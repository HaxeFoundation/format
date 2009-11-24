class Test {

	static function main() {

		var i = neko.io.File.read("read.png",true);
		var data = new format.png.Reader(i).read();

/*
		var bytes = format.png.Tools.extract32(data);
		var h = format.png.Tools.getHeader(data);
		data = format.png.Tools.build32(h.width,h.height,bytes);
*/

		var out = neko.io.File.write("testRead.png",true);
		new format.png.Writer(out).write(data);

		var size = 63;
		var bytes = new haxe.io.BytesOutput();
		for( y in 0...size )
			for( x in 0...size ) {
				var color = (x*3) | ((y*3) << 8);
				var alpha = 0xFF;
				bytes.writeInt32(haxe.Int32.or(haxe.Int32.make(alpha<<8,0),haxe.Int32.ofInt(color)));
			}
		var data = format.png.Tools.build32LE(size,size,bytes.getBytes());

		var out = neko.io.File.write("test32.png",true);
		new format.png.Writer(out).write(data);
	}

}