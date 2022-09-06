package format.ico;

import format.ico.DIB;

enum Data {
	DIB( d : DIB );
	PNG( b : haxe.io.Bytes );
}

class ICORoot {
	public var reserved : Int;      // WORD, Reserved (must be 0)
	public var type  : ICOType;     // WORD
	public var count : Int;         // WORD, length of entries
	public var entries : Array<ICOEntry>;
	public var datas : Array<Data>;
	public function new() {
		entries = [];
		datas = [];
	}
}

class ICOEntry {
	public var width : Int;         // BYTE
	public var height : Int;        // BYTE
	public var colorCount : Int;    // BYTE
	public var reserved : Int;      // BYTE
	public var planes : Int;        // WORD, (x hotspot if CURSOR)
	public var bitCount : Int;      // WORD, (y hotspot if CURSOR)
	public var size : Int;          // DWORD
	public var offset : Int;        // DWORD
	public function new() {
	}
}

extern enum abstract ICOType(Int) to Int {
	var ICON = 1;
	var CURSOR = 2;
}
