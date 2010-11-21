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
import format.neko.Value;

class VM {

	// globals
	var opcodes : Array<Opcode>;
	var hfields : IntHash<String>;
	var builtins : IntHash<Value>;
	var hloader : Int;
	var hexports : Int;

	// registers
	var vthis : Value;
	var env : Array<Value>;
	var stack : haxe.FastList<Value>;

	// current module
	var module : Module;

	public function new() {
		builtins = new IntHash();
		hfields = new IntHash();
		opcodes = [];
		stack = new haxe.FastList<Value>();
		for( f in Type.getEnumConstructs(Opcode) )
			opcodes.push(Type.createEnum(Opcode, f));
		var bl = new Builtins().table;
		for( b in bl.keys() )
			builtins.set(hash(b), bl.get(b));
		hloader = hash("loader");
		hexports = hash("exports");
	}

	function hash( s : String ) {
		var h = 0;
		for( i in 0...s.length )
			h = 223 * h + s.charCodeAt(i);
		return h;
	}

	function exc( v : Value ) {
		throw v;
	}

	function loadPrim( prim : Value, nargs : Value ) {
		var prim = switch( prim ) {
		case VString(s): s;
		default: return null;
		}
		var nargs = switch(nargs) {
		case VInt(n):
		default: return null;
		}
		var me = this;
		return VFunction(VFunVar(function(_) { me.exc(VString("Failed to load primitive " + prim + ":" + nargs)); return null; } ));
	}

	public function load( m : Data, ?loader : ValueObject ) {
		if( loader == null ) {
			loader = new ValueObject(null);
			loader.fields.set(hash("loadprim"), VFunction(VFun2(loadPrim)));
		}
		this.module = new Module(m, loader);
		var me = this, mod = module;
		for( i in 0...m.globals.length )
			module.gtable[i] = switch(m.globals[i]) {
			case GlobalVar(_): VNull;
			case GlobalFloat(v): VFloat(Std.parseFloat(v));
			case GlobalString(s): VString(s);
			case GlobalFunction(pos, nargs): VFunction(switch( nargs ) {
				case 0: VFun0(function() {
					return me.fcall(mod, pos);
				});
				case 1: VFun1(function(a) {
					me.stack.add(a);
					return me.fcall(mod, pos);
				});
				case 2: VFun2(function(a, b) {
					me.stack.add(a);
					me.stack.add(b);
					return me.fcall(mod, pos);
				});
				case 3: VFun3(function(a, b, c) {
					me.stack.add(a);
					me.stack.add(b);
					me.stack.add(c);
					return me.fcall(mod, pos);
				});
				case 4: VFun4(function(a, b, c, d) {
					me.stack.add(a);
					me.stack.add(b);
					me.stack.add(c);
					me.stack.add(d);
					return me.fcall(mod, pos);
				});
				case 5: VFun5(function(a, b, c, d, e) {
					me.stack.add(a);
					me.stack.add(b);
					me.stack.add(c);
					me.stack.add(d);
					me.stack.add(e);
					return me.fcall(mod, pos);
				});
				default:
					throw "assert";
			});
			case GlobalDebug(debug): module.debug = debug; VNull;
			};
		for( f in m.fields ) {
			var fid = hash(f);
			var f2 = hfields.get(fid);
			if( f2 != null && f2 != f )
				throw "Hashing conflicts between '" + f + "' and '" + f2 + "'";
			hfields.set(fid, f);
		}
		vthis = VNull;
		env = [];
		return loop(0);
	}

	function error( pc : Int, msg : String ) {
		pc--;
		throw VString("@"+StringTools.hex(pc)+" : "+msg);
	}

	function fieldName( fid : Int ) {
		var name = hfields.get(fid);
		return (name == null) ? "?" + fid : name;
	}

	function fcall( m : Module, pc : Int) {
		var old = this.module;
		this.module = m;
		var acc = loop(pc);
		this.module = old;
		return acc;
	}

	function call( pc : Int, obj : Value, f : Value, nargs : Int ) {
		var ret = null;
		var old = vthis;
		vthis = obj;
		switch( f ) {
		case VFunction(f):
			switch( f ) {
			case VFun0(f):
				if( nargs != 0 ) error(pc, "Invalid call");
				ret = f();
			case VFun1(f):
				if( nargs != 1 ) error(pc, "Invalid call");
				var a = stack.pop();
				ret = f(a);
			case VFun2(f):
				if( nargs != 2 ) error(pc, "Invalid call");
				var b = stack.pop();
				var a = stack.pop();
				ret = f(a,b);
			case VFun3(f):
				if( nargs != 3 ) error(pc, "Invalid call");
				var c = stack.pop();
				var b = stack.pop();
				var a = stack.pop();
				ret = f(a,b,c);
			case VFun4(f):
				if( nargs != 3 ) error(pc, "Invalid call");
				var d = stack.pop();
				var c = stack.pop();
				var b = stack.pop();
				var a = stack.pop();
				ret = f(a,b,c,d);
			case VFun5(f):
				if( nargs != 3 ) error(pc, "Invalid call");
				var e = stack.pop();
				var d = stack.pop();
				var c = stack.pop();
				var b = stack.pop();
				var a = stack.pop();
				ret = f(a,b,c,d,e);
			case VFunVar(f):
				var args = [];
				for( i in 0...nargs )
					args.push(stack.pop());
				ret = f(args);
			}
		default:
			error(pc, "Invalid call");
		}
		if( ret == null )
			error(pc, "Invalid call");
		vthis = old;
		return ret;
	}

	function loop( pc : Int ) {
		var acc = VNull;
		var code = module.code.code;
		var opcodes = opcodes;
		while( true ) {
			var op = opcodes[code[pc++]];
			switch( op ) {
			case OAccNull:
				acc = VNull;
			case OAccTrue:
				acc = VBool(true);
			case OAccFalse:
				acc = VBool(false);
			case OAccThis:
				acc = vthis;
			case OAccInt:
				acc = VInt(code[pc++]);
// case OAccStack:
			case OAccGlobal:
				acc = module.gtable[code[pc++]];
// case OAccEnv:
			case OAccField:
				switch( acc ) {
				case VObject(o):
					while( true ) {
						acc = o.fields.get(code[pc]);
						if( acc != null ) break;
						o = o.proto;
						if( o == null ) {
							acc = VNull;
							break;
						}
					}
					pc++;
				default: error(pc, "Invalid field access : " + fieldName(code[pc]));
				}
// case OAccArray:
// case OAccIndex:
			case OAccBuiltin:
				acc = builtins.get(code[pc++]);
				if( acc == null )
					switch( code[pc - 1] ) {
					case hloader: acc = VObject(module.loader);
					case hexports: acc = VObject(module.exports);
					default:
						error(pc - 1, "Builtin not found : " + fieldName(code[pc - 1]));
					}
// case OSetStack:
			case OSetGlobal:
				module.gtable[code[pc++]] = acc;
// case OSetEnv:
			case OSetField:
				var obj = stack.pop();
				switch( obj ) {
				case VObject(o): o.fields.set(code[pc++], acc);
				default: error(pc, "Invalid field access : " + fieldName(code[pc]));
				}
// case OSetArray:
// case OSetIndex:
// case OSetThis:
			case OPush:
				stack.add(acc);
			case OPop:
				for( i in 0...code[pc++] )
					stack.pop();
			case OCall:
				acc = call(pc, vthis, acc, code[pc]);
				pc++;
			case OObjCall:
				acc = call(pc, stack.pop(), acc, code[pc]);
				pc++;
			case OJump:
				pc += code[pc] - 1;
// case OJumpIf:
// case OJumpIfNot:
// case OTrap:
// case OEndTrap:
// case ORet:
// case OMakeEnv:
// case OMakeArray:
// case OBool:
// case OIsNull:
// case OIsNotNull:
			case OAdd:
				var a = stack.pop();
				acc = switch( acc ) {
				case VInt(b):
					switch( a ) {
					case VInt(a): VInt(a + b);
					case VFloat(a): VFloat(a + b);
					case VString(a): VString(a + b);
					default: null;
					}
				case VFloat(b):
					switch( a ) {
					case VInt(a): VFloat(a + b);
					case VFloat(a): VFloat(a + b);
					case VString(a): VString(a + b);
					default: null;
					}
				case VString(b):
					switch( a ) {
					case VInt(a): VString(a + b);
					case VFloat(a): VString(a + b);
					case VString(a): VString(a + b);
					default: null;
					}
				default: null;
				}
				if( acc == null ) error(pc, "+");
// case OSub:
// case OMult:
// case ODiv:
// case OMod:
// case OShl:
// case OShr:
// case OUShr:
// case OOr:
// case OAnd:
// case OXor:
// case OEq:
// case ONeq:
// case OGt:
// case OGte:
// case OLt:
// case OLte:
// case ONot:
// case OTypeOf:
// case OCompare:
// case OHash:
			case ONew:
				switch( acc ) {
				case VNull: acc = VObject(new ValueObject(null));
				case VObject(o): acc = VObject(new ValueObject(o));
				default: error(pc, "$new");
				}
// case OJumpTable:
// case OApply:
			case OAccStack0:
				acc = stack.head.elt;
			case OAccStack1:
				acc = stack.head.next.elt;
// case OAccIndex0:
// case OAccIndex1:
// case OPhysCompare:
// case OTailCall:
			default:
				throw "TODO:" + opcodes[code[pc - 1]];
			}
		}
		return null;
	}

}