package 
{
  
   import flash.utils.ByteArray;
   import flash.utils.Dictionary;
   import avmplus.*;
   import avmplus.File;
   import avmplus.Zmq;
   import avmplus.Mongrel;

   public class MongrelTest
   {
      public function MongrelTest() {
      }
      
              
      public static function echoString(str:String):String
      {
         return str;
      }
      
      public static function echoDict(dict:Dictionary):Dictionary
      {
         return dict;
      }
   }
   
   var mongrel:Mongrel = new Mongrel;
   var message:ByteArray;
   var reply:ByteArray;
   mongrel.connect('82209006-86FF-4982-B5EA-D1E29E55D481','tcp://127.0.0.1:9997','tcp://127.0.0.1:9996');
   
   while (true)
   {
      message = mongrel.receive();
      trace('got',message.toString());
      reply = new ByteArray();
      reply.writeUTFBytes('hello from mongrel handler');
      mongrel.send(reply);
   }
   
   
   
}