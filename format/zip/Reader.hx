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
package format.zip;
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

	public function readEntryHeader() : Entry {
		var i = this.i;
		var h = i.readInt31();
		if( h == 0x02014B50 || h == 0x06054B50 )
			return null;
		if( h != 0x04034B50 )
			throw "Invalid Zip Data";
		var version = i.readUInt16();
		var flags = i.readUInt16();
		var extraFields = (flags & 8) != 0;
		if( (flags & 0xFFF7) != 0 )
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
		var ename = i.readString(elen);
		var data;
		if( extraFields ) {
			// TODO : it is needed to directly read the compressed
			// data streamed from the input (needs additional neko apis)
			// then, we can set "compressed" to false, and then follows
			// 12 bytes with real crc, csize and usize
			throw "Zip format with extrafields is currently not supported";
		}
		return {
			fileName : fname,
			fileSize : usize,
			fileTime : mtime,
			compressed : compressed,
			dataSize : csize,
			data : null,
			crc32 : crc32,
		};
	}

	public function readEntryData( e : Entry, buf : haxe.io.Bytes, out : haxe.io.Output ) {
		format.tools.IO.copy(i,out,buf,e.dataSize);
	}

	public function read() : Data {
		var l = new List();
		while( true ) {
			var e = readEntryHeader();
			if( e == null )
				break;
			e.data = i.read(e.dataSize);
			l.add(e);
		}
		return l;
	}

}
