import flash.utils.Dictionary;
import flash.utils.ByteArray;

function test1() {
   var str:String = "hello";
   var t:Boolean = true;
   var f:Boolean = false;
   var dict:Dictionary = new Dictionary();
   var dict2:Dictionary = new Dictionary();
   var ar:Array = [0,'string1',"string2",4,t,f,7434534535,844444,-234,null];
   
   for (y=0; y<100; y++)
   {
      dict[y.toString()] = ar;
   }
   
   
   for (y=0; y<100; y++)
   {
      dict2[y.toString()] = dict;
   }
   
   var out:ByteArray = TNetstring.encode(dict2);
   
   
   var str1:String = out.toString();
   //trace(str1);
   out.position = 0;
   var decoded:Array = TNetstring.decode(out);
   var outdict:Dictionary = decoded[0] as Dictionary;
   var out2:ByteArray = TNetstring.encode(outdict);
   if (out2.toString() == out.toString())
   {
      trace('passed');
      //trace(JSON.stringify(outdict));
   }
}
   
function tnet()
{
   var bytes:ByteArray = new ByteArray();
   bytes.writeUTFBytes(Data.tnet);
   var decoded:Array = TNetstring.decode(bytes);
   trace('decoded');
   var outdict:Dictionary = decoded[0] as Dictionary;
   trace('copied to dict');
   var out2:ByteArray = TNetstring.encode(outdict); 
}
function json() {
      
   var startTime:Date = new Date();
   trace(Data.json.length);     
   var result:Object = JSON.parse(Data.json);
   var endTime:Date = new Date();
   trace("encode time "+String(endTime.getTime()-startTime.getTime())+" milliseconds");
}
   
function xml()
{
   var startTime:Date = new Date();
   var result:XML = new XML(Data.xml);
   var endTime:Date = new Date();
   trace("encode time "+String(endTime.getTime()-startTime.getTime())+" milliseconds"); 
}
tnet();
//xml();
//test1();
//json();