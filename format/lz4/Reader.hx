package format.lz4;

class Reader {

	var bytes : haxe.io.Bytes;
	var pos : Int;
	
	public function new() {
	}
	
	inline function b() {
		return bytes.get(pos++);
	}
	
	function grow( out : haxe.io.Bytes, pos : Int, len : Int ) {
		var size = out.length;
		do {
			size = (size * 3) >> 1;
		} while( size < pos + len );
		var out2 = haxe.io.Bytes.alloc(size);
		out2.blit(0, out, 0, pos);
		return out2;
	}
	
	public function read( bytes : haxe.io.Bytes ) : haxe.io.Bytes {
		this.bytes = bytes;
		this.pos = 0;
		if( b() != 0x04 || b() != 0x22 || b() != 0x4D || b() != 0x18 )
			throw "Invalid header";
		var flags = b();
		
		if( flags >> 6 != 1 )
			throw "Invalid version " + (flags >> 6);
		var blockChecksum = flags & 16 != 0;
		var streamSize = flags & 8 != 0;
		var streamChecksum = flags & 4 != 0;
		if( flags & 2 != 0 ) throw "assert";
		var presetDict = flags & 1 != 0;
		
		var bd = b();
		if( bd & 128 != 0 ) throw "assert";
		var maxBlockSize = [0, 0, 0, 0, 1 << 16, 1 << 18, 1 << 20, 1 << 22][(bd >> 4) & 7];
		if( maxBlockSize == 0 ) throw "assert";
		if( bd & 15 != 0 ) throw "assert";
		
		if( streamSize )
			pos += 8;
		if( presetDict )
			throw "Preset dictionary not supported";
		
		var headerChk = b(); // does not check
		
		var out = haxe.io.Bytes.alloc(128);
		var outPos = 0;
		
		while( true ) {
			var size = b() | (b() << 8) | (b() << 16) | (b() << 24);
			if( size == 0 ) break;
			// skippable chunk
			if( size & 0xFFFFFFF0 == 0x184D2A50 ) {
				var dataSize = b() | (b() << 8) | (b() << 16) | (b() << 24);
				pos += dataSize;
				continue;
			}
			if( size & 0x80000000 != 0 ) {
				// uncompressed block
				size &= 0x7FFFFFFF;
				if( outPos + out.length < size ) out = grow(out,outPos, size);
				out.blit(outPos, bytes, pos, size);
				outPos += size;
				pos += size;
			} else {
				if( outPos + out.length < size ) out = grow(out, outPos, 3000000);
				outPos += Uncompress.run(bytes, pos, size, out, outPos);
				pos += size;
			}
			if( blockChecksum ) pos += 4;
		}
		
		return out.sub(0, outPos);
	}
	
}