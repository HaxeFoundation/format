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
package format.amf3;
import format.amf3.Value;

class Reader {

	var i : haxe.io.Input;

	public function new( i : haxe.io.Input ) {
		this.i = i;
		i.bigEndian = true;
	}

	function readObject() {
		var n = readInt();
		var dyn = ((n >> 3) & 0x01) == 1;
		n >>= 4;
		i.readByte();
		var h = new Map();
		if (dyn) {
			var s;
			while ( true ) {
				s = readString();
				if (s == "") break;
				h.set(s, read());
			}
		}
		else {
			var a = new Array();
			for (j in 0...n)
				a.push(readString());
			for (j in 0...n)
				h.set(a[j], read());
		}
		return h;
	}
	
	function readMap(n : Int) {
		var h = new Map();
		i.readByte();
		for ( i in 0...n )
			h.set(read(), read());
		return h;
	}

	function readArray(n : Int) {
		var a = new Array();
		read();
		for( i in 0...n )
			a.push(read());
		return a;
	}
	
	function readBytes(n : Int) {
		var b = haxe.io.Bytes.alloc(n);
		for ( j in 0...n )
			b.set(j, i.readByte());
		return b;
	}
	
	function readInt( preShift : Int = 0 ) {
		var ret:UInt = 0;
		var c = i.readByte();
		if (c > 0xbf) ret = 0x380;
		var j = 0;
		while (++j < 4 && c > 0x7f) {
			ret |= c & 0x7f;
			ret <<= 7;
			c = i.readByte();
		}
		if (j > 3) ret <<= 1;
		ret |= c;
		return ret >> preShift;
	}

	function readString() {
		var len = readInt(1);
		var u = new haxe.Utf8(len);
		var c = 0, d = 0, j = 0, it = 0;
		while (j < len) {
			c = i.readByte();
			if (c < 0x80) {
				it = 0;
				d = c;
			}
			else if (c < 0xe0) {
				it = 1;
				d = c & 0x1f;
			}
			else if (c < 0xf0) {
				it = 2;
				d = c & 0x0f;
			}
			else if (c < 0xf1) {
				it = 3;
				d = c & 0x07;
			}
			c = it;
			while (c-- > 0) {
				d <<= 6;
				d |= i.readByte() & 0x3f;
			}
			j += it + 1;
			if (d != 0x01) u.addChar(d);
		}
		return u.toString();
	}
	
	public function readWithCode( id ) {
		var i = this.i;
		return switch( id ) {
		case 0x00:
			AUndefined;
		case 0x01:
			ANull;
		case 0x02:
			ABool(false);
		case 0x03:
			ABool(true);
		case 0x04:
			AInt( readInt() );
		case 0x05:
			ANumber( i.readDouble() );
		case 0x06:
			AString( readString() );
		case 0x07:
			throw "XMLDocument unsupported";
		case 0x08:
			i.readByte();
			ADate( Date.fromTime(i.readDouble()) );
		case 0x09:
			AArray( readArray( readInt(1) ) );
		case 0x0a:
			AObject( readObject() );
		case 0x0b:
			AXml( Xml.parse(readString()) );
		case 0x0c:
			ABytes( readBytes( readInt(1) ) );
		case 0x0d, 0x0e, 0x0f:
			AArray( readArray( readInt(1) ) );
		case 0x10:
			var len = readInt(1);
			readString();
			AArray( readArray( len ) );
		case 0x11:
			AMap( readMap( readInt(1) ) );
		default:
			throw "Unknown AMF "+id;
		}
	}

	public function read() {
		return readWithCode(i.readByte());
	}
}