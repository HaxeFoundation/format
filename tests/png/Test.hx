class Test {

	static function main() {

		var i = sys.io.File.read("read.png",true);
		var data = new format.png.Reader(i).read();

/*
		var bytes = format.png.Tools.extract32(data);
		var h = format.png.Tools.getHeader(data);
		data = format.png.Tools.build32(h.width,h.height,bytes);
*/

		var out = sys.io.File.write("testRead.png",true);
		new format.png.Writer(out).write(data);

		var size = 63;
		var bytes = new haxe.io.BytesOutput();
		for( y in 0...size )
			for( x in 0...size ) {
				var color = (x*3) | ((y*3) << 8) | 0xFF000000;
				bytes.writeInt32(color);
			}
		var data = format.png.Tools.build32LE(size,size,bytes.getBytes());

		var out = sys.io.File.write("test32.png",true);
		new format.png.Writer(out).write(data);
	}

}