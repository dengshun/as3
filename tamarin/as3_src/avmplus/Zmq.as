package avmplus
{
   import flash.utils.ByteArray;
	
   [native(cls="ZmqClass", instance="ZmqObject", methods="auto")]
   public class Zmq
   {
      public static const PAIR:int = 0;
      public static const PUB:int = 1;
      public static const SUB:int = 2;
      public static const REQ:int = 3;
      public static const REP:int = 4;
      public static const ROUTER:int = 5;
      public static const XREQ:int = 5
      public static const DEALER:int = 6;
      public static const XREP:int = 6;
      public static const PULL:int = 7;
      public static const UPSTREAM:int = 7;
      public static const PUSH:int = 8;
      public static const DOWNSTREAM:int = 8;

      //public function Zmq ()
      //{
      //}
		
      public native function init(io_threads:int, singleton_context:Boolean):Boolean;
      public native function connect(address:String, type:int):Boolean;
      public native function receive():ByteArray;
      public native function send(message:ByteArray):Boolean;
      public native function disconnect():Boolean;
		
		
   };
};