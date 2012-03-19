
package 
{
  
   import flash.utils.ByteArray;
   import flash.utils.Dictionary;
   import avmplus.*;
   import avmplus.File;
   import avmplus.Zmq;
   import MessageBroker;

   public class MbTest extends MessageBroker
   {
      public function MbTest(_transport:String="inproc") {
         transport = _transport;	
      }
      
      override public function setup():ByteArray
      {
         var action:Dictionary = new Dictionary();
         action['c'] = 'AvmRunner';
         action['f'] = 'setup';
         sender.send(TNetstring.encode(action));
         var message:ByteArray = sender.receive();
         return message;
      }
      
      public static function loadXmlFromFile(filename:String):void
      {
         var bytes:ByteArray = File.readByteArray(filename);
         var xml:XML = new XML(bytes.toString());
         trace('xml file loaded',xml.toString().length);
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
   
   var broker:MbTest = new MbTest('ipc');
   broker.start();
   
   
}
