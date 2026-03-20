import utest.Assert;

import format.amf3.Reader;
import format.amf3.Writer;
import format.amf3.Tools;
import format.amf3.Value;


class TestAmf3 {
	public static function main() {
		utest.UTest.run([new TestObject(), new TestUtf8()]);
	}
}

class TestObject extends utest.Test {
	private var obj = { a: [1, 2, 3], b: 1, c: 1.1, d: Aux.str, e: true, f: null };

	function testWriteRead() {
		// write
		var output = new haxe.io.BytesOutput();
		var writer = new Writer(output);
		writer.write(Tools.encode(obj));
		var bytes = output.getBytes();

		// read
		var input = new haxe.io.BytesInput(bytes, 0);
		var reader = new Reader(input);
		var decodedObj = Aux.unwrap(reader.read());

		Assert.same(obj, decodedObj);
	}
}

class TestUtf8 extends utest.Test {

	function testWriteRead() {
		// write
		var output = new haxe.io.BytesOutput();
		var writer = new Writer(output);
		writer.write(Tools.encode(Aux.str));
		var bytes = output.getBytes();

		Assert.equals(Aux.str_expected_amf, bytes.toHex());

		// read
		var input = new haxe.io.BytesInput(bytes, 0);
		var reader = new Reader(input);
		var decodedStr = Aux.unwrap(reader.read());

		Assert.equals(Aux.str, decodedStr);
	}
}

class Aux {
	// Test multi-byte chars only in haxe4 (the amf3 Writer is broken for multi-byte chars in haxe3)
	#if haxe4
	public static var str = "Οὐχὶ ταὐτὰ παρίσταταί μοι γιγνώσκειν, ὦ ἄνδρες ᾿Αθηναῖοι";
	public static var str_expected_amf = "068167ce9fe1bd90cf87e1bdb620cf84ceb1e1bd90cf84e1bdb020cf80ceb1cf81e1bdb7cf83cf84ceb1cf84ceb1e1bdb720cebccebfceb920ceb3ceb9ceb3cebde1bdbdcf83cebaceb5ceb9cebd2c20e1bda620e1bc84cebdceb4cf81ceb5cf8220e1bebfce91ceb8ceb7cebdceb1e1bf96cebfceb9";
	#else
	public static var str = "single byte string";
	public static var str_expected_amf = "062573696e676c65206279746520737472696e67";
	#end

	public static function unwrap(val:Value):Dynamic
	{
		return switch (val)
		{
			case ANumber(f): return f;
			case AInt(n): return n;
			case ABool(b): return b;
			case AString(s): return s;
			case AUndefined: return null;
			case ANull: return null;
			case AArray(vals): return vals.map(unwrap);
			case AVector(vals): return vals.map(unwrap);
			case AObject(vmap):
				var obj = {};
				for (name in vmap.keys())
				{
					Reflect.setField(obj, name, unwrap(vmap[name]));
				}
				return obj;
			default: throw "not implemented";
		}
	}
}