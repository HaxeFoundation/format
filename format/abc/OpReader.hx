package format.abc;
import format.abc.Data;
import haxe.Int32;

class OpReader {

	public var i : haxe.io.Input;

	public function new(i) {
		this.i = i;
	}

	public function readInt() {
		var a = i.readByte();
		if( a < 128 )
			return a;
		a &= 0x7F;
		var b = i.readByte();
		if( b < 128 )
			return (b << 7) | a;
		b &= 0x7F;
		var c = i.readByte();
		if( c < 128 )
			return (c << 14) | (b << 7) | a;
		c &= 0x7F;
		var d = i.readByte();
		if( d < 128 )
			return (d << 21) | (c << 14) | (b << 7) | a;
		d &= 0x7F;
		var e = i.readByte();
		if( e > 15 ) throw "assert";
		if( ((e & 8) == 0) != ((e & 4) == 0) ) throw haxe.io.Error.Overflow;
		return (e << 28) | (d << 21) | (c << 14) | (b << 7) | a;
	}

	public function readInt32() : Int32 {
		var a = i.readByte();
		if( a < 128 )
			return Int32.ofInt(a);
		a &= 0x7F;
		var b = i.readByte();
		if( b < 128 )
			return Int32.ofInt((b << 7) | a);
		b &= 0x7F;
		var c = i.readByte();
		if( c < 128 )
			return Int32.ofInt((c << 14) | (b << 7) | a);
		c &= 0x7F;
		var d = i.readByte();
		if( d < 128 )
			return Int32.ofInt((d << 21) | (c << 14) | (b << 7) | a);
		d &= 0x7F;
		var e = i.readByte();
		if( e > 15 ) throw "assert";
		var small = Int32.ofInt((d << 21) | (c << 14) | (b << 7) | a);
		var big = Int32.shl(Int32.ofInt(e),28);
		return Int32.or(big,small);
	}

}
