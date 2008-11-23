import format.pbj.Data;

class Test {

	static function main() {
		var file = neko.Sys.args()[0];
		var bytes = neko.io.File.getBytes(file);
		// read
		var i = new haxe.io.BytesInput(bytes);
		var reader = new format.pbj.Reader(i);
		var p = reader.read();
		i.close();
		neko.Lib.println(format.pbj.Tools.dump(p));

		// calculate header size
		var o = new haxe.io.BytesOutput();
		var writer = new format.pbj.Writer(o);
		var code = p.code;
		p.code = new Array();
		writer.write(p);
		p.code = code;
		neko.Lib.println("HEADER-SIZE : "+o.getBytes().length);


		// write
		var o = new haxe.io.BytesOutput();
		var writer = new format.pbj.Writer(o);
		writer.write(p);
		var bytes2 = o.getBytes();

		var i = new haxe.io.BytesInput(bytes);
		var p2 = new format.pbj.Reader(i).read();
		if( format.pbj.Tools.dump(p) != format.pbj.Tools.dump(p2) )
			throw format.pbj.Tools.dump(p2);

		// check bytes
		if( bytes.length != bytes2.length )
			throw "Size differs "+bytes2.length+" should be "+bytes.length;
		for( i in 0...bytes.length )
			if( bytes.get(i) != bytes2.get(i) )
				throw "Byte "+i+" : 0x"+StringTools.hex(bytes2.get(i),2)+" should be 0x"+StringTools.hex(bytes.get(i),2);
	}

}