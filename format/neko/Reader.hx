/*
 * format - Haxe File Formats
 * NekoVM emulator by Nicolas Cannasse
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

	function hash( s : String ) : Int {
		var h = 0;
		#if neko
		for( i in 0...s.length )
			h = 223 * h + s.charCodeAt(i);
		return h;
		#else
		for( i in 0...s.length )
			h = (((223 * h) >> 1) + s.charCodeAt(i)) << 1;
		return h >> 1;
		#end
	}

	public function read() : Data {
		if( i.readString(4) != "NEKO" ) error();
		var nglobals = readInt();
		var nfields = readInt();
		var codesize = readInt();
		if (nglobals < 0 || nglobals > 0xffff
				|| nfields < 0 || nfields > 0xffff
				|| codesize < 0 || codesize > 0xffffff)
				error();

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
			case 6:
				GlobalVersion(i.readByte());
			default:
				error();
			}

		// fields
		var fields = alloc(nfields);
		var fieldHashes = new Map<Int, String>();
		for( k in 0...nfields ) {
			var fld = i.readUntil(0);
			fields[k] = fld;

			var hsh = hash(fld);
			if (fieldHashes.exists(hsh)) {
				if (fieldHashes[hsh] != fld) error();
			} else {
				fieldHashes[hsh] = fld;
			}
		}

		// code
		var code: Array<Opcode> = [];
		var jumps: Array<{cpos: Int, idx: Int}> = [];
		var pos = alloc(codesize + 1);
		var cpos = 0;
		while( cpos < codesize ) {
			var t = i.readByte();
			var opId = 0;
			var p = 0;
			switch( t & 3 ) {
			case 0:
				opId = t >> 2;
			case 1:
				opId = t >> 3;
				p = (t >> 2) & 1;
			case 2:
				if (t == 2) {
					opId = i.readByte();
				} else {
					opId = t >> 2;
					p = i.readByte();
				}
			case 3:
				opId = t >> 2;
				p = #if haxe3 i.readInt32() #else i.readInt31() #end;
			default:
				error();
			}
			var op: Opcode = switch (opId) {
				case 0: OAccNull;
				case 1: OAccTrue;
				case 2: OAccFalse;
				case 3: OAccThis;
				case 4: OAccInt(p);
				case 5: OAccStack(p + 2);
				case 6: OAccGlobal(p);
				case 7: OAccEnv(p);
				case 8:
					if (!fieldHashes.exists(p)) error();
					OAccField(fieldHashes[p]);
				case 9: OAccArray;
				case 10: OAccIndex(p + 2);
				case 11:
					if (!fieldHashes.exists(p)) error();
					OAccBuiltin(fieldHashes[p]);
				case 12: OSetStack(p);
				case 13: OSetGlobal(p);
				case 14: OSetEnv(p);
				case 15:
					if (!fieldHashes.exists(p)) error();
					OSetField(fieldHashes[p]);
				case 16: OSetArray;
				case 17: OSetIndex(p);
				case 18: OSetThis;
				case 19: OPush;
				case 20: OPop(p);
				case 21: OCall(p);
				case 22: OObjCall(p);
				case 23:
					jumps.push({cpos: cpos, idx: code.length});
					OJump(p);
				case 24:
					jumps.push({cpos: cpos, idx: code.length});
					OJumpIf(p);
				case 25:
					jumps.push({cpos: cpos, idx: code.length});
					OJumpIfNot(p);
				case 26:
					jumps.push({cpos: cpos, idx: code.length});
					OTrap(p);
				case 27: OEndTrap;
				case 28: ORet(p);
				case 29: OMakeEnv(p);
				case 30: OMakeArray(p);
				case 31: OBool;
				case 32: OIsNull;
				case 33: OIsNotNull;
				case 34: OAdd;
				case 35: OSub;
				case 36: OMult;
				case 37: ODiv;
				case 38: OMod;
				case 39: OShl;
				case 40: OShr;
				case 41: OUShr;
				case 42: OOr;
				case 43: OAnd;
				case 44: OXor;
				case 45: OEq;
				case 46: ONeq;
				case 47: OGt;
				case 48: OGte;
				case 49: OLt;
				case 50: OLte;
				case 51: ONot;
				case 52: OTypeOf;
				case 53: OCompare;
				case 54: OHash;
				case 55: ONew;
				case 56: OJumpTable(p);
				case 57: OApply(p);
				case 58: OAccStack0;
				case 59: OAccStack1;
				case 60: OAccIndex0;
				case 61: OAccIndex1;
				case 62: OPhysCompare;
				case 63: OTailCall(p & 7, p >> 3);
				case 64: OLoop;
				default: error();
			}
			pos[cpos] = code.length;
			cpos += ((t&3 == 0) || t == 2) ? 1 : 2;
			code.push(op);
		}
		if (cpos != codesize) error();

		/* Fixup jump targets */
		for (jmp in jumps) {
			code[jmp.idx] = switch (code[jmp.idx]) {
				case OJump(p):      OJump(pos[jmp.cpos+p]);
				case OJumpIf(p):    OJumpIf(pos[jmp.cpos+p]);
				case OJumpIfNot(p): OJumpIfNot(pos[jmp.cpos+p]);
				case OTrap(p): 	    OTrap(pos[jmp.cpos+p]);
				default:            error();
			};
		}

		/* Fixup function positions */
		globals = globals.map(function(glob) {
			switch(glob) {
				case GlobalFunction(f, nargs): return GlobalFunction(pos[f], nargs);
				default: return glob;
			}
		} );

		return {
			globals : globals,
			fields : fields,
			code : code,
		};
	}

}
