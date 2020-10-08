import utest.Assert;

import format.amf3.Reader;
import format.amf3.Writer;
import format.amf3.Tools;
import format.amf3.Value;


class TestAmf3 {
	public static function main() {
		utest.UTest.run([new TestObject()]);
	}
}

class TestObject extends utest.Test {
	private var obj = { a: [1, 2, 3], b: 1, c: 1.1, d: "string", e: true, f: null };

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

class Aux {
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