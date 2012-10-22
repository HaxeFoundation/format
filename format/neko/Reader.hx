/*
 * format - haXe File Formats
 * NekoVM emulator by Nicolas Cannasse
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
package format.neko;
import format.neko.Data;

class Reader {
	
	var i : haxe.io.Input;
	
	public function new( i : haxe.io.Input ) {
		this.i = i;
	}
	
	function error() : Dynamic {
		throw "Invalid file format";
		return null;
	}

	inline function readInt() {
		#if haxe3
		return i.readInt32();
		#else
		return i.readUInt30();
		#end
	}
	
	function readDebugInfos() : DebugInfos {
		var nfiles = i.readByte();
		var manyFiles = false;
		if( nfiles >= 0x80 ) {
			nfiles = ((nfiles & 0x7F) << 8) | i.readByte();
			manyFiles = true;
		}
		var files = [];
		for( k in 0...nfiles )
			files[k] = i.readUntil(0);
		var npos = readInt();
		var curfile = files[0];
		var curline = 0;
		var curpos = null;
		var p = 0;
		var pos = alloc(npos);
		while( p < npos ) {
			var c = i.readByte();
			if( c & 1 != 0 ) {
				c >>= 1;
				if( manyFiles )
					c = (c << 8) | i.readByte();
				curfile = files[c];
				curpos = null;
			} else if( c & 2 != 0 ) {
				var delta = c >> 6;
				var count = (c >> 2) & 15;
				if( curpos == null )
					curpos = { file : curfile, line : curline };
				for( k in 0...count )
					pos[p++] = curpos;
				if( delta != 0 ) {
					curline += delta;
					curpos = null;
				}
			} else if( c & 4 != 0 ) {
				curline += c >> 3;
				curpos = { file : curfile, line : curline };
				pos[p++] = curpos;
			} else {
				var b1 = i.readByte();
				var b2 = i.readByte();
				curline = (c >> 3) | (b1 << 5) | (b2 << 13);
				curpos = { file : curfile, line : curline };
				pos[p++] = curpos;
			}
		}
		return pos;
	}
	
	function alloc<T>( size : Int ) : Array<T> {
		var a = new Array<T>();
		if( size > 0 ) a[size-1] = null;
		return a;
	}
	
	public function read() : Data {
		if( i.readString(4) != "NEKO" ) error();
		var nglobals = readInt();
		var nfields = readInt();
		var codesize = readInt();
		// globals
		var globals = alloc(nglobals);
		for( k in 0...nglobals )
			globals[k] = switch( i.readByte() ) {
			case 1:
				GlobalVar(i.readUntil(0));
			case 2:
				var pos = i.readUInt24();
				var nargs = i.readByte();
				GlobalFunction(pos, nargs);
			case 3:
				GlobalString(i.readString(i.readUInt16()));
			case 4:
				GlobalFloat(i.readUntil(0));
			case 5:
				GlobalDebug(readDebugInfos());
			default:
				error();
			}
		// fields
		var fields = alloc(nfields);
		for( k in 0...nfields )
			fields[k] = i.readUntil(0);
		// code
		var code = alloc(codesize + 1);
		var p = 0;
		while( p < codesize ) {
			var t = i.readByte();
			switch( t & 3 ) {
			case 0:
				code[p++] = t >> 2;
			case 1:
				code[p++] = t >> 3;
				code[p++] = (t >> 2) & 1;
			case 2:
				code[p++] = t >> 2;
				code[p++] = i.readByte();
			default:
				code[p++] = t >> 2;
				code[p++] = #if haxe3 i.readInt32() #else i.readInt31() #end;
			}
		}
		code[p++] = Type.enumIndex(ORet);
		return {
			globals : globals,
			fields : fields,
			code : code,
		};
	}
	
}