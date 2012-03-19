package avmplus
{
   import flash.utils.ByteArray;
	
   [native(cls="MongrelClass", instance="MongrelObject", methods="auto")]
   public class Mongrel
   {
     	
      public native function connect(senderId:String, subAddress:String, pubAddress:String):Boolean;
      public native function receive():ByteArray;
      public native function send(message:ByteArray):Boolean;
		
   }
}