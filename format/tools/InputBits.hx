package format.tools;

class InputBits {

	var i : haxe.io.Input;
	var nbits : Int;
	var bits : Int;

	public function new(i) {
		this.i = i;
		nbits = 0;
		bits = 0;
	}

	public function readBits(n) {
		if( nbits >= n ) {
			var c = nbits - n;
			var k = (bits >>> c) & ((1 << n) - 1);
			nbits = c;
			return k;
		}
		var k = i.readByte();
		if( nbits >= 24 ) {
			if( n >= 31 ) throw "Bits error";
			var c = 8 + nbits - n;
			var d = bits & ((1 << nbits) - 1);
			d = (d << (8 - c)) | (k << c);
			bits = k;
			nbits = c;
			return d;
		}
		bits = (bits << 8) | k;
		nbits += 8;
		return readBits(n);
	}

	public function read() {
		if( nbits == 0 ) {
			bits = i.readByte();
			nbits = 8;
		}
		nbits--;
		return ((bits >>> nbits) & 1) == 1;
	}

	public inline function reset() {
		nbits = 0;
	}

}

