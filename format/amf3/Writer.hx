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
package format.amf3;
import format.amf3.Value;

class Writer {

	var o : haxe.io.Output;

	public function new(o) {
		this.o = o;
		o.bigEndian = true;
	}
	
	function writeInt( i : Int ) {
		if (i > 0xfffffff || i < -268435456) {
			o.writeByte(0x05);
			o.writeDouble(i);
		}
		else {
			o.writeByte(0x04);
			writeUInt(i);
		}
	}
	
	function writeUInt( u:UInt, shiftLeft : Bool = false ) {
		if (shiftLeft) u = (u << 1) | 0x01;
		if (((u >> 31) & 0x01) == 1) u &= 0x1fffffff;
		var bits = 22, started = false;
		var chunk = u >> bits - 1;
		if (chunk > 0) {
			chunk >>= 1;
			o.writeByte(chunk | 0x80);
			u -= chunk << bits;
			bits++;
			started = true;
		}
		bits -= 8;
		chunk = u >> bits;
		if (started || chunk > 0) {
			o.writeByte(chunk | 0x80);
			u -= chunk << bits;
			started = true;
		}
		bits -= 7;
		chunk = u >> bits;
		if (started || chunk > 0) {
			o.writeByte(chunk | 0x80);
			u -= chunk << bits;
			started = true;
		}
		o.writeByte(u);
	}
	
	function writeString( s : String ) {
		writeUInt(s.length, true);
		var j = 0, it = 0;
		for (i in 0...s.length) {
			j = s.charCodeAt(i);
			if (j < 0x7f) {
				o.writeByte(j);
				it = 0;
			}
			else if (j < 0x7ff) {
				o.writeByte(j >> 6 | 0xc0);
				j &= 0x3f;
				it = 1;
			}
			else if (j < 0xffff) {
				o.writeByte(j >> 12 | 0xe0);
				j &= 0x0fff;
				it = 2;
			}
			else if (j < 0x10ffff) {
				o.writeByte(j >> 18 | 0xf0);
				j &= 0x2ffff;
				it = 3;
			}
			while (it-- > 0)
				o.writeByte(j >> (6 * it));
		}
	}
	
	function writeObject( h : Map<String, Value>, ?size : Int ) {
		if (size == null) o.writeByte(0x0b);
		else writeUInt(size << 4 | 0x03);
		o.writeByte(0x01);
		if (size == null) {
			for( f in h.keys() ) {
				writeString(f);
				write(h.get(f));
			}
			o.writeByte(0x01);
		}
		else {
			var k = new Array();
			for( f in h.keys() ) {
				k.push(f);
				writeString(f);
			}
			for ( i in 0...k.length )
				write( h.get( k[i] ) );
		}
	}

	public function write( v : Value ) {
		var o = this.o;
		switch( v ) {
		case AUndefined:
			o.writeByte(0x00);
		case ANull:
			o.writeByte(0x01);
		case ABool(b):
			o.writeByte(b ? 0x03 : 0x02);
		case AInt(i):
			writeInt(i);
		case ANumber(n):
			o.writeByte(0x05);
			o.writeDouble(n);
		case AString(s):
			o.writeByte(0x06);
			writeString(s);
		case ADate(d):
			o.writeByte(0x08);
			o.writeByte(0x01);
			o.writeDouble(d.getTime());
		case AArray(a,extra):
			o.writeByte(0x09);
			writeUInt(a.length, true);
			if( extra != null )  // check for assoc array values
			{
				for( mk in extra.keys() )
				{
					o.writeString(mk);
					write(extra[mk]);
				}
			}
			o.writeByte(0x01);  // end of assoc array values
			for(f in a)
				write(f);
		//case AVector(v):  // TODO add vector writing support
		case AObject(h,n):
			o.writeByte(0x0a);
			writeObject(h, n);
		case AXml(x):
			o.writeByte(0x0b);
			writeString(x.toString());
		case ABytes(b):
			o.writeByte(0x0c);
			writeUInt(b.length, true);
			o.write(b);
		case AMap(m):
			o.writeByte(0x11);
			writeUInt( Lambda.count(m), true );
			o.writeByte(0x00);
			for( f in m.keys() ) {
				write(f);
				write(m.get(f));
			}
		default:
			throw "Unsupported type";
		}
	}

}