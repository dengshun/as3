package {
   import flash.utils.ByteArray;
   import avmplus.*;
   import avmplus.Zmq;
   import flash.utils.Dictionary;
   import TNetstring;
	
	
   public class MessageBroker {
      public var sender:Zmq;
      public var receiver:Zmq;
      public var transport:String;
      public static var IO_THREADS:int = 1;
		
      public function MessageBroker(_transport:String="inproc") {
         transport = _transport;	
      }
		
      public function start():void {
         main_loop(receiver);
      }
		
      public function setup():ByteArray
      {
         return null;
      }
        
      public function main_loop(receiver:Zmq):void {
         var message:ByteArray;
         var result:Object;
         var reply:ByteArray;
         var ioThreads:int;
         var sContext:Boolean;
         
         if (transport == 'inproc')
         {
            ioThreads = 0;
            sContext = true;
         }
         else
         {
            ioThreads = IO_THREADS;
            sContext = false;       
         }
         sender= new Zmq();
         sender.init(ioThreads,sContext);
         sender.connect(transport + "://router2", Zmq.REQ);
			
         receiver= new Zmq();
         receiver.init(ioThreads,sContext);
         receiver.connect(transport + "://dealer", Zmq.REP);
         
         message = setup();
         if (message != null)
         {
            dispatch(message);
         }
         
         while(true) {
            message=receiver.receive();
            try
            {
               result=dispatch(message)
               reply = TNetstring.encode(result);
            }
            catch( e:Error )
            {
               trace('Caught in main_loop',e.message);
               reply = TNetstring.encode(e.message);
            }
            receiver.send(reply);
         }
      }
		
      private function dispatch(message:ByteArray):Object {
         var result:Object;
         try
         {
            var parsed:Array = TNetstring.decode(message);
            var msg:Dictionary = parsed[0] as Dictionary;
            var Klass:Class=Domain.currentDomain.getClass(msg.c) as Class;
            var functionName:String=msg.f;
            var arguments:Array= new Array();
            for (var arg in msg.args) {
               arguments.push(msg.args[arg]);
            }
            result = Klass[functionName].apply(null, arguments);
         }
         catch( e:Error )
         {
            trace('Caught: ',e.message,e.getStackTrace());
            trace('message:',message.toString());
            return e.message;
         }
         return result;
      }
   }
}
