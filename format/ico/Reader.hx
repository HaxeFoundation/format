package format.ico;

import format.ico.Data;
import format.ico.DIB;

class Reader {

	var input : haxe.io.Input;

	inline function readUInt16() return input.readUInt16();
	inline function readInt32() return input.readInt32();
	inline function readByte() return input.readByte();

	public function new(i) {
		input = i;
		input.bigEndian = false;
	}

	public function read() : ICORoot {
		var root = new ICORoot();
		root.reserved = readUInt16();
		root.type = cast readUInt16();
		root.count = readUInt16();

		if (root.reserved != 0)
			return root; // empty

		for (i in 0...root.count) {
			var entry = new ICOEntry();
			entry.width        = readByte();
			entry.height       = readByte();
			entry.colorCount   = readByte();
			entry.reserved     = readByte();
			entry.planes       = readUInt16();
			entry.bitCount     = readUInt16();
			entry.size         = readInt32();
			entry.offset       = readInt32();
			root.entries.push(entry);
		}

		for (entry in root.entries) {
			var bmp = haxe.io.Bytes.alloc(entry.size);
			input.readBytes(bmp, 0, entry.size);

			if (bmp.getInt32(0) == PNG_SIGN) {
				root.datas.push( PNG(bmp) );
				continue;
			}

			var info = new BMPInfo();
			info.sizeof        = bmp.getInt32(0);
			info.width         = bmp.getInt32(1 * 4);
			info.height        = bmp.getInt32(2 * 4);
			info.planes        = bmp.getUInt16(3 * 4);
			info.bitCount      = bmp.getUInt16(3 * 4 + 2);
			info.compression   = bmp.getInt32(4 * 4);
			info.sizeImage     = bmp.getInt32(5 * 4);
			info.xPelsPerMeter = bmp.getInt32(6 * 4);
			info.yPelsPermeter = bmp.getInt32(7 * 4);
			info.clrUsed       = bmp.getInt32(8 * 4);
			info.clrImportant  = bmp.getInt32(9 * 4);

			var image = new DIB(bmp, info);
			root.datas.push(DIB(image));
		}
		input = null;
		return root;
	}

	static inline var PNG_SIGN = 0x89 | ("P".code << 8) | ("N".code << 16) | ("G".code << 24);
}
