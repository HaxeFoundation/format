package format.lz4;

class Uncompress {

	public static function run( src : haxe.io.Bytes, srcPos : Int, srcLen : Int, out : haxe.io.Bytes, outPos : Int ) {
		var outSave = outPos;
		var srcEnd = srcPos + srcLen;
		if( srcLen == 0 )
			return 0;
		#if flash
		flash.Memory.select(out.getData());
		#end
		while( true ) {
			var tk = src.get(srcPos++);
			var litLen = tk >> 4;
			var matchLen = tk & 15;
			if( litLen == 15 ) {
				var b;
				do {
					b = src.get(srcPos++);
					litLen += b;
				} while( b == 0xFF );
			}
			inline function write(v) {
				#if flash
				flash.Memory.setByte(outPos, v);
				#else
				out.set(outPos, v);
				#end
				outPos++;
			}
			switch( litLen ) {
			case 0:
			case 1:
				write(src.get(srcPos++));
			case 2:
				write(src.get(srcPos++));
				write(src.get(srcPos++));
			case 3:
				write(src.get(srcPos++));
				write(src.get(srcPos++));
				write(src.get(srcPos++));
			default:
				out.blit(outPos, src, srcPos, litLen);
				outPos += litLen;
				srcPos += litLen;
			}
			if( srcPos >= srcEnd ) break;
			var offset = src.get(srcPos++);
			offset |= src.get(srcPos++) << 8;
			if( matchLen == 15 ) {
				var b;
				do {
					b = src.get(srcPos++);
					matchLen += b;
				} while( b == 0xFF );
			}
			matchLen += 4;
			if( matchLen >= 64 && matchLen <= offset ) {
				out.blit(outPos, out, outPos - offset, matchLen);
				outPos += matchLen;
			} else {
				var copyEnd = outPos + matchLen;
				while( outPos < copyEnd )
					write(#if flash flash.Memory.getByte(outPos - offset) #else out.get(outPos - offset) #end);
			}
		}
		if( srcPos != srcEnd ) throw "Read too much data " + (srcPos - srcLen);
		return outPos - outSave;
	}
	
}