package engine.combat
{
	CONFIG::release
	{
		import debug.swap.Cc;
	}
	CONFIG::debug
	{
		import com.junkbyte.console.Cc;
	}
	//import com.greensock.TweenNano;
	import engine.combat.GearBonusCalculator;
	import com.offbeat.events.EventController;
	import com.offbeat.generic.Random;
	import engine.combat.net.CombatLogger;
	import engine.combat.structs.LootObject;
	import engine.combat.types.ActionTypes;
	import flash.events.EventDispatcher;
	import managers.data.ItemData;
	import managers.data.items.powerups.AbstractPowerup;
	import managers.events.ItemEvent;
	import managers.HeroManager;
	import managers.ItemManager;
	import managers.data.types.ModTypes;
	import managers.ModManager;
	import managers.RandomManager;
	import managers.StaticDataManager;
	import managers.StatusManager;
	import engine.combat.events.BattleUpdate;
	import engine.combat.events.CombatActionEvent;
	import engine.combat.events.ControllerEvent;
	import engine.combat.statuses.AbstractStatus;
	import engine.combat.structs.ActionResultObject;
	import engine.combat.structs.DamageObject;
	import engine.combat.structs.TargetingObject;
	import engine.combat.structs.VitalsObject;
	import engine.combat.Team;
	import engine.combat.types.OutcomeTypes;
	import engine.combat.types.StatTypes;
	import engine.combat.RandomAI;
	import managers.data.items.powerups.PowerupPack;
	import server.ServerData;
	import flash.utils.Dictionary;
	import engine.combat.CombatMath;
	
	/**
	 * The model of combat. This drives the gameplay, too.
	 * @author WEng
	 */
	public class CombatEngine extends EventDispatcher
	{
		//:: Combat state machine
		private const PRE_BATTLE:String 	= "pre_battle";
		private const PRE_ROUND:String 		= "pre_round";
		private const IN_BATTLE:String 		= "in_battle";
		private const POST_ROUND:String 	= "post_round";
		private const POST_BATTLE:String 	= "post_battle";
		
		//:: Combat conclusions
		public static const VICTORY:String	= "victory";
		public static const DEFEAT:String	= "defeat";
		public static const DRAW:String		= "draw";
		
		//:: Speed constants
		private const STEP_DELAY:Number		= 1.25;	//delay between steps when calling nextStep()
		private const WAVE_DELAY:Number 	= 2;	//delay when starting a new wave, used in checkWinConditions()
		
		//:: State variables
		//identifiers
		private var _combatID:String;		//combat ID
		private var _encounterID:String;	//defines the set of villains used for this combat (only relevant for single-player server communication)
		//state machine vars
		private var _state:String;			//state machine's current
		private var _running:Boolean;		//if the engine is running (for clean unpausing)
		private var _pause:Boolean;			//flag prevents progression through nextStep()
		//battle state
		private var _round:int;				//just keeps tract of which round it is
		private var _roundQueue:Vector.<Character>;	//round ends when this list is exhausted
		private var _nextRoundQueue:Vector.<Character>;	//pre-generated queue for the round after current
		private var _actionQueue:Vector.<Object>;	//queues up Actions as engine runs them one-by-one
		private var _conclusion:String;		//set when combat's over
		//character variables
		private static var _heroes:Team;	//hero team
		private static var _villains:Team;	//villain team
		private var _curChar:Character;		//who's turn it is
		private var _assist:Character;		//assist char (if any) who's taking a turn
		
		//:: Animation vars
		private var _curAction:CombatActionEvent;				//the CAEvent CombatEngine is awaiting an animationComplete() call for
		private var _aliveChars:Vector.<Character>;				//at the start of each turn, save the _nextRoundQueue for a snapshot of characters alive
		private var _actorXpGain:int;							//how much Xp to award to the actor of _curAction when complete
		private var _actorLevelUp:Boolean;
		
		//:: Loot variables
		private var _lootTable:Vector.<LootObject>;
		
		//:: Singleton references
		private var _event:EventController;
		private var _sm:StatusManager;
		private var _log:CombatLogger;
		private var _random:Random;	//not a singleton, but aqcuired from RandomManager
		
		//temp debug log variables
		private var _lootDrops:Array;
		private var _villainsKOed:Array;
		private var _actionHash:Object;
		private var _outcomeHash:Object;
		public var _combatResults:Object;
		
		//-------------------------------------------------
		// Constructor
		//-------------------------------------------------
		public function CombatEngine(combatResults:Object, combatID:String, encounterID:String, heroes:Team, villains:Team, lootTable:Vector.<LootObject> = null)
		{
			_combatResults = combatResults;
			_combatID = combatID;
			_encounterID = encounterID;
			_heroes = heroes;
			_villains = villains;
			
			_state = PRE_BATTLE;
			_roundQueue = new Vector.<Character>;
			_actionQueue = new Vector.<Object>;
			_aliveChars = new Vector.<Character>;
			
			_actorXpGain = 0;
			_actorLevelUp = false;
			
			_lootTable = lootTable;
			
			_running = false;
			_pause = false;
			
			_event = EventController.getInstance();
			_sm = StatusManager.getInstance();
			_log = CombatLogger.getInstance();
			_random = RandomManager.getInstance().getPRNG(RandomManager.COMBAT);
		}
		
		//-------------------------------------------------
		// Destructor
		//-------------------------------------------------
		public function destroy():void
		{
			_heroes.destroy();
			_heroes = null;
			
			_villains.destroy();
			_villains = null;
			
			_curChar = null;
			_assist = null;
			
			while (_roundQueue.length > 0)
				_roundQueue.pop();
			_roundQueue = null;
			
			while (_nextRoundQueue.length > 0)
				_nextRoundQueue.pop();
			_nextRoundQueue = null;
			
			while (_actionQueue.length > 0)
				_actionQueue.pop();
			_actionQueue = null;
			
			_curAction = null;
			
			while (_aliveChars.length > 0)
				_aliveChars.pop();
			_aliveChars = null;
			
			if (_lootTable)
			{
				while (_lootTable.length > 0)
					_lootTable.pop();
			}
			_lootTable = null;
			
			if (_actionHash)
			{
				for (var key:* in _actionHash)
					delete _actionHash[key];
			}
			_actionHash = null;
			
			if (_outcomeHash)
			{
				for (key in _outcomeHash)
					delete _outcomeHash[key];
			}
			_outcomeHash = null;
			
			_event = null;
			_sm = null;
			_log = null;
			_random = null;
		}
		
		//-------------------------------------------------
		// Public functions
		//-------------------------------------------------		
		/**
		 * Starts the combat.
		 */
		public function play():void
		{
			_log.flushLog();
			_log.logEncounterID(_combatID, _encounterID);
			_random.rolls;	//flushes roll history to keep in sync with start of combat
			_log.logRandomSeed( _random.seed );
			
			//Combat log - villains
			_log.logVillains(_villains.allIDsByWave);
			
			//Combat log - heroes
			_log.logHeroes(_heroes.allIDsByWave);
			
			//temp -- log "final" hero state at start of battle to double check we're starting at same place
			var teamVect:Vector.<Character> = _heroes.allMembers;
			for each (var char:Character in teamVect)
				_log.logFinalHeroState(char.id, char.hpCurrent, char.apCurrent, char.xp);
			
			//temp -- start items dropped array for logging
			_lootDrops = [];
			//temp -- start villains killed array for logging
			_villainsKOed = [];
			
			//init the action/outcome hashes
			_actionHash = { };
			_outcomeHash = { };
			
			_round = 0;
			nextStep(PRE_BATTLE);
		}
		
		/**
		 * Pauses/unpauses the CombatEngine. The engine will halt the next time it is convenient.
		 */
		public function set pause(value:Boolean):void
		{
			_pause = value;
			
			if (!_pause && !_running)	//if we're unpausing, do not call nextStep() if engine is already running!
				nextStep(_state);	//use last known state	
		}
		
		/**
		 * Returns true if the CombatEngine is (or is scheduled to be) paused.
		 */
		public function get pause():Boolean
		{
			return _pause;
		}
		
		/**
		 * Returns a copy of the current round queue
		 */
		public function get roundQueue():Vector.<Character>
		{
			return _roundQueue ? _roundQueue.slice() : null;
		}
		
		/**
		 * Returns a copy of the next round queue
		 */
		public function get nextRoundQueue():Vector.<Character>
		{
			return _nextRoundQueue ? _nextRoundQueue.slice() : null;
		}
		
		/**
		 * Returns the Character object of the Character whose turn it is. Don't destroy this object!!
		 */
		public function get currentCharacter():Character
		{
			return _curChar;
		}
		
		/**
		 * Searches both teams' current waves and returns the Character object with matching ID.
		 * Returns null if the search failed. Try not to modify the Character, please.
		 * @param	id
		 * @return
		 */
		public static function getCharacterByID(id:String):Character
		{
			//search heroes
			for (var i:int = 0; _heroes.currentWave && i < _heroes.currentWave.length; i++)
			{
				if (_heroes.currentWave[i].id == id)
					return _heroes.currentWave[i];
			}
			
			//check heroes' assist char
			if (_heroes.hasAssistCharacter())
			{
				var assist:Character = _heroes.getAssistCharacter();
				if (assist.id == id)
					return assist;
			}
			
			//search villains
			for (i = 0; _villains.currentWave && i < _villains.currentWave.length; i++)
			{
				if (_villains.currentWave[i].id == id)
					return _villains.currentWave[i];
			}
			
			//check villains' assist char
			if (_villains.hasAssistCharacter())
			{
				assist = _villains.getAssistCharacter();
				if (assist.id == id)
					return assist;
			}
			
			return null;
		}
		
		/**
		 * Attemps to make CombatEngine save the defaultTarget of a Character's team
		 * (rather than saving the defaultTarget when an Action is chosen).
		 * Returns true if the TargetingObject is legal
		 * @param	targetObj
		 * @return
		 */
		public function setTeamDefaultTarget(targetObj:TargetingObject):Boolean
		{
			//ensure actor declared
			if (!targetObj.actor) return false;
			//ensure at least one target declared
			if (!targetObj.targets || targetObj.targets.length < 1) return false;
			
			var target:Character = getCharacterByID(targetObj.targets[0]);
			
			//default target can't be on same team as actor
			if (!target || target.teamName == _curChar.teamName) return false;
			
			//ensure target is alive
			if (target.hpCurrent < 1) return false;
			
			//TargetingObject passed all checks
			var team:Team = _heroes.belongsToTeamByID(targetObj.actor) ? _heroes :_villains;
			team.defaultTarget = getCharacterByID(targetObj.targets[0]);
			return true;
		}
		
		/**
		 * For the current Character, returns a TargetingObject with current Character as the actor,
		 * and the targets Vector set according to the ActionType of the Action.
		 * @param	actionType an ActionTypes constant (e.g. AREA, etc.)
		 * @param	character overrides current Character as the actor of the TargetingObject
		 * @return
		 */
		public function getTargetingObject(actionType:String, character:Character = null ):TargetingObject
		{
			var actor:Character;
			if (character)
				actor = character;
			else
			{
				if (!_curChar) return null;	//_curChar not set yet.
				else actor = _curChar;
			}
			
			var team:Team = _heroes.belongsToTeam(actor) ? _heroes : _villains;
			var enemyTeam:Team = (team == _heroes) ? _villains : _heroes;
			
			var targets:Vector.<String> = new Vector.<String>();
			
			switch (actionType)
			{
				case ActionTypes.ENEMY:
					if (team == _heroes)
						targets.push( getDefaultTarget(actor).id );
					else
						targets.push( getDefaultTarget(actor).id );
					break;
				case ActionTypes.AREA:
					for (var i:int = 0; i < enemyTeam.currentWave.length; i++)
					{
						if (enemyTeam.currentWave[i].hpCurrent > 0)
							targets.push(enemyTeam.currentWave[i].id);
					}
					//unshift the middle target to front of Vector
					var midIndex:int = int( (targets.length - 1) / 2)
					targets.unshift( targets.splice(midIndex, 1)[0] );
					break;
				case ActionTypes.DEFENSE:
					targets.push(actor.id);	//defensive actions must target current Character
					break;
				case ActionTypes.MY_TEAM:
					for (i = 0; i < team.currentWave.length; i++)
					{	
						if (team.currentWave[i].hpCurrent > 0)
							targets.push(team.currentWave[i].id);
					}
					break;
				case ActionTypes.ALL:
					for (i = 0; i < enemyTeam.currentWave.length; i++)
					{
						if (enemyTeam.currentWave[i].hpCurrent > 0)
							targets.push(enemyTeam.currentWave[i].id);
					}
					for (i = 0; i < team.currentWave.length; i++)
					{
						if (team.currentWave[i].hpCurrent > 0)
							targets.push(team.currentWave[i].id);
					}
					break;
				default:
					//no action type supplied. Use the team's old default
					targets.push( getDefaultTarget(actor).id );
					break;
			}
			
			return new TargetingObject(actor.id, targets);
		}
		
		/**
		 * Returns a TargetingObject that lists all legal targets of the actionType. Actor is returned as null.
		 * (This function was written for handing out powerups in combat)
		 * @param	actionType
		 * @return
		 */
		public function getLegalTargetsForPowerup(actionType:String):TargetingObject
		{
			var team:Team = _heroes;
			var enemyTeam:Team = _villains;
			
			var targets:Vector.<String> = new Vector.<String>();
			
			switch (actionType)
			{
				case ActionTypes.ENEMY:	//all enemies are legal, just like AREA
				case ActionTypes.AREA:
					for (var i:int = 0; i < enemyTeam.currentWave.length; i++)
					{
						if (enemyTeam.currentWave[i].hpCurrent > 0)
							targets.push(enemyTeam.currentWave[i].id);
					}
					//unshift the middle target to front of Vector
					var midIndex:int = int( (targets.length - 1) / 2)
					targets.unshift( targets.splice(midIndex, 1)[0] );
					break;
				case ActionTypes.DEFENSE: //all allies are legal, just like MY_TEAM
				case ActionTypes.MY_TEAM:
					for (i = 0; i < team.currentWave.length; i++)
					{	
						if (team.currentWave[i].hpCurrent > 0)
							targets.push(team.currentWave[i].id);
					}
					break;
				case ActionTypes.ALL:
					for (i = 0; i < enemyTeam.currentWave.length; i++)
					{
						if (enemyTeam.currentWave[i].hpCurrent > 0)
							targets.push(enemyTeam.currentWave[i].id);
					}
					for (i = 0; i < team.currentWave.length; i++)
					{
						if (team.currentWave[i].hpCurrent > 0)
							targets.push(team.currentWave[i].id);
					}
					break;
				default:
					//no action type supplied. Push no legal targets.
					break;
			}
			
			return new TargetingObject(_curChar.id, targets);
		}
		
		/**
		 * Calculates the expected HP and AP deltas for all Characters targeted by an Action.
		 * Returns: Object[char id] = { hpDelta : N, apDelta : M }
		 * @param	action
		 * @param	targetingObject
		 * @return
		 */
		public function getExpectedDeltasForAction(action:Action, targetingObject:TargetingObject):Object
		{
			var result:Object = { };
			
			var actor:Character = getCharacterByID(targetingObject.actor);
			var apDelta:int = -CombatMath.calcActionCost(action, actor);
			result[actor.id] = { apDelta : apDelta };
			
			for each (var targetID:String in targetingObject.targets)
			{
				var target:Character = getCharacterByID(targetID);
				var hpDelta:int = 0;
				for (var i:int = 0; i < action.hits; i++)
					hpDelta -= CombatMath.calcDamage(actor.atkTotal, target.defTotal, action, 0.5);
				if (result[target.id])
					result[target.id]["hpDelta"] = hpDelta;
				else
					result[target.id] = { hpDelta : hpDelta };
			}
			
			return result;
		}
		
		/**
		 * Applies an item's effect to a target character(s)
		 * @param	target ID of a character to use the item on (may be NaN if the item targets all/no characters)
		 * @param	item the Item to use
		 */
		public function usePowerup(targetObj:Object, item:AbstractPowerup):void
		{			
			//assemble the Character objects so powerup can act on them directly
			var actor:Character = getCharacterByID(targetObj.actor);
			var targets:Vector.<Character> = new Vector.<Character>();
			var target:Character;
			for each (var charID:String in targetObj.targets)
			{
				target = getCharacterByID(charID);
				if (target)
					targets.push(target);
			}
			item.applyTo(actor, targets);
			item.coolUp();	//set cooldown count to max
			ServerData.itemsUsed.push(item.id);
			
			//ItemManager.getInstance().decrementItemCount(item.id, 1, ItemEvent.REASON_COMBATUSE, _combatID);	//decrement count through ItemManger for persistence
		
			//play powerup's 'move' on targets; maybe delay engine to give animation time to complete?
			if (item.anim_id)
			{
				//var cae:CombatActionEvent = new CombatActionEvent(CombatActionEvent.ACT, null, targetObj, _curChar.teamName);
				//cae.animID = item.anim_id;
				//_curAction = cae;	//wait for this animation to complete
				//_event.dispatchEvent(cae);
			} else {
				endOfTurn();		//no animation, end the turn (statuses added with powerup won't report until next animation)
			}
		}
		
		/**
		 * Inserts an assist character into the round queue as the next turn.
		 * @param	char
		 * @param	friendID
		 */
		public function assistInput(char:Character, friendID:String):void
		{
			var team:Team = _curChar.teamName == Team.HERO ? _heroes : _villains;

			team.addAssistCharacter(char);

			//log distress call
			_log.logDistressCall(friendID, char.id);

			//design choice: end the turn?
			endOfTurn();
			nextStep(IN_BATTLE, 0);	//:: WEng 6/3/2011 - Assists occur during current Character's turn (does not cost their turn)
		}
		
		/**
		 * Report to the CombatEngine that an Action was choosen (via UI or AI)
		 * @param	event
		 */
		public function actionInput(event:Object):void
		{
			trace('actionInput');
			//if (event.type != ControllerEvent.ACTION_INPUT)
			//	return;	//wrong event type
			
			//deactivate the associated controller
			//_curChar.controller.removeEventListener(ControllerEvent.ACTION_INPUT, actionInput);
			//_curChar.controller.deactivate();
			
			//check that this action can be paid for, targets all OK
			if (!ensureLegalAction(event.action, event.targetingObj))
			{
				trace('illegal action');
				endOfTurn(); //this action cannot be performed, move on to next turn
				return;
			}
			
			//:: 2/17/2011 cooldown logic moved here from carryOutAction()
			//:: Action cooldown logic -- cooldown unused actions, set 'action' cooldown time to max
			for each (var unused:Action in _curChar.actions)
			{
				unused.coolDown();
			}
			event.action.coolUp();
			
			//:: 2/17/2011 energy cost logic moved here from carryOutAction()
			//:: Charge energy to perform this action
			var apCost:int = CombatMath.calcActionCost(event.action, _curChar);	//::WEng 4/22/2011 -- values between 0 and 1 take a percentage of ap, not flat
			_curChar.apCurrent -= apCost;
			
			//don't dispatch this event. CombatUI's onAction will update accordingly without this.
			//_event.dispatchEvent(new BattleUpdate(BattleUpdate.VITALS, { vitalsObj : new VitalsObject(_curChar.id, StatTypes.AP_CUR, _curChar.apCurrent) } ));
			
			//perform the action
			queueAction(event.action, event.targetingObj);
			playNextAction();
		}
		
		/**
		 * Informs CombatEngine that the last CombatActionEvent it dispatched has finished animating.
		 */
		public function animationComplete(targetObj:TargetingObject):void
		{
				//:: show actor's xp gain
				//displayActorXpGain(_curAction.targetObj.actor);
				
				//:: Do post-defense status check on targets of _curAction
				for (var i:int = 0; i < targetObj.targets.length; i++)
				{
					var target:Character = getCharacterByID(targetObj.targets[i]);
					if (target)
						target.triggerCheck(AbstractStatus.POST_DEF);
				}
				//_curAction = null;
				
				//:: clean up characters (removal of characters during counter attacks)
				cleanUpKOs();
				
				//:: do a status report check on all characters in the current waves
				var n:int = _aliveChars.length;
				for (i = 0; i < n; i++)
				{
					var statuses:Vector.<AbstractStatus> = _aliveChars[i].statuses;
					var m:int = statuses.length;
					for (var j:int = 0; j < m; j++)
						statuses[j].reportCheck();
				}
				
				//:: Auto-play the next queued Action
				playNextAction();
		}
		
		//-------------------------------------------------
		// Battle state machine logic ( private )
		//-------------------------------------------------
		private function nextStep(state:String = null, stepDelay:Number = STEP_DELAY):void
		{
			//if state was set, update to that and proceed
			if (state)
				_state = state;
			
			//pause the engine?
			_running = !_pause;
			if (_pause)
				return;
			
			//proceed to substep 1
			winConCheck();
			
			//-------------------------
			// substep 1: winConCheck() -- state-based effects
			//-------------------------
			function winConCheck():void
			{
				var delayObj:Object = { delay : 0 };	//if checkWinConditions doesn't set delay, do not wait to proceed
				
				cleanUpKOs();	//::WEng 6/16/2011 do not change states without cleaning up KOs
				
				//check for win conditions before proceeding
				if ( checkWinConditions( delayObj ) )
				{
					//state = null;
					_state = POST_BATTLE;
				}
				
				//proceed to substep 2
				stateCheck();
			}
			
			//-------------------------
			// substep 2: stateCheck()
			//-------------------------
			function stateCheck():void
			{
				/*//if state was set, update to that and proceed
				if (state)
					_state = state;*/
				
				switch (_state)
				{
					case PRE_BATTLE:
						beginBattle();
						break;
					case PRE_ROUND:
						beginRound();
						break;
					case IN_BATTLE:
						if (_roundQueue.length < 1)
							nextStep(POST_ROUND, 0);
						else
							takeTurn();
						break;
					case POST_ROUND:
						endRound();
						break;
					case POST_BATTLE:
						endBattle();
						break;
				}
			}
		}
		
		//-------------------------------------------------
		// Battle steps functions ( private )
		//-------------------------------------------------
		private function beginBattle():void
		{
			//dispatch 'add heroes / villains to battlefield' events for each character
			for each (var char:Character in _heroes.currentWave)
			{
				//_event.dispatchEvent(new BattleUpdate(BattleUpdate.CHAR_ENTER, { /*id : char.id,*/ character : char, team : Team.HERO } ));
			}
			
			for each (char in _villains.currentWave)
			{
				//_event.dispatchEvent(new BattleUpdate(BattleUpdate.CHAR_ENTER, { /*id : char.id,*/ character :char, team : Team.VILLAIN } ));
			}
			
			//show some story elements?
			//story hook 1: Dispatch an event after characters enter the battlefield
			//_event.dispatchEvent(new BattleUpdate(BattleUpdate.BEGIN_BATTLE, { combatID : _combatID } ));
			
			//add battlefield status effects here?
			
			nextStep(PRE_ROUND);
		}
		
		private function beginRound():void
		{
			//reset turnsTakenThisRound of each Character to 0
			for each (var char:Character in _heroes.currentWave)
				char.turnsTakenRound = 0;
			for each (char in _villains.currentWave)
				char.turnsTakenRound = 0;
			
			//get the next round queue
			//_roundQueue = nextRoundQueue;
			_roundQueue = _nextRoundQueue ? _nextRoundQueue : createNextRoundQueue();	//_nextRoundQueue null, generate it on first round of battle
			_nextRoundQueue = createNextRoundQueue();			
			
			//update _aliveChars
			//_aliveChars = _roundQueue.slice();	//WEng 6/3/2011 -- only occurs in takeTurn() now
			//filterDuplicates(_aliveChars);	//filter out duplicate character instances (e.g. via ExtraTurn status)
			
			//tell UI about the new queue	//WEng 6/3/2011 -- moved to takeTurn()
			//_event.dispatchEvent(new BattleUpdate(BattleUpdate.QUEUE, { current : _roundQueue.slice(), next : _roundQueue.slice() } ));
			
			//handle pre-round status updates
			var needDelay:Boolean = phaseTrigger(AbstractStatus.PRE_ROUND);
			
			//logging paperwork
			_log.openRound(++_round);
			
			//proceed to the first turn of the round
			nextStep(IN_BATTLE, needDelay ? STEP_DELAY : 0);
		}
		
		private function takeTurn():void
		{			
			//determine who's turn it is. If either team has an assist Character set, use that
			if (_heroes.hasAssistCharacter())
			{
				_curChar = _heroes.getAssistCharacter();
				_assist = _curChar;
				//_event.dispatchEvent(new BattleUpdate(BattleUpdate.CHAR_ENTER, { /*id : _curChar.id*/ character : _assist, team : Team.HERO, isSpecial : true } ));
			} else if (_villains.hasAssistCharacter()) {
				_curChar = _villains.getAssistCharacter();
				_assist = _curChar;
				//_event.dispatchEvent(new BattleUpdate(BattleUpdate.CHAR_ENTER, { /*id : _curChar.id*/ character : _assist, team : Team.VILLAIN, isSpecial : true } ));
			} else {
				//get the next Character in the _roundQueue, it's their turn
				_curChar = _roundQueue[0];		//splicing of Character from _roundQueue occurs at end of turn
			}
			
			_aliveChars = _nextRoundQueue.slice();	//save a snapshot of who's alive to start the turn
			filterDuplicates(_aliveChars);	//filter out duplicate character instances (e.g. via ExtraTurn status)
			
			//announce the updated round queue
			//_event.dispatchEvent(new BattleUpdate(BattleUpdate.QUEUE, { current : roundQueue, next : nextRoundQueue } ));
			
			//announce a Character taking turn
			//_event.dispatchEvent(new BattleUpdate(BattleUpdate.TURN, { id : _curChar.id, defaultTarget : getDefaultTarget(_curChar).id } ));
			
			//pre-turn status update
			phaseTrigger(AbstractStatus.PRE_TURN);
			
			//logging paperwork
			_log.openTurn(_curChar.id, _curChar.teamName);
			
			//end turn immediately if character has been KO'ed (probably by a status during PRE_TURN), or has no available Actions
			if (_curChar.hpCurrent < 1 || _curChar.availableActions.length < 1)
			{
				endOfTurn();
				return;
			}
			
			//activate the controller of the _curChar, wait for INPUT event
			//_curChar.controller.addEventListener(ControllerEvent.ACTION_INPUT, actionInput);
			
//			if (_heroes.belongsToTeam(_curChar))
//				ac = rai.activate(_curChar,_heroes, _villains);	//now we wait...
//			else
//				ac = rai.activate(_curChar,_villains, _heroes);
			trace('taketurn');
			var res:int = nextActionFromLog();
			trace(res);
			if (res == 0)
			{
				return;
			}
			
		}
		
		private function nextActionFromLog():int
		{
			var actionEvent:Object = ServerData.nextTurn(_curChar);
			trace(actionEvent.eventType);
			if (actionEvent == undefined)
			{
				trace('No more turns!');
				return 0;
			}
			
			
			if (actionEvent.eventType == 'action')
			{
				actionInput(actionEvent);
				return 1;
			}
			else if (actionEvent.eventType == 'status_effect')
			{
				return nextActionFromLog();
			}
			else if (actionEvent.eventType == 'item_effect')
			{
				//var item:XML = ServerData.getItem(actionEvent.itemEffect.@id);
				var powerUp:PowerupPack = ItemManager.getInstance().getItem(actionEvent.itemEffect.@id) as PowerupPack;
				usePowerup(actionEvent.targetingObj,powerUp);
				return nextActionFromLog();
			}
			else
			{
				return 1;
			}
			
		}
		
		private function endOfTurn():void
		{
			//logging paperwork
			_log.closeTurn();			
			
			//:: WEng 5/31/2011 -- moved to animationComplete()
			//do a status report check on all characters in the current waves
			//var n:int = _aliveChars.length;
			//for (var i:int = 0; i < n; i++)
			//{
				//var statuses:Vector.<AbstractStatus> = _aliveChars[i].statuses;
				//var m:int = statuses.length;
				//for (var j:int = 0; j < m; j++)
					//statuses[j].reportCheck();
			//}
			
			//allow characters to add extra turns after their turn
			var copy:Vector.<Character> = _roundQueue.slice();
			for each (var character:Character in copy)
			{
				character.triggerCheck(AbstractStatus.MODIFY_QUEUE, copy);
			}
			//if (_roundQueue.length < copy.length)	//turns added?
				//_event.dispatchEvent(new BattleUpdate(BattleUpdate.QUEUE, { current : _roundQueue.slice(), next : _nextRoundQueue.slice() } ));	//don't update queue, it'll happen in takeTurn()
			_roundQueue = copy;
			
			//remove cameo Character if they were added to battlefield.
			if (_assist)
			{
				//_event.dispatchEvent(new BattleUpdate(BattleUpdate.CHAR_LEAVE, { id : _assist.id } ));
				var team:Team = _assist.teamName == Team.HERO ? _heroes : _villains;
				team.removeAssistCharacter();	//clear assist character from their team
				_assist = null;
				_curChar = _roundQueue[0];	//reassign _curChar from _assist to _roundQueue[0]
			} else {
				//remove Character from head of _roundQueue
				if (_roundQueue.length > 0 && _curChar == _roundQueue[0])	//if _curChar died (and removed from head of round queue by cleanUpKOs()), do not remove head of round queue
					_roundQueue.shift();
				
				//increment turns taken
				_curChar.turnsTakenRound++;
			}
			
			//clean up KO'ed Characters
			/*for each (var charKO:Character in _aliveChars)
			{
				if (charKO.hpCurrent < 1)
				{
					//remove character from round queue
					for (var i:int = 0; i < _roundQueue.length; )
					{
						if (_roundQueue[i] == charKO)
							_roundQueue.splice(i, 1);
						else
							i++;
					}
					
					//remove character from next round queue
					for (i = 0; i < _nextRoundQueue.length; )
					{
						if (_nextRoundQueue[i] == charKO)
							_nextRoundQueue.splice(i, 1);
						else
							i++;
					}
					
					//remove character from environment
					//_event.dispatchEvent(new BattleUpdate(BattleUpdate.CHAR_LEAVE, { id : charKO.id, dead : true, team : charKO.teamName } ));
					
					//inform character they're officially KO'ed
					if (charKO.teamName == Team.VILLAIN)
					{
						ServerData.charactersKilled.push(charKO.base_id);
					}
					
					charKO.knockedOut();
					
					//temp -- log KO'ed villains
					if (charKO as Villain)
						_villainsKOed.push(charKO.base_id);
				}
			}*/
			
			//cooldown all items in user's inventory (if the _curChar was a Hero)
			if (_curChar.teamName == Team.HERO)
			{
				var inv:Vector.<ItemData> = ItemManager.getInstance().getOwnedItemsByType(ItemData.POWER_UP);
				
				for each (var powerup:AbstractPowerup in inv)
					powerup.coolDown();
			}
			
			//Post-turn trigger check
			phaseTrigger(AbstractStatus.POST_TURN);
			
			nextStep(IN_BATTLE, STEP_DELAY);
		}
		
		private function endRound():void
		{
			//logging paperwork
			_log.closeRound();
			
			//handle post-round status updates
			var needDelay:Boolean = phaseTrigger(AbstractStatus.POST_ROUND);
			
			//todo: check for characters who've died from the POST_ROUND statusUpdate!
			
			nextStep(PRE_ROUND, needDelay ? STEP_DELAY : 0);
		}
		
		private function endBattle():void
		{
			//story elements go here, based on conclusion?
			switch(_conclusion)
			{
				case VICTORY:
					break;
				case DEFEAT:
					break;
				case DRAW:
					break;
				default:
					return;
			}
			
			//reset all cooldowns of owned items
			var inv:Vector.<ItemData> = ItemManager.getInstance().getOwnedItemsByType(ItemData.POWER_UP);
			for each (var powerup:AbstractPowerup in inv)
				powerup.cooldownCount = 0;
			
			//send combat log to server
			var teamVect:Vector.<Character> = _heroes.allMembers;
			for each (var char:Character in teamVect)
				_log.logFinalHeroState(char.id, char.hpCurrent, char.apCurrent, char.xp);
			_log.logRandomNumbers(_random.rolls);
			_log.logConclusion(_conclusion);
			_log.logLootDrops(_lootDrops);
			_log.logVillainsKOed(_villainsKOed);
			_log.sendLog();
			
			_combatResults.conclusion = _conclusion;
			//:: 2/9/2011 -- don't dispatch END_BATTLE through EventController, just relay to CombatPage.
			//This allows CombatPage to control when the page is closed.
			//this.dispatchEvent(new BattleUpdate(BattleUpdate.END_BATTLE, { conclusion : _conclusion, combat_id : _combatID } ));
		}
		
		//-------------------------------------------------
		// Utility functions ( private )
		//-------------------------------------------------
		
		/**
		 * If the next round started right now, this is the order of that round
		 */
		private function createNextRoundQueue():Vector.<Character>
		{
			var result:Vector.<Character> = new Vector.<Character>();
			
			for each (var character:Character in _heroes.currentWave)
			{
				if (character.hpCurrent > 0)
				{
					result.push(character);
					
					//make sure Character has rolled initiative
					if ( !character.hasRolledInitiative() )
						character.rollInitiative();
				}
			}
			
			for each (character in _villains.currentWave)
			{
				if (character.hpCurrent > 0)
				{
					result.push(character);
					
					//make sure Character has rolled initiative
					if ( !character.hasRolledInitiative() )
						character.rollInitiative();
				}
			}
			
			result.sort(sortByInitiative);
			
			//allow characters to alter the queue	//:: WEng 6/4/2011 also occurs during endOfTurn()
			var copy:Vector.<Character> = result.slice();	//send a copy so statuses can add/remove characters without causing infinite loops
			for each (character in result)
			{
				character.triggerCheck(AbstractStatus.MODIFY_QUEUE, copy);
			}
			result = copy;
			
			return result;
		}
		
		//Returns true if the battle has reached a conclusion
		private function checkWinConditions(delayObj:Object):Boolean
		{
			var heroAlive:Boolean = _heroes.currentWave.some(isAlive, null);
			var villAlive:Boolean = _villains.currentWave.some(isAlive, null);
			
			//if either team's wave is wiped out, try to move on to the next
			if (!heroAlive)
			{				
				_heroes.startNextWave();
				heroAlive = (_heroes.currentWave) ? _heroes.currentWave.some(isAlive, null) : false;
				
				//announce new heroes entering battle
				if (heroAlive)
				{
					for each (var char:Character in _heroes.currentWave)
					{
						//it takes 1.9 seconds to playKOeffect() on dead char. Wait 2.5 seconds.
						//TweenNano.delayedCall(2.5 - STEP_DELAY, _event.dispatchEvent, [ new BattleUpdate(BattleUpdate.CHAR_ENTER, { character : char, team : Team.HERO } ) ]);
					}
					
					//logging paperwork
					_log.closeRound();
					
					//clear _roundQueue, starting a new round
					while (_roundQueue.length > 0)
						_roundQueue.pop();
					
					//let UI display a message about a new wave starting
					_event.dispatchEvent(new BattleUpdate(BattleUpdate.NEXT_WAVE, { team : Team.HERO } ));
					
					delayObj["delay"] = WAVE_DELAY;
				}
			}
			
			if (!villAlive)
			{
				_villains.startNextWave();
				villAlive = (_villains.currentWave) ? _villains.currentWave.some(isAlive, null) : false;
				
				//announce new villains entering battle
				if (villAlive)
				{
					for each (char in _villains.currentWave)
					{
						//it takes 1.9 seconds to playKOeffect() on dead char. Wait 2.5 seconds.
						//TweenNano.delayedCall(2.5 - STEP_DELAY, _event.dispatchEvent, [ new BattleUpdate(BattleUpdate.CHAR_ENTER, { character : char, team : Team.VILLAIN } ) ]);
					}
					
					//logging paperwork
					_log.closeRound();
					
					//clear _roundQueue, starting a new round
					while (_roundQueue.length > 0)
						_roundQueue.pop();
					
					//let UI display a message about a new wave starting
					_event.dispatchEvent(new BattleUpdate(BattleUpdate.NEXT_WAVE, { team : Team.VILLAIN } ));
					
					delayObj["delay"] = WAVE_DELAY;
				}
			}
			
			//declare a winner if either team is completely wiped out
			if (!heroAlive || !villAlive)
			{
				_conclusion = heroAlive ? VICTORY : DEFEAT;
				
				if (!heroAlive && !villAlive)
					_conclusion = DRAW;				
			}
			
			return _conclusion != null;
			
			function isAlive(item:Character, index:int, vector:Vector.<Character>):Boolean
			{
				return item.hpCurrent > 0;
			}
		}
		
		/**
		 * Removes KO'ed Characters from _roundQueue, _nextRoundQueue, and _aliveChars.
		 * Also dispatches BattleUpdate.CHAR_LEAVE events.
		 * @return true if at least one Character was removed
		 */
		private function cleanUpKOs():Boolean
		{
			var result:Boolean = false;
			
			//for each (var charKO:Character in _aliveChars)
			for (var i:int = 0; i < _aliveChars.length; )	//no i++
			{
				var charKO:Character = _aliveChars[i];
				if (charKO.hpCurrent < 1)
				{	
					result = true;
					
					//remove character from round queue
					for (var j:int = 0; j < _roundQueue.length; )	//no j++
					{
						if (_roundQueue[j] == charKO)
							_roundQueue.splice(j, 1);
						else
							j++;
					}
					
					//remove character from next round queue
					for (j = 0; j < _nextRoundQueue.length; )	//no j++
					{
						if (_nextRoundQueue[j] == charKO)
							_nextRoundQueue.splice(j, 1);
						else
							j++;
					}
					
					//remove character from _aliveChars
					for (j = i; j < _aliveChars.length; ) //no j++
					{
						if (_aliveChars[j] == charKO)
							_aliveChars.splice(j, 1);
						else
							j++;
					}
					
					//remove character from environment
					_event.dispatchEvent(new BattleUpdate(BattleUpdate.CHAR_LEAVE, { id : charKO.id, dead : true, team : charKO.teamName } ));
					
					//inform character they're officially KO'ed
					charKO.knockedOut();
					
					//temp -- log KO'ed villains
					if (charKO as Villain)
						_villainsKOed.push(charKO.base_id);
				} else
					i++;	//character not KO'ed, move on
			}
			
			return result;
		}
		
		/**
		 * Performs a PRE/POST_TURN and PRE/POST_ROUND triggerCheck() calls on appropriate set of Characters.
		 * Returns true if a status triggered because of this trigger.
		 * @param	timing Use AbstractStatus.PRE_TURN, etc. Not for use with non-phase related triggers (e.g. MODIFY_ON_ATTACK, et al.)
		 * @return
		 */
		private function phaseTrigger(timing:String):Boolean
		{	
			var checkChars:Vector.<Character>;	//holds all characters that must be checked in this phase
			if (timing == AbstractStatus.PRE_TURN || timing == AbstractStatus.POST_TURN)
			{
				checkChars = new Vector.<Character>(_curChar);
				checkChars.push(_curChar);
			} else if (timing == AbstractStatus.PRE_ROUND || AbstractStatus.POST_ROUND) {
				checkChars = _aliveChars;
			}
			
			var triggered:Boolean = false;
			
			for each (var character:Character in checkChars)
			{
				if ( character.triggerCheck(timing) )	//character.triggerCheck() returns true/false if a status triggered on this timing
					triggered = true;
			}
			
			return triggered;
		}
		
		private function ensureLegalAction(action:Action, targetingObj:TargetingObject):Boolean
		{
			//check that Action was chosen
			if (action == null)	return false;
			
			//check that there are targets
			if (!targetingObj || !targetingObj.targets || !( targetingObj.targets.length > 0) ) return false;
			
			//check that the Action cooldown is 0
			if (action.cooldownCount > 0) return false;
			
			//check that Action can be paid for
			if (CombatMath.calcActionCost(action, _curChar) > _curChar.apCurrent) return false;	//::WEng 4/22/2011 -- added percentage of total ap cost check
			
			return true;
		}
		
		private function queueAction(action:Action, targetingObj:TargetingObject, counter:Boolean = false):void
		{
			var obj:Object = { action : action, targetObj : targetingObj, counter : counter };
			_actionQueue.push( obj );	//playNextAction() consumes from this Vector
		}
		
		private function playNextAction():void
		{
			trace('playNextAction');
			if (_actionQueue.length > 0)
			{
				var obj:Object = _actionQueue.shift();
				
				//:: Double check actors and targets of the action are still alive (esp. when counterattacking)
				var targetObj:TargetingObject = TargetingObject(obj["targetObj"]);
				var actor:Character = getCharacterByID( targetObj.actor );
				if ( !actor || actor.hpCurrent < 1 )		//ensure actor is alive!
				{
					trace('actor not alive');
					playNextAction();
					return;
				}
				for (var i:int = 0; i < targetObj.targets.length; ) //no i++
				{
					var target:Character = getCharacterByID( targetObj.targets[i] );
					if (!target || target.hpCurrent < 1)	//ensure target is alive!
						targetObj.targets.splice(i, 1);
					else
						i++;	//target OK
				}
				if (targetObj.targets.length < 1)	//no targets, cannot perform Action
				{
					trace('no targets');
					playNextAction();
					return;
				}
				
				carryOutAction(obj["action"], obj["targetObj"], obj["counter"]);	//request next Action be played
				
				//if (obj["counter"])	//WEng -- kinda hacky. How else can we know this was a counter move?
					//_event.dispatchEvent(new BattleUpdate(BattleUpdate.ONE_UP, { id : TargetingObject(obj["targetObj"]).actor, message : "Counter!", color : 0x88ccff} ));
			} else {
				endOfTurn();										//end the turn, all Actions finished
			}
		}
		
		/**
		 * Calculates and applies the outcome of an action performed by an actor on a set of targets.
		 * @param	action should be chosen from actor's set of Actions
		 * @param	targetingObj declares the actor and targets of the Action
		 * @param	counter	declares this Action as a counter attack for logging
		 */
		private function carryOutAction(action:Action, targetingObj:TargetingObject, counter:Boolean = false):void
		{		
			trace('carryOutAction');
			//:: Create the result Dictionary. maps resultObjects[character] = ActionResultObject
			var resultObjects:Dictionary = new Dictionary();
			
			//:: Obtain actor Character from ID
			var actor:Character = getCharacterByID(targetingObj.actor);
			
			if (actor.teamName == Team.HERO)
			{
				ServerData.actionsUsed.push(action.id);
			}
			
			//:: clone a malleable copy of the Action for tweaking
			var baseCopy:Action = action.clone();
			
			//:: have baseCopy inherit actor's tags
			baseCopy.tags = baseCopy.tags.concat( actor.tags );
			
			//:: allow attacker's statuses to modify the attack
			actor.triggerCheck(AbstractStatus.MODIFY_ON_ATTACK, baseCopy);
			
			//:: allow anyone's statuses to modify targets
			for each (var char:Character in _aliveChars)
				char.triggerCheck(AbstractStatus.MODIFY_TARGETS, baseCopy, targetingObj);
			
			//:: Obtain target Characters from ID
			var targets:Vector.<Character> = new Vector.<Character>();
			
			for (var i:int = 0; i < targetingObj.targets.length; i++)
			{
				var target:Character = getCharacterByID(targetingObj.targets[i]);
				if (target)
					targets.push(target);
			}
			
			//:: Combat log - start a fresh action log
			newActionLog(baseCopy.id, baseCopy.level, actor, targets, counter);
			
			//:: Combat log - actor AP spent
			if (!counter)	//counters do not cost AP
				updateOutcome(actor.id, { apDelta : -CombatMath.calcActionCost(baseCopy, actor) } );
			
			//:: remeber actor starting state
			var actorLvl:int = actor.level;
			var actorXp:int = actor.xp;
			
			//:: Calculate hit outcomes on all targets
			trace('carryOutAction targets',targets);
			for each (target in targets)
			{
				var actionResult:ActionResultObject = new ActionResultObject(target.id);
				resultObjects[target] = actionResult;	//map target Character to its ActionResultObject
				
				//assign target their own copy of actor's modified copy
				var subcopy:Action = baseCopy.clone();
				actionResult.subcopy = subcopy;				
				
				//step 1: pre-hits modification
				target.triggerCheck(AbstractStatus.MODIFY_PRE_HITS, subcopy);
				//step 2: determine outcome of each hit
				for (i = 0; i < subcopy.hits; i++)
				{
					//2.1 - Roll 1: MISS, CRIT, or HIT
					var roll_1:Number = _random.nextFloat();
					var outcome:String = CombatMath.calcHitOutcome(actor.accTotal, target.evaTotal, subcopy, roll_1);
					
					//2.2 - Roll 2: damage
					var roll_2:Number = _random.nextFloat();
					var damage:int = CombatMath.calcDamage(actor.atkTotal, target.defTotal, subcopy, roll_2, outcome);
					trace('Damage',damage);
					//create DamageObject for this hit
					var dmgObj:DamageObject = new DamageObject(target.id, damage, outcome);
					actionResult.damageList.push(dmgObj);
					
					//2.3: post-hit modification
					target.triggerCheck(AbstractStatus.MODIFY_POST_HITS, subcopy, dmgObj);
					
					//2.x: Determine gear bonuses (if any)
					GearBonusCalculator.calculateBonus(dmgObj, actor, target, subcopy, roll_1, roll_2, actor.teamName == Team.HERO ? _heroes : _villains, target.teamName == Team.HERO ? _heroes : _villains);
					
					//2.4: apply damage
					target.hpCurrent -= dmgObj.amount;
					trace(target.hpCurrent,dmgObj.amount);
					//2.5: award xp to actor
					var targetXpStart:int = target.xp;
					target.xp -= CombatMath.calcXpGain(damage, target);
					dmgObj.xp = targetXpStart - target.xp;	//only award as much xp as target lost
					actor.xp += dmgObj.xp;
				}
				
				//step 3 - Roll 3: target drops loot (on target KO'ed or critical occurred)
				var roll_3:Number = _random.nextFloat();
				var villain:Villain = target as Villain;
				if ( villain && target.hpCurrent < 1 )
				{
					var lootID:String = rollForLoot(villain, roll_3, true)
				} else if (villain && actionResult.damageList.some(testForCrit, null) ) {
					lootID = rollForLoot(villain, roll_3, false)
				} //else no loot drop
				
				actionResult.damageList[actionResult.damageList.length - 1].loot = lootID;
				//Combat log - loot dropped (temp)
				if (lootID)
					_lootDrops.push(lootID);
				
				//Combat log - target damage taken, target loot dropped
				var log_dmg:int = 0;
				for each (dmgObj in actionResult.damageList)
					log_dmg += dmgObj.amount;
				updateOutcome(target.id, { team : target.teamName, hpDelta : -log_dmg, loot : lootID } );
			}
			_actorLevelUp = actorLvl < actor.level;	//did actor level up from this action?
			_actorXpGain = actor.xp - actorXp;		//how much xp actor gained from this action
			
			//:: Combat log - actor xp gain
			updateOutcome(actor.id, { xpDelta : _actorXpGain });
			
			//step 4: apply statuses to Action.statusTarget(s)
			for (var key:* in resultObjects)
			{
				actionResult = resultObjects[key];
				
				//subcopy defines a status
				if (actionResult.subcopy.status)
				{
					//4.1 - Roll 4: status chance
					var roll_4:Number = _random.nextFloat();
					
					//4.2: calculate chance to fail
					var failChance:Number = 1;
					for each (dmgObj in actionResult.damageList)
					{
						if (dmgObj.details == OutcomeTypes.HIT || dmgObj.details == OutcomeTypes.CRIT)
							failChance *= (1 - actionResult.subcopy.statusChance);
					}
					
					//4.3: apply status to statusTarget(s)
					if (roll_4 >= failChance)	//reduced down from (roll_4 < 1 - failChance)
					{
						//apply status to each target in resultObjects...
						if (actionResult.subcopy.statusTarget == ActionTypes.ENEMY)
						{
							_sm.addStatusTo(key as Character, actionResult.subcopy.status, false, true);
							
							//Combat log - target gains status
							actionResult.status = true;
							updateOutcome(actionResult.charID, { status : actionResult.subcopy.status } );
							continue;
						} else {	//...OR apply status once to Characters in the set defined by Action.statusTarget
							var statusTO:TargetingObject = getTargetingObject(actionResult.subcopy.statusTarget, actor);
							for each (var charID:String in statusTO.targets)
							{
								var character:Character = getCharacterByID(charID);
								_sm.addStatusTo(character, actionResult.subcopy.status, false, true);
								
								//Combat log - statusTarget(s) gain status
								updateOutcome(charID, { status : actionResult.subcopy.status });
							}
							break;
						}
					}
				}
			}
			
			//step 5: queue up counter actions
			for each (target in targets)
			{
				if (target.countersWith && target.hpCurrent > 0)	//target cannot counter if they are KO'ed
				{
					//var counterVect:Vector.<String> = new Vector.<String>();
					//counterVect.push(actor.id);
					//var counterTargetObj:TargetingObject = new TargetingObject(target.id, counterVect);
					var counterTargetObj:TargetingObject = getTargetingObject(target.countersWith.type, target);
					if (target.countersWith.type == ActionTypes.ENEMY)
						counterTargetObj.targets.splice(0, 1, actor.id);	//calling getTargetingObject for type ENEMY returns team's default target; redirect to actor
					queueAction(target.countersWith, counterTargetObj, true);
					
					target.countersWith = null;	//reset countersWith Action
				}
			}			
			
			//:: Combat log - Finalize, commit
			trace('commitactionlog');
			commitActionLog();
			
			//finally, dispatch animation for this action
			var damageLists:Dictionary = new Dictionary();
			for (key in resultObjects)
			{
				char = Character(key);
				damageLists[char.id] = ActionResultObject(resultObjects[char]).damageList;
			}
			
			//var cae:CombatActionEvent = new CombatActionEvent(CombatActionEvent.ACT, baseCopy, targetingObj, actor.teamName, damageLists, counter);
			//_curAction = cae;
			//_event.dispatchEvent(cae);
			animationComplete(targetingObj);
		}
		
		private function sortByInitiative(x:Character, y:Character):Number
		{
			return y.initiative - x.initiative;
		}
		
		private function testForCrit( item:DamageObject, index:int, vector:Vector.<DamageObject> ):Boolean
		{
			return (item.details == OutcomeTypes.CRIT);
		}
		
		private function filterDuplicates(chars:Vector.<Character>):void
		{
			for (var i:int = 0; i < chars.length; i++)
			{
				var char:Character = chars[i];
				for (var j:int = i + 1; j < chars.length; )	//no j++
				{
					var char2:Character = chars[j];
					if (char == char2)
						chars.splice(j, 1);
					else
						j++;
				}
			}
		}
		
		/**
		 * Returns an enemy of the Character passed in as 'char'. The last target of each Team
		 * is the default target automatically. If that Character has been KO'ed, another target is
		 * selected.
		 * @param	char who's turn it is; who you want an enemy of
		 * @return
		 */
		private function getDefaultTarget(char:Character):Character
		{
			var team:Team;	//which team char belongs to
			
			if (!char) return null;	//Character not provided
			
			if (!char.teamName)
			{
				if ( _heroes.belongsToTeam(char) )
					team = _heroes;
				else if ( _villains.belongsToTeam(char) )
					team = _villains;
			} else {
				if (char.teamName == Team.HERO)
					team = _heroes;
				else if (char.teamName == Team.VILLAIN)
					team = _villains;
			}
			
			if (!team) return null;	//Character's team couldn't be determined
			
			if (!team.defaultTarget || team.defaultTarget.hpCurrent < 1)	//select a new target, this one's null or KO'ed
			{
				var enemyTeam:Team = (team == _heroes) ? _villains : _heroes;
				
				if (enemyTeam && enemyTeam.currentWave)
				{
					for (var i:int = 0; i < enemyTeam.currentWave.length; i++)
					{
						if (enemyTeam.currentWave[i].hpCurrent > 0)
						{
							team.defaultTarget = enemyTeam.currentWave[i];	//new target selected
							break;
						}
					}
				}
			}
			
			return team.defaultTarget;
		}
		
		/**
		 * Returns an item ID chosen from Villain's and combat's loot tables if successful.
		 * Otherwise returns null.
		 * @param	target Villain who may drop loot
		 * @param	roll random number (0<= x < 1) determines what loot drops
		 * @param	killed if true allows items that drop on kill to occur
		 * @return
		 */
		private function rollForLoot(target:Villain, roll:Number, killed:Boolean = false):String
		{
			if (isNaN(roll))
				throw new Error("CombatEngine.rollForLoot not passed random roll!");
			
			//todo -- incorporate 'killed' logic
			var itemID:String;
			
			//combine target's and combat's loot tables
			var joinedLoot:Vector.<LootObject> = new Vector.<LootObject>();
			if (_lootTable)
				joinedLoot = joinedLoot.concat( _lootTable );
			if (target.lootTable)
				joinedLoot = joinedLoot.concat( target.lootTable );
			
			//calculate total probability of all LootObjects
			var sumProbability:Number = 0;
			var n:int = joinedLoot.length;
			for (var i:int = 0; i < n; i++)
				sumProbability += joinedLoot[i].probability;
			
			//in case 'sumProbability' isn't 1, have roll match its scale
			roll *= sumProbability;
			
			//determine which LootObject was chosen
			var c:Number = sumProbability;
			var loot:LootObject;
			for (i = 0; i < n; i++)
			{
				if (roll >= c - joinedLoot[i].probability)
				{
					loot = joinedLoot[i];
					break;
				}
				
				c -= joinedLoot[i].probability;	//c acts as additonal constant, creating tiers for each item in the 0-1 spectrum
			}
			
			//if a LootObject was chosen and it contained an item, remove it from future rolls
			if (loot && loot.itemID != null)
			{				
				itemID = loot.itemID;
				ServerData.itemsDropped.push(itemID);
				
				//reassign the lootObject with an empty ID so future drop rates aren't inflated
				loot.itemID = null;
			}
			
			return itemID;
		}
		
		/**
		 * Show xp gain/level up for actor if applicable (pretty hacky)
		 */
		private function displayActorXpGain(actorID:String):void
		{
			if (_actorLevelUp)
			{
				//dispatch "Level 2!" for actor
				var actor:Character = getCharacterByID(actorID);
				_event.dispatchEvent(new BattleUpdate(BattleUpdate.ONE_UP, { id : actorID, message : "<font size=\"32\">Level " + actor.level + "!</font>", color : 0xffcc00 } ));
				
				//update current and max HP/AP of their team
				var team:Team = _heroes.belongsToTeam(actor) ? _heroes : _villains;
				for each (var char:Character in _heroes.currentWave)
					if (char.hpCurrent > 0) dispatchVitals(char);				
			} else if (_actorXpGain > 0) {
				_event.dispatchEvent(new BattleUpdate(BattleUpdate.ONE_UP, { id : actorID, message : "+" + _actorXpGain + " XP", color : 0x88ccff } ));
			}
			_actorXpGain = 0;
			_actorLevelUp = false;
		}
		
		/**
		 * Utility function to update all visible vitals of a character. Use sparingly.
		 * @param	char
		 */
		private function dispatchVitals(char:Character):void
		{
			_event.dispatchEvent(new BattleUpdate(BattleUpdate.VITALS, { vitalsObj : new VitalsObject(char.id, StatTypes.HP_MAX, char.hpMax ) } ));
			_event.dispatchEvent(new BattleUpdate(BattleUpdate.VITALS, { vitalsObj : new VitalsObject(char.id, StatTypes.AP_MAX, char.apMax ) } ));
			_event.dispatchEvent(new BattleUpdate(BattleUpdate.VITALS, { vitalsObj : new VitalsObject(char.id, StatTypes.HP_CUR, char.hpCurrent ) } ));
			_event.dispatchEvent(new BattleUpdate(BattleUpdate.VITALS, { vitalsObj : new VitalsObject(char.id, StatTypes.AP_CUR, char.apCurrent ) } ));
		}
		
		/**
		 * Utility function used by carryOutAction() to keep most CombatLogger logic outside the CombatEngine core.
		 * @param	actionID
		 * @param	actionLevel
		 * @param	actor
		 * @param	targets
		 * @param	counter
		 */
		private function newActionLog(actionID:String, actionLevel:int, actor:Character, targets:Vector.<Character>, counter:Boolean):void
		{	
			//re-initialize _actionHash
			_actionHash["actionID"] = actionID;
			_actionHash["actionLevel"] = actionLevel;
			_actionHash["actor"] = actor;
			_actionHash["targets"] = targets;
			_actionHash["counter"] = counter;
		}
		
		/**
		 * Related to newActionLog(). Keeps a hash record of Character deltas as carryOutAction() calculates outcomes.
		 * @param	charID
		 * @param	details
		 */
		private function updateOutcome(charID:String, details:Object):void
		{
			var outcome:Object = _outcomeHash[charID];
			
			if (!outcome)
			{
				outcome = { };
				_outcomeHash[charID] = outcome;
			}
			
			for (var key:* in details)
				outcome[key] = details[key];
		}
		
		/**
		 * Related to newActionLog(). Finalizes and records the logging for the current action being run in carryOutAction().
		 */
		private function commitActionLog():void
		{
			var actionID:String = _actionHash["actionID"];
			var actionLevel:int = _actionHash["actionLevel"];
			var counter:Boolean = _actionHash["counter"];
			var actor:Character = _actionHash["actor"];
			var targets:Array = [];
			var outcomes:Array = [];
			
			//make targets Array
			for each (var target:Character in _actionHash["targets"] as Vector.<Character>)
			{
				targets.push( { id : target.id, team : target.teamName } );
			}
			
			//make outcomes Array
			for (var key:* in _outcomeHash)
			{
				var outcome:Object = _outcomeHash[key];
				outcomes.push( _log.formatOutcomeNode(key, getCharacterByID(key).teamName, outcome["hpDelta"], outcome["apDelta"], outcome["xpDelta"], outcome["status"], outcome["loot"]));
			}
			
			_log.logAction(actionID, actionLevel, { id : actor.id, team : actor.teamName }, targets, outcomes, counter);
			
			//clean up hashes
			for (key in _actionHash)
				delete _actionHash[key];
			for (key in _outcomeHash)
				delete _outcomeHash[key];
		}
	}

}