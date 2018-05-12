import haxe.io.Bytes;
import haxe.PosInfos;
import format.bmp.Reader;
import format.bmp.Data;
import format.bmp.Data.Header;
import format.bmp.Tools;
import format.png.Writer;
import haxe.unit.TestCase;
import haxe.unit.TestRunner;

using StringTools;
using Lambda;


typedef ExpectedValues = {
	size : { w:Int, h:Int },             // actual size of BMP
	dataLength : Int,                    // byteLength including padding
	pixelPos : Array<{ x:Int, y:Int }>,  // pixels to test (top to bottom)
	pixelBGR : Array<Int>,               // BGR value of pixels at pixelPos in Data.pixels
	pixelBGRA : Array<Int>,              // BGRA value of pixels at pixelPos after extractBGRA()
	pixelARGB : Array<Int>,              // ARGB value of pixels at pixelPos after extractARGB()
}

class Tests extends TestCase
{
	var expected:Map<String, ExpectedValues> = [
		"bgrw.bmp" => {
			size : { w:2, h:2 },
			dataLength : 16,
			pixelPos : [ {x:  1, y:  1}, {x:  0, y:  1} ],
			pixelBGR : [   0x00FFFFFF  ,   0x000000FF   ],
			pixelBGRA: [   0xFFFFFFFF  ,   0x0000FFFF   ],
			pixelARGB: [   0xFFFFFFFF  ,   0xFFFF0000   ],
		},
		"lena.bmp" => {
			size : { w:199, h:199 },
			dataLength : 119400,
			pixelPos : [ {x:  1, y:  1}, {x:198, y:198} ],
			pixelBGR : [   0x004D71C5,     0x00252745   ],
			pixelBGRA: [   0x4D71C5FF  ,   0x252745FF   ],
			pixelARGB: [   0xFFC5714D  ,   0xFF452725   ],
		},
		"xing_b24.bmp" => {
			size : { w:240, h:164 },
			dataLength : 118080,
			pixelPos : [ {x:  1, y:  1}, {x: 64, y:152} ],
			pixelBGR : [   0x002D6829  ,   0x0093FDF7   ],
			pixelBGRA: [   0x2D6829ff  ,   0x93FDF7FF   ],
			pixelARGB: [   0xff29682D  ,   0xFFF7FD93   ],
		},
		"xing_toptobottom.bmp" => {
			size : { w:240, h:164 },
			dataLength : 118080,
			pixelPos : [ {x:  1, y:163-1}, {x: 64, y:163-152} ],
			pixelBGR : [   0x002D6829  ,   0x0093FDF7   ],
			pixelBGRA: [   0x2D6829ff  ,   0x93FDF7FF   ],
			pixelARGB: [   0xff29682D  ,   0xFFF7FD93   ],
		},
	];

	var data:Map<String, Data> = new Map();
  
  
	static function main() {
		#if ((haxe_ver < 4) && php)
		// uncaught exception: The each() function is deprecated. This message will be suppressed on further calls (errno: 8192)
		// in file: /Users/travis/build/andyli/hscript/bin/lib/Type.class.php line 178
		untyped __php__("error_reporting(E_ALL ^ E_DEPRECATED);");
		#end

		var testRunner = new TestRunner();
		testRunner.add(new Tests());
		var succeed = testRunner.run();
		#if sys
			Sys.exit(succeed ? 0 : 1);
		#elseif flash
			flash.system.System.exit(succeed ? 0 : 1);
		#else
			if (!succeed)
				throw "failed";
		#end
	}
  
	override function setup() {
		for (k in expected.keys()) {
			if (!data.exists(k)) {
				var input = new haxe.io.BytesInput(haxe.Resource.getBytes(k));
				data[k] = new Reader(input).read();
				_assertTrue(data[k] != null, k);
			}
		}
		_assertTrue(Lambda.count(expected) >= Lambda.count(data), "count");
	}
  
	public function testSize() {
		for (k in expected.keys()) {
			var header = data[k].header;
			_assertEquals(expected[k].size.w, header.width, k + " width");
			_assertEquals(expected[k].size.h, header.height, k + " height");
		}
	}
  
	public function testDataLength() {
		for (k in expected.keys()) {
			var header = data[k].header;
			var pixels = data[k].pixels;
			_assertEquals(expected[k].dataLength, header.dataLength, k + " dataLength");
			_assertEquals(expected[k].dataLength, pixels.length, k + " pixels.length");
			_assertEquals(expected[k].dataLength, header.paddedStride * header.height, k + " paddedStride * height");
		}
	}
  
	public function testBGR() {
		for (k in expected.keys()) {
			for (i in 0...Lambda.count(expected[k].pixelPos)) {
				var pixelCoord = expected[k].pixelPos[i];
				var bgr = PixelTools.getBGR(data[k], pixelCoord.x, pixelCoord.y);
				assertHexEquals(expected[k].pixelBGR[i], bgr, k + "@" + pixelCoord);
			}
		}
	}
	
	public function testBGRA() {
		for (k in expected.keys()) {
			var header = data[k].header;
			var bytesBGRA = Tools.extractBGRA(data[k]);
			for (i in 0...Lambda.count(expected[k].pixelPos)) {
				var pixelCoord = expected[k].pixelPos[i];
				var bgra = PixelTools.getInt32(bytesBGRA, pixelCoord.x, pixelCoord.y, header.width);
				assertHexEquals(expected[k].pixelBGRA[i], bgra, k + "@" + pixelCoord);
			}
		}
	}
	
	public function testARGB() {
		for (k in expected.keys()) {
			var header = data[k].header;
			var bytesARGB = Tools.extractARGB(data[k]);
			for (i in 0...Lambda.count(expected[k].pixelPos)) {
				var pixelCoord = expected[k].pixelPos[i];
				var argb = PixelTools.getInt32(bytesARGB, pixelCoord.x, pixelCoord.y, header.width);
				assertHexEquals(expected[k].pixelARGB[i], argb, k + "@" + pixelCoord);
			}
		}
	}
	
	public function testBuilt_vs_Read() {
		for (k in expected.keys()) {
			var header = data[k].header;

			var extractedARGB = Tools.extractARGB(data[k]);
			var builtFromARGB = Tools.buildFromARGB(header.width, header.height, extractedARGB, header.topToBottom);
			assertBytesEquals(data[k].pixels, builtFromARGB.pixels, k + " ARGB");

			var extractedBGRA = Tools.extractBGRA(data[k]);
			var builtFromBGRA = Tools.buildFromBGRA(header.width, header.height, extractedBGRA, header.topToBottom);
			assertBytesEquals(data[k].pixels, builtFromBGRA.pixels, k + " BGRA");
		}
	}
  
#if sys
	public function testWritten_vs_Read() {
		for (k in expected.keys()) {
			var header = data[k].header;

			var extractedARGB = Tools.extractARGB(data[k]);
			var builtFromARGB = Tools.buildFromARGB(header.width, header.height, extractedARGB, header.topToBottom);

			var outFile = sys.io.File.write("out_" + k, true);
			var bmpWriter = new format.bmp.Writer(outFile);
			bmpWriter.write(builtFromARGB);
			outFile.close();

			var inFile = sys.io.File.read("out_" + k, true);
			var bmpReader = new format.bmp.Reader(inFile);
			var writtenData = bmpReader.read();
			inFile.close();
			assertBytesEquals(data[k].pixels, writtenData.pixels, k + " ARGB");


			var extractedBGRA = Tools.extractBGRA(data[k]);
			var builtFromBGRA = Tools.buildFromBGRA(header.width, header.height, extractedBGRA, header.topToBottom);

			outFile = sys.io.File.write("out_" + k, true);
			bmpWriter = new format.bmp.Writer(outFile);
			bmpWriter.write(builtFromBGRA);
			outFile.close();

			inFile = sys.io.File.read("out_" + k, true);
			bmpReader = new format.bmp.Reader(inFile);
			writtenData = bmpReader.read();
			inFile.close();
			assertBytesEquals(data[k].pixels, writtenData.pixels, k + " BGRA");
		}
	}
#end

#if flash
	public function testToBitmap():Void {
		var y = 50;
		var offset = 10;
		for (k in expected.keys()) {
			var header = data[k].header;
			var bmd = new flash.display.BitmapData(header.width, header.height, false);
			var bmp = new flash.display.Bitmap(bmd);
			bmp.x = offset; bmp.y = y;
			flash.Lib.current.addChildAt(bmp, 0);
			var bytes = Tools.extractARGB(data[k]);
			var byteArray = bytes.getData();
			byteArray.endian = flash.utils.Endian.BIG_ENDIAN;
			bmd.setPixels(bmd.rect, byteArray);
			for (i in 0...Lambda.count(expected[k].pixelPos)) {
				var pixelCoord = expected[k].pixelPos[i];
				var argb = bmd.getPixel32(pixelCoord.x, pixelCoord.y);
				assertHexEquals(expected[k].pixelARGB[i], argb, k + "@" + pixelCoord);
			}
			offset += bmd.width + 5;
		}
	}
#end

	// wrap asserts to show optional msg

	function _assertTrue(b:Bool, ?c:PosInfos, ?msg:String):Void {
		try {
			super.assertTrue(b, c);
		} catch (err:Dynamic) {
			if (msg != null) currentTest.error = msg + ": " + currentTest.error;
			throw currentTest;
		}
	}
  
	function _assertEquals<T>(expected:T, actual:T, ?c:PosInfos, ?msg:String):Void	{
		try {
			super.assertEquals(expected, actual, c);
		} catch (err:Dynamic) {
			if (msg != null) currentTest.error = msg + ": " + currentTest.error;
			throw currentTest;
		}
	}
    
	function assertHexEquals(expected:Int, actual:Int, ?c:PosInfos, ?msg:String):Void	{
		try {
			super.assertEquals("0x" + expected.hex(8), "0x" + actual.hex(8), c);
		} catch (err:Dynamic) {
			if (msg != null) currentTest.error = msg + ": " + currentTest.error;
			throw currentTest;
		}
	}

	function assertBytesEquals(expected:Bytes, actual:Bytes, ?c:PosInfos, ?msg:String):Void	{
		_assertEquals(expected.length, actual.length, msg + " length");
		for (i in 0...expected.length) _assertEquals(expected.get(i), actual.get(i), msg + " byte@" + i);
	}
}


class PixelTools {
	static public function getBGR(data:Data, x:Int, y:Int):Int {
		var pixels = data.pixels;
		var header = data.header;
		var bytesPerPixel = 24 >> 3;

		var pos = header.topToBottom ? y * header.paddedStride : header.dataLength - (y + 1) * header.paddedStride;
		pos += x * bytesPerPixel;

		var b = pixels.get(pos + 0);
		var g = pixels.get(pos + 1);
		var r = pixels.get(pos + 2);

		return (b << 16) | (g << 8) | r;
	}
  
	static public function getInt32(data:Bytes, x:Int, y:Int, width:Int):Int {
		var bytesPerPixel = 32 >> 3;

		var pos = (y * width + x) * bytesPerPixel;

		var b0 = data.get(pos + 0);
		var b1 = data.get(pos + 1);
		var b2 = data.get(pos + 2);
		var b3 = data.get(pos + 3);

		return (b0 << 24) | (b1 << 16) | (b2 << 8) | b3;
	}
  
	static public function toString(data:Bytes, pos:Int, ?len:Int):String {
		var str = "[";
		
		if (len == null) len = data.length - pos;
		else len = Std.int(Math.min(len, data.length - pos));
		
		var sub = data.sub(pos, len);
		for (i in 0...len) str += data.get(pos + i).hex(2) + " ";
		str += "]";
		
		return str;
	}
}