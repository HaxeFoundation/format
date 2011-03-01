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
package format.hxsl;
import format.hxsl.Data;

class Compiler {

	var cur : Code;
	var vars : Hash<Variable>;
	var indexes : Array<Int>;
	var ops : Array<Array<{ p1 : VarType, p2 : VarType, r : VarType }>>;

	public function new() {
		vars = new Hash();
		indexes = [0, 0, 0, 0, 0, 0];
		ops = new Array();
		for( o in initOps() )
			ops[Type.enumIndex(o.op)] = o.types;
	}

	function initOps() {
		var mat = TMatrix44( { t : false } );
		var mat_t = TMatrix44( { t : true } );
		var mat_u = TMatrix44( { t : null } );
		var floats = [
			{ p1 : TFloat, p2 : TFloat, r : TFloat },
			{ p1 : TFloat2, p2 : TFloat2, r : TFloat2 },
			{ p1 : TFloat3, p2 : TFloat3, r : TFloat3 },
			{ p1 : TFloat4, p2 : TFloat4, r : TFloat4 },
		];
		var ops = [];
		for( o in Lambda.map(Type.getEnumConstructs(CodeOp), function(c) return Type.createEnum(CodeOp, c)) )
			ops.push({ op : o, types : switch( o ) {
				case CAdd, CSub, CDiv, CPow: floats;
				case CMin, CMax, CLt, CGte: floats;
				case CDot: [ { p1 : TFloat4, p2 : TFloat4, r : TFloat }, { p1 : TFloat3, p2 : TFloat3, r : TFloat } ];
				case CCross: [ { p1 : TFloat4, p2 : TFloat4, r : TFloat3 }];
				case CMul: floats.concat([
					{ p1 : TFloat4, p2 : mat_t, r : TFloat4 },
					{ p1 : TFloat3, p2 : mat_t, r : TFloat3 },
					{ p1 : mat, p2 : mat_t, r : mat_u },
				]);
			}});
		return ops;
	}

	function error(msg:String, p) : Dynamic {
		throw new Error(msg, p);
		return null;
	}

	public dynamic function warn( msg:String, p:Position) {
	}

	function typeStr( t : VarType )  {
		return Std.string(t).substr(1);
	}

	public function compile( h : ParsedHxsl ) {
		allocVar("out", VOut, TFloat4, h.pos);
		
		var input = [];
		for( v in h.input )
			input.push(allocVar(v.n, VInput, v.t, v.p));
		
		for( v in h.vars )
			allocVar(v.n, VVar, v.t, v.p);
			
		var vertex = compileShader(h.vertex);
		var fragment = compileShader(h.fragment);
		
		return { input : input, vertex : vertex, fragment : fragment };
	}
	
	function compileShader( c : ParsedCode ) : Code {
		cur = {
			vertex : c.vertex,
			pos : c.pos,
			consts : c.consts,
			args : [],
			exprs : [],
			tex : [],
			tempSize : 0,
		};
		for( v in c.args )
			if( v.t == TTexture ) {
				if( c.vertex ) error("You can't use a texture inside a vertex shader", v.p);
				cur.tex.push(allocVar(v.n, VTexture, v.t, v.p));
			} else
				cur.args.push(allocVar(v.n, VParam, v.t, v.p));
	
		for( e in c.exprs )
			compileAssign(e.v, e.e, e.p);
			
		cur.tempSize = indexes[Type.enumIndex(VTmp)];
		checkVars();
		
		// cleanup
		for( v in vars )
			switch( v.kind ) {
			case VParam, VTmp: vars.remove(v.name);
			default:
			}
		indexes[Type.enumIndex(VParam)] = 0;
		indexes[Type.enumIndex(VTmp)] = 0;
		
		return cur;
	}
	
	function compileAssign( v : Null<ParsedValue>, e : ParsedValue, p : Position ) {
		if( v == null ) {
			var e = compileValue(e);
			switch( e.d ) {
			case CUnop(op, _):
				if( op == CKill ) {
					cur.exprs.push( { v : null, e : e } );
					return;
				}
			default:
			}
			error("assert",p);
		}
		if( e == null ) {
			switch( v.v ) {
			case PLocal(v):
				allocVar(v.n, VTmp, v.t, v.p);
				return;
			default:
			}
			error("assert",p);
		}
		var e = compileValue(e);
		switch( v.v ) {
		case PLocal(v):
			if( v.t == null ) v.t = e.t;
		default:
		}
		var v = compileValue(v);
		unify(e.t, v.t, e.p);
		checkRead(e);
		switch( v.d ) {
		case CVar(vr, swiz):
			var bits = swizBits(swiz, vr.type);
			switch( vr.kind ) {
			case VVar:
				if( !cur.vertex ) error("You can't write a variable in fragment shader", v.p);
				if( vr.write & bits != 0  ) error("Multiple writes to the same variable are not allowed", v.p);
				vr.write |= bits;
			case VParam:
				error("Constant values cannot be written", v.p);
			case VInput:
				error("Input values cannot be written", v.p);
			case VOut, VTmp:
				vr.write |= bits;
			case VTexture:
				error("You can't write to a texture", v.p);
			}
			if( swiz != null ) {
				var min = -1;
				for( s in swiz ) {
					var k = Type.enumIndex(s);
					if( k <= min ) error("Invalid write mask", v.p);
					min = k;
				}
			}
		default:
			error("Invalid assign", p);
		}
		cur.exprs.push( { v : v, e : e } );
	}

	function swizBits( s : Array<Comp>, t : VarType ) {
		if( s == null ) return fullBits(t);
		var b = 0;
		for( x in s )
			b |= 1 << Type.enumIndex(x);
		return b;
	}

	function fullBits( t : VarType ) {
		return (1 << Tools.floatSize(t)) - 1;
	}
	
	function allocVar( name, k, t, p ) {
		if( vars.exists(name) ) error("Duplicate variable '" + name + "'", p);
		var tkind = Type.enumIndex(k);
		var v : Variable = {
			name : name,
			type : t,
			kind : k,
			read : false,
			index : indexes[tkind],
			write : if( k == null ) fullBits(t) else switch( k ) { case VInput, VParam: fullBits(t); default: 0; },
			pos : p,
		};
		#if neko
		var me = this;
		untyped v.__string = function() return neko.NativeString.ofString(name + ":"+me.typeStr(t));
		#end
		vars.set(name, v);
		indexes[tkind] += Tools.regSize(t);
		return v;
	}

	function constSwiz(k,count) {
		var s = [];
		var e = [X, Y, Z, W][k];
		for( i in 0...count ) s.push(e);
		return s;
	}
	
	function allocZero( count : Int, p : Position ) {
		// do we already have a zero ?
		var free = null;
		for( i in 0...cur.consts.length ) {
			var c = cur.consts[i];
			for( k in 0...c.length )
				if( c[k] == "0." )
					return compileValue( { v : PConst(i, constSwiz(k,count)), p : p } );
			if( free == null && cur.consts.length < 4 )
				free = i;
		}
		// alloc a new one
		if( free == null ) {
			free = cur.consts.length;
			cur.consts.push([]);
		}
		var s = constSwiz(cur.consts[free].length,count);
		cur.consts[free].push("0.");
		return compileValue( { v : PConst(free, s), p : p } );
	}

	function checkVars() {
		var shader = (cur.vertex ? "vertex" : "fragment")+" shader";
		for( v in vars )
			switch( v.kind ) {
			case VOut:
				if( v.write == 0 ) error("Output is not written by " + shader, v.pos);
				if( v.write != fullBits(v.type) ) error("Some output components are not written by " + shader, v.pos);
				v.write = 0; // reset status between two shaders
			case VVar:
				if( cur.vertex ) {
					if( v.write == 0 ) {
						// delay error
					} else if( v.write != fullBits(v.type) )
						error("Some components of variable '" + v.name + "' are not written by vertex shader", v.pos);
					else if( v.write != 15 ) {
						// force the output write
						padWrite(v);
					}
				} else {
					if( !v.read && v.write == 0 )
						warn("Variable '" + v.name + "' is not used", v.pos);
					else if( !v.read )
						warn("Variable '" + v.name + "' is not read by " + shader, v.pos);
					else if( v.write == 0 )
						error("Variable '" + v.name + "' is not written by vertex shader", v.pos);
				}
			case VInput:
				if( cur.vertex && !v.read ) {
					warn("Input '" + v.name + "' is not used by " + shader, v.pos);
					// force the input read
					cur.exprs.push({ v : trash(), e : { d : CVar(v), t : TFloat4, p : v.pos } });
				}
			case VTmp:
				if( !v.read ) warn("Unused local variable '" + v.name+"'", v.pos);
			case VParam:
				if( !v.read ) warn("Parameter '" + v.name + "' not used by " + shader, v.pos);
			case VTexture:
				if( !v.read ) {
					warn("Unused texture " + v.name, v.pos);
					// force the texture read
					var t = trash();
					var a = t;
					if( cur.tempSize == 0 )
						a = allocZero(2,v.pos);
					cur.exprs.push({ v : t, e : { d : CTex(v,a,[]), t : TFloat4, p : v.pos } });
				}
			}
	}
	
	function padWrite( v : Variable ) {
		// if we already have a partial "mov" copy, we can simply extend the writing on other components
		for( e in cur.exprs ) {
			if( e.v == null ) continue;
			switch( e.v.d ) {
			case CVar(vv, sv):
				if( v == vv && isGoodSwiz(sv) ) {
					switch( e.e.d ) {
					case CVar(v2, sv2):
						// remove swizzle on write
						var vn = Reflect.copy(v);
						vn.type = TFloat4;
						e.v.d = CVar(vn);
						// remove swizzle on read
						if( isGoodSwiz(sv2) ) {
							var vn2 = Reflect.copy(v2);
							vn2.type = TFloat4;
							e.e.d = CVar(vn2);
						} else
						// or pad swizzle on input var
							while( sv2.length < 4 )
								sv2.push(X);
						// adjust types
						e.e.t = e.v.t = TFloat4;
						return;
					default:
					}
				}
			default:
			}
		}
		// store zeroes into remaining components
		var missing = [];
		for( i in Tools.floatSize(v.type)...4 )
			missing.push(Type.createEnumIndex(Comp, i));
		var c = allocZero(missing.length, v.pos);
		checkRead(c);
		cur.exprs.push( { v : { d : CVar(v, missing), t : makeFloat(missing.length), p : v.pos }, e : c } );
	}

	function isGoodSwiz( s : Array<Comp> ) {
		if( s == null ) return true;
		var cur = 0;
		for( x in s )
			if( Type.enumIndex(x) != cur++ )
				return false;
		return true;
	}
		
	function trash() {
		return { d : CVar( {
			name : "$trash",
			pos : cur.pos,
			type : TFloat4,
			kind : VTmp,
			index : 0,
			read : false,
			write : 15,
		}), t : TFloat4, p : cur.pos };
	}
	
	function makeFloat( i : Int ) {
		 return switch( i ) { case 1: TFloat; case 2: TFloat2; case 3: TFloat3; case 4: TFloat4; default: throw "assert"; };
	}

	function checkRead( e : CodeValue ) {
		switch( e.d ) {
		case CVar(v, swiz):
			switch( v.kind ) {
			case VOut: error("Output cannot be read", e.p);
			case VVar: if( cur.vertex ) error("You cannot read variable in vertex shader", e.p); v.read = true;
			case VParam: v.read = true;
			case VTmp:
				if( v.write == 0 ) error("Variable '"+v.name+"'has not been initialized", e.p);
				var bits = swizBits(swiz, v.type);
				if( v.write & bits != bits ) error("Some fields of '"+v.name+"'have not been initialized", e.p);
				v.read = true;
			case VInput:
				if( !cur.vertex ) error("You cannot read input variable in fragment shader", e.p);
				v.read = true;
			case VTexture:
				error("You can't read from a texture", e.p);
			}
		case COp(_, e1, e2):
			checkRead(e1);
			checkRead(e2);
		case CUnop(_, e):
			checkRead(e);
		case CTex(t, v, _):
			if( cur.vertex ) error("You can't read from texture in vertex shader", e.p);
			t.read = true;
			checkRead(v);
		case CSwiz(v, _):
			checkRead(v);
		}
	}
	
	function compileValue( e : ParsedValue ) : CodeValue {
		return switch( e.v ) {
		case PVar(vname):
			var v = vars.get(vname);
			if( v == null ) error("Unknown variable '" + vname + "'", e.p);
			{ d : CVar(v), t : v.type, p : e.p };
		case PConst(i, swiz):
			var v : Variable = {
				name : "$c" + i,
				kind : VParam,
				type : TFloat4,
				index : i + indexes[Type.enumIndex(VParam)],
				read : true,
				write : 0,
				pos : e.p,
			};
			{ d : CVar(v, swiz), t : makeFloat(swiz.length), p : e.p };
		case PLocal(v):
			var v = allocVar(v.n, VTmp, v.t, v.p);
			{ d : CVar(v), t : v.type, p : e.p };
		case PSwiz(v, s):
			var v = compileValue(v);
			// check swizzling according to value type
			var count = switch( v.t ) {
			case TFloat: 1;
			case TFloat2: 2;
			case TFloat3: 3;
			case TFloat4: 4;
			case TMatrix44(_), TTexture: 0;
			}
			// allow all components access on input and varying values only
			switch( v.d ) {
			case CVar(v, s):
				if( s == null && (v.kind == VInput || v.kind == VVar) ) count = 4;
			default:
			}
			// check that swizzling is correct
			for( s in s )
				if( Type.enumIndex(s) >= count )
					error("Invalid swizzling on " + typeStr(v.t), e.p);
			// build swizzling
			switch( v.d ) {
			case CVar(v, swiz):
				var ns;
				if( swiz == null )
					ns = s
				else {
					// combine swizzlings
					ns = [];
					for( s in s )
						ns.push(swiz[Type.enumIndex(s)]);
				}
				{ d : CVar(v, ns), t : makeFloat(s.length), p : e.p };
			default:
				{ d : CSwiz(v, s), t : makeFloat(s.length), p : e.p };
			}
		case POp(op, e1, e2):
			makeOp(op, compileValue(e1), compileValue(e2), e.p);
		case PUnop(op, e1):
			makeUnop(op, compileValue(e1), e.p);
		case PTex(vname, acc, flags):
			var v = vars.get(vname);
			if( v == null || v.type != TTexture ) error("Invalid texture '" + vname + "'", e.p);
			var acc = compileValue(acc);
			// allow 1-3 components, maybe we should have different texture types
			if( Tools.floatSize(acc.t) > 3 ) unify(acc.t, TFloat2, acc.p);
			{ d : CTex(v, acc, flags), t : TFloat4, p : e.p };
		case PIf(cond,e1,e2):
			var cond = compileValue(cond);
			var cond2 = switch( cond.d ) {
				case COp(op, e1, e2): if( op == CGte || op == CLt ) { d : COp(op == CGte ? CLt : CGte,e1,e2), t : cond.t, p : cond.p } else null;
			default: null;
			}
			if( cond2 == null ) error("'if' condition should be a comparison operator", cond.p);
			var e1 = compileValue(e1);
			var e2 = compileValue(e2);
			unify(e2.t, e1.t, e2.p);
			if( !isFloat(e1.t) ) error("'if' values should be vectors", e.p);
			var mkCond = function(c) return c;
			if( cond.t != e1.t ) {
				if( cond.t != TFloat ) unify(cond.t, e1.t, cond.p);
				cond = { d : CSwiz(cond, constSwiz(0, Tools.floatSize(e1.t))), t : e1.t, p : cond.p };
				cond2 = { d : CSwiz(cond2, constSwiz(0, Tools.floatSize(e1.t))), t : e1.t, p : cond.p };
			}
			// compile "if( c ) e1 else e2" into "c * e1 + (!c) * e2"
			// we could optimize by storing the value of "c" into a temp var
			var e1 = { d : COp(CMul, cond, e1), t : e1.t, p : e.p };
			var e2 = { d : COp(CMul, cond2, e2), t : e2.t, p : e.p };
			{ d : COp(CAdd, e1, e2), t : e1.t, p : e.p };
		};
	}
	
	function tryUnify( t1 : VarType, t2 : VarType ) {
		if( t1 == t2 ) return true;
		switch( t1 ) {
		case TMatrix44(t1):
			switch( t2 ) {
			case TMatrix44(t2):
				if( t1.t == null ) {
					if( t2.t == null ) throw "assert";
					t1.t = t2.t;
					return true;
				}
				return( t1.t == t2.t );
			default:
			}
		default:
		}
		return false;
	}

	function unify(t1, t2, p) {
		if( !tryUnify(t1, t2) ) {
			switch(t1) {
			case TMatrix44(t):
				if( t.t != null ) {
					if( t.t )
						error("Matrix is transposed by another operation", p);
					else
						error("Matrix is not transposed by a previous operation", p);
				}
			default:
			}
			error(typeStr(t1) + " should be " +typeStr(t2), p);
		}
	}
	
	function makeOp( op : CodeOp, e1 : CodeValue, e2 : CodeValue, p : Position ) {
		// look for a valid operation as listed in "ops"
		var types = ops[Type.enumIndex(op)];
		var first = null;
		for( t in types ) {
			if( isCompatible(e1.t, t.p1) && isCompatible(e2.t, t.p2) ) {
				if( first == null ) first = t;
				if( tryUnify(e1.t, t.p1) && tryUnify(e2.t, t.p2) ) {
					var ct = switch( t.r ) {
					case TMatrix44(t): TMatrix44( { t : t.t } );
					default: t.r;
					};
					return { d : COp(op, e1, e2), t : ct, p : p };
				}
			}
		}
		// if we have an operation on a single scalar, let's map it on all floats
		if( e2.t == TFloat && isFloat(e1.t) )
			for( t in types )
				if( isCompatible(e1.t, t.p1) && isCompatible(e1.t, t.p2) ) {
					var swiz = [];
					var s = switch( e2.d ) {
					case CVar(_, s): if( s == null ) X else s[0];
					default: X;
					}
					for( i in 0...Tools.floatSize(e1.t) )
						swiz.push(s);
					return makeOp(op, e1, { d : CSwiz(e2, swiz), t : e1.t, p : e2.p }, p );
				}
		// ...or the other way around
		if( e1.t == TFloat && isFloat(e2.t) )
			for( t in types )
				if( isCompatible(e2.t, t.p1) && isCompatible(e2.t, t.p2) ) {
					var swiz = [];
					var s = switch( e1.d ) {
					case CVar(_, s): if( s == null ) X else s[0];
					default: X;
					}
					for( i in 0...Tools.floatSize(e2.t) )
						swiz.push(s);
					return makeOp(op, { d : CSwiz(e1, swiz), t : e2.t, p : e1.p }, e2, p );
				}

		// we have an error, so let's find the most appropriate override
		// in order to print the most meaningful error message
		if( first == null )
			for( t in types )
				if( isCompatible(e1.t, t.p1) ) {
					first = t;
					break;
				}
		if( first == null )
			first = types[0];
		unify(e1.t, first.p1, e1.p);
		unify(e2.t, first.p2, e2.p);
		throw "assert";
		return null;
	}
	
	function makeUnop( op : CodeUnop, e : CodeValue, p : Position ) {
		if( !isFloat(e.t) )
			unify(e.t, TFloat4, e.p);
		var rt = e.t;
		switch( op ) {
		case CNorm: rt = TFloat3;
		case CLen: rt = TFloat;
		default:
		}
		return { d : CUnop(op, e), t : rt, p : p };
	}

	function isFloat( t : VarType ) {
		return switch( t ) {
		case TFloat, TFloat2, TFloat3, TFloat4: true;
		default: false;
		};
	}

	function isMatrix( t : VarType, ?transp : Bool ) {
		return switch( t ) {
		case TMatrix44(tr):
			if( transp == null )
				true;
			else if( tr.t == null ) {
				tr.t = transp;
				true;
			} else
				tr.t == transp;
		default: false;
		};
	}

	function isCompatible( t1 : VarType, t2 : VarType ) {
		if( t1 == t2 ) return true;
		switch( t1 ) {
		case TMatrix44(t1):
			switch( t2 ) {
			case TMatrix44(t2):
				return( t1.t == null || t2.t == null || t1.t == t2.t );
			default:
			}
		default:
		}
		return false;
	}

}