/*
 * format - haXe File Formats
 *
 * Copyright (c) 2008, The haXe Project Contributors
 * All rights reserved.
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 *   - Redistributions of source code must retain the above copyright
 *     notice, this list of conditions and the following disclaimer.
 *   - Redistributions in binary form must reproduce the above copyright
 *     notice, this list of conditions and the following disclaimer in the
 *     documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE HAXE PROJECT CONTRIBUTORS "AS IS" AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE HAXE PROJECT CONTRIBUTORS BE LIABLE FOR
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 * CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH
 * DAMAGE.
 */
package format.gz;
import format.gz.Data;

class Reader {

	var i : haxe.io.Input;

	public function new(i) {
		this.i = i;
	}
	
	public function read() {
		var h = readHeader();
		var o = new haxe.io.BytesOutput();
		readData(o);
		return { file : h.fileName, data : o.getBytes() };
	}

	public function readHeader() : Header {
		if( i.readByte() != 0x1F || i.readByte() != 0x8B )
			throw "Invalid GZ header";
		if( i.readByte() != 8 )
			throw "Invalid compression method";
		var flags = i.readByte();
		var mtime = i.read(4);
		var xflags = i.readByte();
		var os = i.readByte();
		var fname = null;
		var comments = null;
		var xdata = null;
		if( flags & 4 != 0 ) {
			var xlen = i.readUInt16();
			xdata = i.read(xlen);
		}
		if( flags & 8 != 0 )
			fname = i.readUntil(0);
		if( flags & 16 != 0 )
			comments = i.readUntil(0);
		if( flags & 2 != 0 ) {
			var hcrc = i.readUInt16();
			// does not check header crc
		}
		return {
			fileName : fname,
			comments : comments,
			extraData : xdata,
		};
	}

	public function readData( o : haxe.io.Output, ?bufsize : Int ) : Int {
		if( bufsize == null ) bufsize = (1 << 16); // 65Ks
		var buf = haxe.io.Bytes.alloc(bufsize);
		var tsize = 0;
		#if neko
		var bufpos = bufsize;
		var out = haxe.io.Bytes.alloc(bufsize);
		var u = new neko.zip.Uncompress(-15);
		u.setFlushMode(neko.zip.Flush.SYNC);
		while( true ) {
			if( bufpos == buf.length ) {
				buf = refill(buf,0);
				bufpos = 0;
			}
			var r = u.execute(buf,bufpos,out,0);
			if( r.read == 0 ) {
				if( bufpos == 0 )
					throw new haxe.io.Eof();
				var len = buf.length - bufpos;
				buf.blit(0,buf,bufpos,len);
				buf = refill(buf,len);
				bufpos = 0;
			} else {
				bufpos += r.read;
				tsize += r.read;
				o.writeFullBytes(out,0,r.write);
				if( r.done )
					break;
			}
		}
		#else
		var inflate = new format.tools.InflateImpl(i, false, false);
		while (true) {
			var len = inflate.readBytes(buf, 0, bufsize);
			o.writeFullBytes(buf, 0, len);
			if( len < bufsize )
				break;
			tsize += len;
		}
		#end
		return tsize;
	}

	function refill( buf : haxe.io.Bytes, pos : Int ) {
		try {
			while( pos != buf.length ) {
				var k = i.readBytes(buf,pos,buf.length-pos);
				pos += k;
			}
		} catch( e : haxe.io.Eof ) {
		}
		if( pos == 0 )
			throw new haxe.io.Eof();
		if( pos != buf.length )
			buf = buf.sub(0,pos);
		return buf;
	}

}
