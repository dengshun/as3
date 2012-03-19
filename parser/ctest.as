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
		function destroy():void
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