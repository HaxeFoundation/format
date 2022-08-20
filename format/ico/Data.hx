package format.ico;

// https://docs.fileformat.com/image/ico/

enum Data {
	DIB( d : DIB );
	PNG( b : haxe.io.Bytes );
}

private extern enum abstract ICOType(Int) to Int {
	var ICON = 1;
	var CURSOR = 2;
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

class DIB {
	public var data(default, null) : haxe.io.Bytes;
	public var info(default, null) : BMPInfo;
	public var ixor(default, null) : Int;
	public var iand(default, null) : Int;
	public var width(default, null) : Int;
	public var height(default, null) : Int;
	public var colors(default, null) : Array<Int>; // 0RGB
	public function new( data, info ) {
		this.data = data;
		this.info = info;
		this.width = info.width;
		this.height = info.height >> 1;
		this.ixor = info.findDIBBits();
		this.iand = this.ixor + this.height * info.bytesPerline();
		this.colors = [];
		var ptr = info.sizeof;
		var max = ptr + info.numberColors() * 4;
		while(ptr < max) {
			this.colors.push(data.getInt32(ptr));
			ptr += 4;
		}
	}
}

/**
 For .ico file format, Only the following members are used:

 sizeof, width, height, planes, bitCount, sizeImage. All other members must be 0.
*/
class BMPInfo {
	public var sizeof : Int;        // DWORD, size of the structure = 40
	public var width : Int;         // DWORD, width of the image in pixels
	public var height : Int;        // DWORD, height of the image in pixels, (negative: top-down, positive: bottom-up)
	public var planes : Int;        //  WORD, = 1
	public var bitCount : Int;      //  WORD, bits per pixel (1, 4, 8, 16, 24, or 32)
	public var compression : Int;   // DWORD, compression code
	public var sizeImage : Int;     // DWORD, number of bytes in image
	public var xPelsPerMeter : Int; // DWORD, horizontal resolution
	public var yPelsPermeter : Int; // DWORD, vertical resolution
	public var clrUsed : Int;       // DWORD, number of colors used
	public var clrImportant : Int;  // DWORD, number of important colors

	public function new() {
	}

	// Calculates the number of entries in the color table.
	public function numberColors() : Int {
		if (clrUsed > 0)
			return clrUsed;
		return switch(bitCount) {   // 1 << bitCount
		case 1:    2;
		case 4:   16;
		case 8:  256;
		default:   0;
		}
	}

	// Calculates the number of bytes in the color table.
	public inline function paletteSize() return numberColors() * 4;

	// Locate the image bits in a CF_DIB format DIB.
	public inline function findDIBBits() return sizeof + paletteSize();

	// Calculates the number of bytes in one scan line from Indexes
	public inline function bytesPerline() return WIDTHBYTES(width * bitCount);

	static public inline function WIDTHBYTES( bits ) return bits + 31 >> 5 << 2;
}
