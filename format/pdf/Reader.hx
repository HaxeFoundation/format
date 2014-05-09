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
package format.pdf;
import format.pdf.Data;
import haxe.io.Bytes;
import haxe.io.BytesBuffer;
import haxe.io.BytesData;
import haxe.io.BytesInput;

private enum Break {
	BDictEnd;
	BEndObj;
}

class Reader {

	var char : Null<Int>;
	var objects : Array<Data>;

	public function new() {
	}

	function readEOL( i : haxe.io.Input ) {
		var c = i.readByte();
		if( c == 13 )
			c = i.readByte();
		if( c != 10 )
			throw "Invalid eol "+c;
		// we can't handle single \r eol, although it's part of the spec.
		// is it used in practice ?
	}

	function invalidChar( c : Int ) {
		return throw "Invalid char "+c;
	}

	function invalidBreak( e : Break ) {
		return throw "Invalid break "+e;
	}

	function readObjectEof( i : haxe.io.Input ) {
		if( char == null ) {
			try {
				char = i.readByte();
			} catch( e : haxe.io.Eof ) {
				return null;
			}
		}
		switch( char ) {
		case 0,9,10,12,13,32: // whitespace
			char = null;
			return readObjectEof(i);
		default:
		}
		return readObject(i);
	}

	function readObject( i : haxe.io.Input ) {
		var c;
		if( char == null )
			c = i.readByte();
		else {
			c = char;
			char = null;
		}
		switch( c ) {
		case 37: // %
			return DComment(i.readLine());
		case 48,49,50,51,52,53,54,55,56,57,46,43,45: // 0-9 . + -
			var s = new StringBuf();
			if( c != 43 ) s.addChar(c);
			while( true ) {
				c = i.readByte();
				switch( c ) {
				case 48,49,50,51,52,53,54,55,56,57,46:
					s.addChar(c);
				case 0,9,10,12,13,32:
					break;
				case 40,41,60,62,91,93,123,125,47,37: // separators
					char = c;
					break;
				default:
					invalidChar(c);
				}
			}
			return DNumber( Std.parseFloat(s.toString()) );
		case 0,9,10,12,13,32: // whitespace
			return readObject(i);
		case 60: // <
			c = i.readByte();
			if( c == 60 )
				return readDictionnary(i);
			var code = -1;
			var s = new StringBuf();
			while( true ) {
				switch( c ) {
				case 48,49,50,51,52,53,54,55,56,57: // 0-9
					c -= 48;
				case 65,66,67,68,69,70: // A-F
					c -= 55;
				case 97,98,99,100,101,102: // a-f
					c -= 87;
				case 62:
					break;
				default:
					invalidChar(c);
				}
				if( code == -1 )
					code = c;
				else {
					s.addChar((code << 4) | c);
					code = -1;
				}
				c = i.readByte();
			}
			if( code != -1 )
				s.addChar(code << 4);
			return DHexString( s.toString() );
		case 47: // '/'
			var s = new StringBuf();
			while( true ) {
				c = i.readByte();
				switch( c ) {
				case 0,9,10,12,13,32:
					break;
				case 40,41,60,62,91,93,123,125,47,37: // separators
					char = c;
					break;
				default:
					s.addChar(c);
				}
			}
			var s = s.toString();
			// replace #XX by corresponding hex char
			#if (haxe_211 || haxe3)
			s = ~/#([0-9A-Fa-f][0-9a-fA-F])/g.map(s, function(r:EReg) return String.fromCharCode( Std.parseInt("0x" + r.matched(1)) ));
			#else
			s = ~/#([0-9A-Fa-f][0-9a-fA-F])/.customReplace(s, function(r:EReg) return String.fromCharCode( Std.parseInt("0x" + r.matched(1)) ));
			#end
			return DName(s);
		case 62:
			c = i.readByte();
			if( c == 62 )
				throw BDictEnd;
			invalidChar(c);
		case 91: // [
			var a = new Array();
			var old = objects;
			objects = a;
			while( true ) {
				if( char == null )
					char = i.readByte();

				// skip spaces
				while (true) {
					switch (char) {
						case 0, 9, 10, 12, 13, 32: // whitespace
						case _: break;
					}
					char = i.readByte();
				}

				if( char == 93 ) { // ]
					char = null;
					break;
				}
				objects.push(readObject(i));
			}
			objects = old;
			return DArray(a);
		case 40: // (
			var count = 1;
			var buf = new StringBuf();
			var esc = false;
			while( true ) {
				c = i.readByte();
				if( esc ) {
					esc = false;
					switch( c ) {
					case 110: // n
						buf.add("\n");
					case 114: // r
						buf.add("\r");
					case 116: // t
						buf.add("\t");
					case 98: // b
						buf.addChar(8);
					case 102: // f
						buf.addChar(12);
					case 40, 41, 92: // ()\
						buf.addChar(c);
					case 10,13:
						// ignore
					default:
						buf.addChar(c); // had values such has 0, 2 & 3 here with real world pdfs; adding the char allowed to parse the pdf.
//						throw "Invalid escape sequence  <"+buf.toString() + "> "   +String.fromCharCode(c);
					}
				} else switch( c ) {
				case 40: // (
					count++;
					buf.addChar(c);
				case 41: // )
					count--;
					if( count == 0 ) break;
					buf.addChar(c);
				case 92: // '\'
					esc = true;
				default:
					buf.addChar(c);
				}
			}
			return DString( buf.toString() );
		case 82: // R
			var rev = Extract.int(objects.pop());
			var id = Extract.int(objects.pop());
			return DRef( id, rev );
		case 97,98,99,100,101,102,103,104,105,106,107,108,109,110,111,112,113,114,115,116,117,118,119,120,121,122: // a-z
			var s = new StringBuf();
			s.addChar(c);
			while( true ) {
				c = i.readByte();
				switch( c ) {
				case 97,98,99,100,101,102,103,104,105,106,107,108,109,110,111,112,113,114,115,116,117,118,119,120,121,122: // a-z
					s.addChar(c);
				default:
					char = c;
					break;
				}
			}
			var id = s.toString();
			switch( id ) {
			case "null": return DNull;
			case "false": return DBool(false);
			case "true": return DBool(true);
			case "obj": return readIndirect(i);
			case "endobj": throw BEndObj;
			case "stream": return readStream(i);
			case "xref": return readXRefTable(i);
			case "trailer": return DTrailer(readObject(i));
			case "startxref": return DStartXRef(Extract.int(readObject(i)));
			default: throw "Unknown id "+id;
			}
		default:
			
			invalidChar(c);
		}
		throw "Assert";
		return null;
	}

	function readDictionnary( i : haxe.io.Input ) {
		var old = objects;
		objects = new Array();
		while( true ) {
			try { // not caught on hxcpp if no '{' '}'
				objects.push(readObject(i)); 
			} catch ( e : Break ) {
				if( e == BDictEnd ) break else invalidBreak(e);
			}
		}
		var values = objects;
		objects = old;
		var h = new Map();
		while( values.length > 0 ) {
			var obj = values.shift();
			switch( obj ) {
			case DName(key):
				obj = values.shift();
				if( obj == null ) throw "Missing value for key "+key;
				h.set(key,obj);
			default: throw "Invalid object key "+obj;
			}
		}
		return DDict(h);
	}

	function readIndirect(i) {
		var rev = Extract.int(objects.pop());
		var id = Extract.int(objects.pop());
		var old = objects;
		objects = new Array();
		while( true ) {
			try {
				objects.push(readObject(i));
			} catch( e : Break ) {
				if ( e == BEndObj ) break else invalidBreak(e);
			}
		}
		if( objects.length != 1 ) throw "Multiple values in object";
		var value = objects[0];
		objects = old;
		return DIndirect( id, rev, value );
	}

	function readStream(i) {
		if( objects.length == 0 )
			throw "Invalid stream";
		if( char == 10 ) char = null else readEOL(i);
		var size, props;
		var dict = objects.pop();
		switch( dict ) {
		case DDict(h):
			props = h;
			var len = h.get("Length");
			if( len == null )
				throw "Invalid stream dict "+dict;
			switch( len ) {
			case DNumber(n): size = Std.int(n);
			case DRef(id, rev): size = -1; // should read indirects; these can be unknow, hence our specific handling (see below)
			default: throw "Invalid stream length "+len;
			}
		default:
			throw "Invalid stream dict "+dict;
		}
		if (size != -1) {
			var b = haxe.io.Bytes.alloc(size);
			i.readFullBytes(b,0,size);
			readEOL(i);
			if( i.readString(9) != "endstream" )
				throw "Invalid stream end";
			return DStream(b, props);			
			
		} else { // consume stream until we match the pattern
			var data =  new BytesBuffer();
			var ref = Bytes.ofString("endstream");
			var refLength = ref.length;
			var refMatch = 0;
			var toMatch = ref.get(refMatch);
			
			while (refMatch < refLength) {
				var b = i.readByte();
				if (b == toMatch) {
					refMatch ++;
					toMatch = ref.get(refMatch);
				} else {
					if (refMatch != 0) {
						for (i in 0 ... refMatch) {
						  data.addByte(ref.get(i));						
						}
						refMatch = 0;
						toMatch = ref.get(refMatch);
					}
					data.addByte(b);
				}
			}	
			var b = data.getBytes();
			return DStream(b,props);
		}
	}

	function readXRefTable(i) {
		var tables = new Array();
		while( true ) {
			var start;
			switch( readObject(i) ) {
				case DNumber(n):
					start = Std.int(n);
				// small hack
				case DTrailer(t):
					objects.push(DXRefTable(tables));
					return DTrailer(t);
				default: throw "Invalid CR table";
			};
			var count = Extract.int(readObject(i));
			var entries = new Array();
			var r = ~/^([0-9]{10}) ([0-9]{5}) ([fn]) ?$/;
			while( count > 0 ) {
				var s = i.readLine();
				if( s == "" ) continue;
				if( !r.match(s) )
					throw "Invalid CR entry '"+s+"'";
				count--;
				entries.push({ offset : Std.parseInt(r.matched(1)), gen : Std.parseInt(r.matched(2)), used : r.matched(3) == "f" });
			}
			tables.push({ start : start, entries : entries });
		}
		return DXRefTable(tables);
	}

	public function read( i : haxe.io.Input ) {
		objects = new Array();
		while( true ) {
			var o = readObjectEof(i);
			if( o == null )
				break;
			objects.push(o);
		}
		var tmp = objects;
		objects = null;
		return tmp;
	}

}