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
	var builtins : Builtins;
	var hfields : Map<Int,String>;
	var hbuiltins : Map<Int,Value>;
	var hloader : Int;
	var hexports : Int;

	// registers
	var vthis : Value;
	var env : Array<Value>;
	var stack : haxe.ds.GenericStack<Value>;

	// current module
	var module : Module;

	public function new() {
		hbuiltins = new Map();
		hfields = new Map();
		opcodes = [];
		stack = new haxe.ds.GenericStack<Value>();
		for( f in Type.getEnumConstructs(Opcode) )
			opcodes.push(Type.createEnum(Opcode, f));
		builtins = new Builtins(this);
		for( b in builtins.table.keys() )
			hbuiltins.set(hash(b), builtins.table.get(b));
		hloader = hash("loader");
		hexports = hash("exports");
	}

	function hash( s : String ) {
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

	public dynamic function doPrint( s : String ) {
		haxe.Log.trace(s, cast {});
	}

	public function hashField( f : String ) {
		var fid = hash(f);
		var f2 = hfields.get(fid);
		if( f2 != null ) {
			if( f2 == f ) return fid;
			throw "Hashing conflicts between '" + f + "' and '" + f2 + "'";
		}
		hfields.set(fid, f);
		return fid;
	}

	public function _abstract<T>( b : Value, t : Class<T> ) : T {
		switch( b ) {
		case VAbstract(v):
			if( Std.is(v, t) )
				return cast v;
		default:
		}
		exc(VString("Invalid call"));
		return null;
	}

	public function valueToString( v : Value ) {
		return builtins._string(v);
	}

	function exc( v : Value ) {
		throw v;
	}

	function loadPrim( vprim : Value, vargs : Value ) {
		var prim, nargs;
		switch( vprim ) {
		case VString(s): prim = s;
		default: return null;
		}
		switch(vargs) {
		case VInt(n): nargs = n;
		default: return null;
		}
		var me = this;
		return VFunction(VFunVar(function(_) { me.exc(VString("Failed to load primitive " + prim + ":" + nargs)); return null; } ));
	}

	public function defaultLoader() {
		var loader = new ValueObject(null);
		loader.fields.set(hash("loadprim"), VFunction(VFun2(loadPrim)));
		return loader;
	}

	public function load( m : Data, ?loader : ValueObject ) {
		if( loader == null ) loader = defaultLoader();
		this.module = new Module(m, loader);
		for( i in 0...m.globals.length ) {
			var me = this, mod = module;
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
		}
		for( f in m.fields )
			hashField(f);
		vthis = VNull;
		env = [];
		loop(0);
		return this.module;
	}

	function error( pc : Int, msg : String ) {
		pc--;
		var pos;
		if( pc < 0 )
			pos = "C Function";
		else if( module.debug != null ) {
			var p = module.debug[pc];
			pos = p.file+"("+p.line+")";
		} else
			pos = "@" + StringTools.hex(pc);
		throw VString(pos+" : "+msg);
	}

	function fieldName( fid : Int ) {
		var name = hfields.get(fid);
		return (name == null) ? "?" + fid : name;
	}

	public function call( vthis : Value, vfun : Value, args : Array<Value> ) : Value {
		for( a in args )
			stack.add(a);
		return mcall(0, vthis, vfun, args.length );
	}

	function fcall( m : Module, pc : Int) {
		var old = this.module;
		this.module = m;
		var acc = loop(pc);
		this.module = old;
		return acc;
	}

	function mcall( pc : Int, obj : Value, f : Value, nargs : Int ) {
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
				if( nargs != 4 ) error(pc, "Invalid call");
				var d = stack.pop();
				var c = stack.pop();
				var b = stack.pop();
				var a = stack.pop();
				ret = f(a,b,c,d);
			case VFun5(f):
				if( nargs != 5 ) error(pc, "Invalid call");
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
		case VProxyFunction(f):
			var args = [];
			for( i in 0...nargs )
				args.unshift(unwrap(stack.pop()));
			ret = wrap(Reflect.callMethod(switch( obj ) { case VProxy(o): o; default: null; }, f, args));
		default:
			error(pc, "Invalid call");
		}
		if( ret == null )
			error(pc, "Invalid call");
		vthis = old;
		return ret;
	}

	inline function compare( pc : Int, a : Value, b : Value ) {
		return builtins._compare(a, b);
	}

	inline function accIndex( pc : Int, acc : Value, index : Int ) {
		switch( acc ) {
		case VArray(a):
			acc = a[index];
			if( acc == null ) acc = VNull;
		case VObject(_):
			throw "TODO";
		default:
			error(pc, "Invalid array access");
		}
		return acc;
	}

	public function wrap( v : Dynamic ) {
		return switch( Type.typeof(v) ) {
			case TNull: VNull;
			case TInt: VInt(v);
			case TFloat: VFloat(v);
			case TBool: VBool(v);
			case TFunction: VProxyFunction(v);
			case TObject, TClass(_), TEnum(_): VProxy(v);
			case TUnknown:
				#if neko
				untyped {
					var t = $typeof(v);
					if( t == $tstring ) VString(new String(v)) else if( t == $tarray ) VArray(Array.new1(v, $asize(v))) else null;
				}
				#else
				null;
				#end
		};
	}

	public function unwrap( v : Value ) : Dynamic {
		switch(v) {
		case VNull: return null;
		case VInt(i): return i;
		case VFloat(f): return f;
		case VString(s): return s;
		case VProxy(o): return o;
		case VBool(b): return b;
		case VAbstract(v): return v;
		case VProxyFunction(f): return f;
		case VArray(a):
			var a2 = [];
			for( x in a )
				a2.push(unwrap(x));
			return a2;
		case VObject(o):
			var a = { };
			for( f in o.fields.keys() )
				Reflect.setField(a, fieldName(f), unwrap(o.fields.get(f)));
			return a;
		case VFunction(f):
			var me = this;
			switch(f) {
			case VFun0(f): return function() return me.unwrap(f());
			case VFun1(f): return function(x) return me.unwrap(f(me.wrap(x)));
			case VFun2(f): return function(x,y) return me.unwrap(f(me.wrap(x),me.wrap(y)));
			case VFun3(f): return function(x,y,z) return me.unwrap(f(me.wrap(x),me.wrap(y),me.wrap(z)));
			case VFun4(f): return function(x,y,z,w) return me.unwrap(f(me.wrap(x),me.wrap(y),me.wrap(z),me.wrap(w)));
			case VFun5(f): return function(x,y,z,w,k) return me.unwrap(f(me.wrap(x),me.wrap(y),me.wrap(z),me.wrap(w),me.wrap(k)));
			case VFunVar(f): return Reflect.makeVarArgs(function(args) {
					var args2 = new Array();
					for( x in args ) args2.push(me.wrap(x));
					return me.unwrap(f(args2));
				});
			}
		}
	}

	public function getField( v : Value, fid : Int ) {
		switch( v ) {
		case VObject(o):
			while( true ) {
				v = o.fields.get(fid);
				if( v != null ) break;
				o = o.proto;
				if( o == null ) {
					v = VNull;
					break;
				}
			}
		case VProxy(o):
			var f : Dynamic = try Reflect.field(o, fieldName(fid)) catch( e : Dynamic ) null;
			v = wrap(f);
		default:
			v = null;
		}
		return v;
	}

	function loop( pc : Int ) {
		var acc = VNull;
		var code = module.code.code;
		var opcodes = opcodes;
		while( true ) {
			var op = opcodes[code[pc++]];
			//var dbg = module.debug[pc];
			//if( dbg != null ) trace(dbg.file + "(" + dbg.line + ") " + op+ " " +Lambda.count(stack));
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
			case OAccStack:
				var idx = code[pc++];
				var head = stack.head;
				while( idx > -2 ) {
					head = head.next;
					idx--;
				}
				acc = head.elt;
			case OAccStack0:
				acc = stack.head.elt;
			case OAccStack1:
				acc = stack.head.next.elt;
			case OAccGlobal:
				acc = module.gtable[code[pc++]];
// case OAccEnv:
			case OAccField:
				acc = getField(acc, code[pc]);
				if( acc == null ) error(pc, "Invalid field access : " + fieldName(code[pc]));
				pc++;
			case OAccArray:
				var arr = stack.pop();
				switch( arr ) {
				case VArray(a):
					switch( acc ) {
					case VInt(i): acc = a[i]; if( acc == null ) acc = VNull;
					default: error(pc, "Invalid array access");
					}
				case VObject(_):
					throw "TODO";
				default:
					error(pc, "Invalid array access");
				}
			case OAccIndex:
				acc = accIndex(pc, acc, code[pc] + 2);
				pc++;
			case OAccIndex0:
				acc = accIndex(pc, acc, 0);
			case OAccIndex1:
				acc = accIndex(pc, acc, 1);
			case OAccBuiltin:
				acc = hbuiltins.get(code[pc++]);
				if( acc == null ) {
					if( code[pc - 1] == hloader )
						acc = VObject(module.loader);
					else if( code[pc-1] == hexports )
						acc = VObject(module.exports);
					else
						error(pc - 1, "Builtin not found : " + fieldName(code[pc - 1]));
				}
			case OSetStack:
				var idx = code[pc++];
				var head = stack.head;
				while( idx > 0 ) {
					head = head.next;
					idx--;
				}
				head.elt = acc;
			case OSetGlobal:
				module.gtable[code[pc++]] = acc;
// case OSetEnv:
			case OSetField:
				var obj = stack.pop();
				switch( obj ) {
				case VObject(o): o.fields.set(code[pc++], acc);
				case VProxy(o): Reflect.setField(o, fieldName(code[pc++]), unwrap(acc));
				default: error(pc, "Invalid field access : " + fieldName(code[pc]));
				}
// case OSetArray:
// case OSetIndex:
// case OSetThis:
			case OPush:
				if( acc == null ) throw "assert";
				stack.add(acc);
			case OPop:
				for( i in 0...code[pc++] )
					stack.pop();
			case OTailCall:
				var v = code[pc];
				var nstack = v >> 3;
				var nargs = v & 7;
				var head = stack.head;
				while( nstack-- > 0 )
					head = head.next;
				if( nargs == 0 )
					stack.head = head;
				else {
					var args = stack.head;
					for( i in 0...nargs - 1 )
						args = args.next;
					args.next = head;
				}
				return mcall(pc, vthis, acc, nargs);
			case OCall:
				acc = mcall(pc, vthis, acc, code[pc]);
				pc++;
			case OObjCall:
				acc = mcall(pc, stack.pop(), acc, code[pc]);
				pc++;
			case OJump:
				pc += code[pc] - 1;
			case OJumpIf:
				switch( acc ) {
				case VBool(a): if( a ) pc += code[pc] - 2;
				default:
				}
				pc++;
			case OJumpIfNot:
				switch( acc ) {
				case VBool(a): if( !a ) pc += code[pc] - 2;
				default: pc += code[pc] - 2;
				}
				pc++;
// case OTrap:
// case OEndTrap:
			case ORet:
				for( i in 0...code[pc++] )
					stack.pop();
				return acc;
// case OMakeEnv:
			case OMakeArray:
				var a = new Array();
				for( i in 0...code[pc++] )
					a.unshift(stack.pop());
				a.unshift(acc);
				acc = VArray(a);
			case OBool:
				acc = switch( acc ) {
				case VBool(_): acc;
				case VNull: VBool(false);
				case VInt(i): VBool(i != 0);
				default: VBool(true);
				}
			case ONot:
				acc = switch( acc ) {
				case VBool(b): VBool(!b);
				case VNull: VBool(true);
				case VInt(i): VBool(i == 0);
				default: VBool(false);
				}
			case OIsNull:
				acc = VBool(acc == VNull);
			case OIsNotNull:
				acc = VBool(acc != VNull);
			case OAdd:
				var a = stack.pop();
				acc = switch( acc ) {
				case VInt(b):
					switch( a ) {
					case VInt(a): VInt(a + b);
					case VFloat(a): VFloat(a + b);
					case VString(a): VString(a + b);
					case VProxy(a): wrap(a + b);
					default: null;
					}
				case VFloat(b):
					switch( a ) {
					case VInt(a): VFloat(a + b);
					case VFloat(a): VFloat(a + b);
					case VString(a): VString(a + b);
					case VProxy(a): wrap(a + b);
					default: null;
					}
				case VString(b):
					switch( a ) {
					case VInt(a): VString(a + b);
					case VFloat(a): VString(a + b);
					case VString(a): VString(a + b);
					case VProxy(a): wrap(a + b);
					default: null;
					}
				case VProxy(b):
					wrap(unwrap(a) + b);
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
			case OEq:
				var c = compare(pc, stack.pop(), acc);
				acc = VBool(c == 0 && c != Builtins.CINVALID);
			case ONeq:
				var c = compare(pc, stack.pop(), acc);
				acc = VBool(c != 0 && c != Builtins.CINVALID);
			case OGt:
				var c = compare(pc, stack.pop(), acc);
				acc = VBool(c > 0 && c != Builtins.CINVALID);
			case OGte:
				var c = compare(pc, stack.pop(), acc);
				acc = VBool(c >= 0 && c != Builtins.CINVALID);
			case OLt:
				var c = compare(pc, stack.pop(), acc);
				acc = VBool(c < 0 && c != Builtins.CINVALID);
			case OLte:
				var c = compare(pc, stack.pop(), acc);
				acc = VBool(c <= 0 && c != Builtins.CINVALID);
			case OTypeOf:
				acc = builtins.typeof(acc);
			case OCompare:
				var v = builtins._compare(stack.pop(), acc);
				acc = (v == Builtins.CINVALID) ? VNull : VInt(v);
			case OHash:
				switch( acc ) {
				case VString(f): acc = VInt(hashField(f));
				default: error(pc, "$hash");
				}
			case ONew:
				switch( acc ) {
				case VNull: acc = VObject(new ValueObject(null));
				case VObject(o): acc = VObject(new ValueObject(o));
				default: error(pc, "$new");
				}
// case OJumpTable:
// case OApply:
			case OPhysCompare:
				error(pc, "$pcompare");
			default:
				throw "TODO:" + opcodes[code[pc - 1]];
			}
		}
		return null;
	}

}