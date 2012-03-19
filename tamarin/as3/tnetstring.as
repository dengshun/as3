//http://tnetstrings.org/
//
//Copyright <2011> <Chris Ochs>. All rights reserved.
//
//Redistribution and use in source and binary forms, with or without modification, are
//permitted provided that the following conditions are met:
//
//   1. Redistributions of source code must retain the above copyright notice, this list of
//      conditions and the following disclaimer.
//
//   2. Redistributions in binary form must reproduce the above copyright notice, this list
//      of conditions and the following disclaimer in the documentation and/or other materials
//      provided with the distribution.
//
//THIS SOFTWARE IS PROVIDED BY <CHRIS OCHS> ``AS IS'' AND ANY EXPRESS OR IMPLIED
//WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
//FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL <CHRIS OCHS> OR
//CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
//CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
//SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
//ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
//NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
//ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
//The views and conclusions contained in the software and documentation are those of the
//authors and should not be interpreted as representing official policies, either expressed
//or implied, of <Chris Ochs>.
   
package
{
   import flash.utils.ByteArray;
   import avmplus.*;
   import flash.utils.Dictionary;
   
   public class TNetstring
   {
      public static const STRING:String = ',';
      public static const INT:String = '#';
      public static const BOOL:String = '!';
      public static const NULL:String = '~';
      public static const DICT:String = '}';
      public static const ARRAY:String = ']';
           
      public function TNetstring()
      {
      }
      
      public static function encode(obj:*):ByteArray
      {
         var tns:TNetstring = new TNetstring();
         var result:* = tns._encode(obj);
         return result;
      }
      
      public static function decode(data:ByteArray):Array
      {
         data.position = 0;
         var tns:TNetstring = new TNetstring();
         var result:Array = tns._decode(data);
         return result;
      }
            
      private function _encode(obj:*,bytes:ByteArray=null):ByteArray
      {
         var payload:ByteArray;
          
         if (bytes == null)
         {
            bytes = new ByteArray();
         }
        
         
         if (obj is String)
         {
            this.writeStringToByteArray(obj.length + ":" + obj + STRING,bytes);
         }
         else if (obj is int)
         {
            this.writeStringToByteArray(obj.toString().length + ":" + obj + INT,bytes);
         }
         else if (obj is Boolean)
         {
            this.writeStringToByteArray(obj.toString().length + ":" + obj + BOOL,bytes);
         }
         else if (obj === null)
         {
            this.writeStringToByteArray(0 + ":" + NULL,bytes);
         }
         else if (obj is Dictionary)
         {
            payload = this.writeDict(obj);
            payload.position = 0;
            this.writeStringToByteArray(payload.length + ":",bytes);
            bytes.writeBytes(payload);
            this.writeStringToByteArray(DICT,bytes);
         }
         else if (obj is Array)
         {
            payload = this.writeArray(obj);
            payload.position = 0;
            this.writeStringToByteArray(payload.length + ":",bytes);
            bytes.writeBytes(payload);
            this.writeStringToByteArray(ARRAY,bytes);
         }
         return bytes;  
      }
            
      public function writeDict(obj:Dictionary):ByteArray
      {
         var payload:ByteArray = new ByteArray;
         for (var k:String in obj)
         {
            this._encode(k.toString(),payload); 
            this._encode(obj[k],payload);   
         }
         return payload;
      }
      
      public function writeArray(obj:Array):ByteArray
      {
         var payload:ByteArray = new ByteArray;
         var len:int = obj.length;
         for (var y:int = 0; y<len; y++)
         {
            this._encode(obj[y],payload); 
         }
         return payload;
      }
      
      private function _decode(data:ByteArray):Array
      {
         var result:Array = decodeOne(data);
         var len:int = result[0];
         var type:String = result[1];
         var payload:ByteArray = result[2];
         
         if (type == '#')
         {
            return [parseInt(payload.readUTFBytes(len)),data];   
         }
         else if (type == '}')
         {
            return [decodeDict(payload),data];      
         }
         else if (type == ']')
         {
            return [decodeArray(payload),data];    
         }
         else if (type == '!')
         {
            return [(payload.readUTFBytes(len) == 'true'),data];
         }
         else if (type == '~')
         {
            return [null,data];      
         }
         else if (type == ',')
         {
            return [payload.readUTFBytes(len),data];     
         }
         return [undefined,data];
      }
      
      
      private function decodeDict(payload:ByteArray):Dictionary
      {
         var result:Dictionary = new Dictionary();
         var decoded:Array;
         var key:String;
         while (payload.bytesAvailable > 0)
         {
            decoded = this._decode(payload);
            key = decoded[0] as String;
            payload = decoded[1] as ByteArray;
            decoded = this._decode(payload);
            payload = decoded[1] as ByteArray;
            result[key] = decoded[0];
         }
         return result;
      }
      
      private function decodeArray(payload:ByteArray):Array
      {
         var result:Array = new Array();
         while (payload.bytesAvailable > 0)
         {
            var decoded:Array = this._decode(payload);
            result.push(decoded[0]);
            payload = decoded[1] as ByteArray;
         }
         return result;
      }
      
      private function decodeOne(data:ByteArray):Array
      {
         var size:String = '';
         var byte:String;
         var len:int;
         var type:String;
         var value:ByteArray = new ByteArray;
         
         for (var y:int = 0; y<10; y++) {
            byte = data.readUTFBytes(1);
            if (byte == ':')
            {
               break;
            }
            else
            {
               size = size + byte;    
            }
         }
         len = parseInt(size);
         if (len > 0) data.readBytes(value,0,len);
         type = data.readUTFBytes(1);
         value.position = 0;
         return [len,type,value];
      }
      
      public function writeStringToByteArray(s:String,ba:ByteArray):void {
         for (var i:uint = 0; i < s.length; ++i) {
            ba.writeByte(s.charCodeAt(i));
         }
      }
   }
      
}