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
package format.tar;
import format.tar.Data;

class Reader {

	var i : haxe.io.Input;

	public function new(i) {
		this.i = i;
	}

	public function read() : List<Entry> {
		var l = new List();
		var buf = haxe.io.Bytes.alloc(1 << 16); // 64 KB
		while( true ) {
			var e = readEntryHeader();
			if( e == null )
				break;
			var size = e.fileSize;
			e.data = i.read(size);
			readPad(size);
			l.add(e);
		}
		return l;
	}

	public function readEntryHeader() {
		var i = this.i;
		var fname = i.readUntil(0);
		if( fname.length == 0 ) {
			for( x in 0...511+512 )
				if( i.readByte() != 0 )
					throw "Invalid TAR end";
			return null;
		}
		i.read(99 - fname.length); // skip
		var fmod = parseOctal(i.read(8));
		var uid = parseOctal(i.read(8));
		var gid = parseOctal(i.read(8));
		var fsize = parseOctal(i.read(12));
		// read in two parts in order to prevent overflow
		var mtime : Float = parseOctal(i.read(8));
		mtime = mtime * 512.0 + parseOctal(i.read(4));
		var crc = i.read(8);
		var type = i.readByte();
		var lname = i.readUntil(0);
		i.read(99 - lname.length); // skip
		var ustar = i.readString(8); // skip
		var uname = i.readUntil(0);
		i.read(31 - uname.length);
		var gname = i.readUntil(0);
		i.read(31 - gname.length);
		var devmaj = parseOctal(i.read(8));
		var devmin = parseOctal(i.read(8));
		var prefix = i.readUntil(0);
		i.read(166 - prefix.length);
		return {
			fileName : fname,
			fileSize : fsize,
			fileTime : Date.fromTime(mtime * 1000.0),
			fmod : fmod,
			uid : uid,
			uname : uname,
			gid : gid,
			gname : gname,
			data : null,
		};
	}

	public function readEntryData( e : Entry, buf : haxe.io.Bytes, out : haxe.io.Output ) {
		format.tools.IO.copy(i,out,buf,e.fileSize);
		readPad(e.fileSize);
	}

	function readPad( size : Int ) {
		// read padding
		var pad = Math.ceil(size / 512) * 512 - size;
		i.read(pad);
	}

	function parseOctal( n : haxe.io.Bytes ) {
		var i = 0;
		for( p in 0...n.length ) {
			var c = n.get(p);
			if( c == 0 )
				break;
			if( c == 32 )
				continue;
			if( c < 48 || c > 55 )
				throw "Invalid octal char";
			i = (i * 8) + (c - 48);
		}
		return i;
	}

}