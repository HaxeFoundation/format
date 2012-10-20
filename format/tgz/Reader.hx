package format.tgz;

class Reader {

	var i : haxe.io.Input;

	public function new(i) {
		this.i = i;
	}

	public function read() : Data {
		var tmp = new haxe.io.BytesOutput();
		var gz = new format.gz.Reader(i);
		gz.readHeader();
		gz.readData(tmp);
		return new format.tar.Reader(new haxe.io.BytesInput(tmp.getBytes())).read();
	}

}

