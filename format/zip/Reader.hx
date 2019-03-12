/*
 * format - Haxe File Formats
 *
 * Copyright (c) 2008, The Haxe Project Contributors
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
package format.zip;

#if haxe3

typedef Reader = haxe.zip.Reader;

#else

import format.zip.Data;

// see http://www.pkware.com/documents/casestudies/APPNOTE.TXT

class Reader {

	var i : haxe.io.Input;

	public function new(i) {
		this.i = i;
	}

	function readZipDate() {
		var t = i.readUInt16();
		var hour = (t >> 11) & 31;
		var min = (t >> 5) & 63;
		var sec = t & 31;
		var d = i.readUInt16();
		var year = d >> 9;
		var month = (d >> 5) & 15;
		var day = d & 31;
		return new Date(year + 1980, month-1, day, hour, min, sec << 1);
	}

	function readExtraFields(length) {
		var fields = new List();
		while( length > 0 ) {
			if( length < 4 ) throw "Invalid extra fields data";
			var tag = i.readUInt16();
			var len = i.readUInt16();
			if( length < len ) throw "Invalid extra fields data";
			switch( tag ) {
			case 0x7075:
				var version = i.readByte();
				if( version != 1 ) {
					var data = new haxe.io.BytesBuffer();
					data.addByte(version);
					data.add(i.read(len-1));
					fields.add(FUnknown(tag,data.getBytes()));
				} else {
					var crc = i.readInt32();
					var name = i.read(len - 5).toString();
					fields.add(FInfoZipUnicodePath(name,crc));
				}
			default:
				fields.add(FUnknown(tag,i.read(len)));
			}
			length -= 4 + len;
		}
		return fields;
	}

	public function readEntryHeader() : Entry {
		var i = this.i;
		var h = i.readInt31();
		if( h == 0x02014B50 || h == 0x06054B50 )
			return null;
		if( h != 0x04034B50 )
			throw "Invalid Zip Data";
		var version = i.readUInt16();
		var flags = i.readUInt16();
		var utf8 = flags & 0x800 != 0;
		if( (flags & 0xF7F7) != 0 )
			throw "Unsupported flags "+flags;
		var compression = i.readUInt16();
		var compressed = (compression != 0);
		if( compressed && compression != 8 )
			throw "Unsupported compression "+compression;
		var mtime = readZipDate();
		var crc32 = i.readInt32();
		var csize = i.readUInt30();
		var usize = i.readUInt30();
		var fnamelen = i.readInt16();
		var elen = i.readInt16();
		var fname = i.readString(fnamelen);
		var fields = readExtraFields(elen);
		if( utf8 )
			fields.push(FUtf8);
		var data = null;
		if( (flags & 8) != 0 )
			csize = -1;
		return {
			fileName : fname,
			fileSize : usize,
			fileTime : mtime,
			compressed : compressed,
			dataSize : csize,
			data : data,
			crc32 : crc32,
			extraFields : fields,
		};
	}

	public function readEntryData( e : Entry, buf : haxe.io.Bytes, out : haxe.io.Output ) {
		format.tools.IO.copy(i,out,buf,e.dataSize);
	}

	public function read() : Data {
		var l = new List();
		var buf = null;
		var tmp = null;
		while( true ) {
			var e = readEntryHeader();
			if( e == null )
				break;
			if( e.dataSize < 0 ) {
				#if neko
				// enter progressive mode : we use a different input which has
				// a temporary buffer, this is necessary since we have to uncompress
				// progressively, and after that we might have pending readed data
				// that needs to be processed
				var bufSize = 65536;
				if( buf == null ) {
					buf = new format.tools.BufferInput(i, haxe.io.Bytes.alloc(bufSize));
					tmp = haxe.io.Bytes.alloc(bufSize);
					i = buf;
				}
				var out = new haxe.io.BytesBuffer();
				var z = new neko.zip.Uncompress(-15);
				z.setFlushMode(neko.zip.Flush.SYNC);
				while( true ) {
					if( buf.available == 0 )
						buf.refill();
					var p = bufSize - buf.available;
					if( p != buf.pos ) {
						// because of lack of "srcLen" in zip api, we need to always be stuck to the buffer end
						buf.buf.blit(p, buf.buf, buf.pos, buf.available);
						buf.pos = p;
					}
					var r = z.execute(buf.buf, buf.pos, tmp, 0);
					out.addBytes(tmp, 0, r.write);
					buf.pos += r.read;
					buf.available -= r.read;
					if( r.done ) break;
				}
				e.data = out.getBytes();
				#else
				var bufSize = 65536;
				if( tmp == null )
					tmp = haxe.io.Bytes.alloc(bufSize);
				var out = new haxe.io.BytesBuffer();
				var z = new format.tools.InflateImpl(i, false, false);
				while( true ) {
					var n = z.readBytes(tmp, 0, bufSize);
					out.addBytes(tmp, 0, n);
					if( n < bufSize )
						break;
				}
				e.data = out.getBytes();
				#end
				e.crc32 = i.readInt32();
				if( haxe.Int32.compare(e.crc32,haxe.Int32.ofInt(0x08074b50)) == 0 )
					e.crc32 = i.readInt32();
				e.dataSize = i.readUInt30();
				e.fileSize = i.readUInt30();
				// set data to uncompressed
				e.dataSize = e.fileSize;
				e.compressed = false;
			} else
				e.data = i.read(e.dataSize);
			l.add(e);
		}
		return l;
	}

}

#end