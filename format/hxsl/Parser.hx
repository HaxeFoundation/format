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
import haxe.macro.Expr;

class ParserError {
	public var message : String;
	public var pos : Position;
	public function new(msg, p) {
		this.message = msg;
		this.pos = p;
	}
}

class Parser {

	var vertex : Function;
	var fragment : Function;
	var cur : Code;

	var vars : Hash<Variable>;
	var input : Array<Variable>;
	var indexes : Array<Int>;

	var vertexShader : Bool;
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
		throw new ParserError(msg, p);
		return null;
	}

	public dynamic function warn( msg:String, p:Position) {
	}

	function typeStr( t : VarType )  {
		return Std.string(t).substr(1);
	}

	public function parse( e : Expr ) {
		input = [];
		allocVar("out", VOut, TFloat4, e.pos);
		switch( e.expr ) {
		case EBlock(l):
			for( x in l )
				parseDecl(x);
		default:
			error("Shader code should be a block", e.pos);
		}
		if( vertex == null ) error("Missing vertex function", e.pos);
		if( fragment == null ) error("Missing fragment function", e.pos);
		if( input.length == 0 ) error("Missing input variable", e.pos);
		// build vertex shader code
		vertexShader = true;
		var vs = buildShader(vertex);
		checkVars();

		// reset
		for( v in vars )
			switch( v.kind ) {
			case VParam: vars.remove(v.name);
			default:
			}
		indexes[Type.enumIndex(VParam)] = 0;
		indexes[Type.enumIndex(VTmp)] = 0;

		// build fragment shader code
		vertexShader = false;
		var fs = buildShader(fragment);
		checkVars();

		return { input : input, vs : vs, fs : fs };
	}
	
	function checkVars() {
		var shader = (vertexShader ? "vertex" : "fragment")+" shader";
		for( v in vars )
			switch( v.kind ) {
			case VOut:
				if( v.write == 0 ) error("Output is not written by " + shader, v.pos);
				if( v.write != fullBits(v.type) ) error("Some output components are not written by " + shader, v.pos);
				v.write = 0; // reset status
			case VVar:
				if( vertexShader ) {
					if( v.write == 0 ) {
						// delay error
					} else if( v.write != fullBits(v.type) )
						error("Some components of variable '" + v.name + "' are not written by vertex shader", v.pos);
					else if( v.write != 15 )
						padWrite(v);
				} else {
					if( !v.read && v.write == 0 )
						warn("Variable '" + v.name + "' is not used", v.pos);
					else if( !v.read )
						warn("Variable '" + v.name + "' is not read by " + shader, v.pos);
					else if( v.write == 0 )
						error("Variable '" + v.name + "' is not written by vertex shader", v.pos);
				}
			case VInput:
				if( vertexShader && !v.read ) {
					warn("Input '" + v.name + "' is not used by " + shader, v.pos);
					cur.exprs.push({ v : trash(), e : { d : CVar(v), t : TFloat4, p : v.pos } });
				}
			case VTmp:
				throw "assert";
			case VParam:
				if( !v.read ) warn("Parameter '" + v.name + "' not used by " + shader, v.pos);
			case VTexture:
				if( !v.read ) {
					warn("Unused texture " + v.name, v.pos);
					var t = trash();
					var a = t;
					if( cur.tempSize == 0 )
						a = allocConst(["0", "0"], v.pos);
					cur.exprs.push({ v : t, e : { d : CTex(v,a,[]), t : TFloat4, p : v.pos } });
				}
			}
	}
	
	function isGoodSwiz( s : Array<Comp> ) {
		if( s == null ) return true;
		var cur = 0;
		for( x in s )
			if( Type.enumIndex(x) != cur++ )
				return false;
		return true;
	}
	
	function padWrite( v : Variable ) {
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
		var missing = [], zeroes = [];
		for( i in Tools.floatSize(v.type)...4 ) {
			missing.push(Type.createEnumIndex(Comp, i));
			zeroes.push("0");
		}
		var c = allocConst(zeroes, v.pos);
		checkRead(c);
		cur.exprs.push( { v : { d : CVar(v, missing), t : makeFloat(missing.length), p : v.pos }, e : c } );
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
			const : null,
		}), t : TFloat4, p : cur.pos };
	}

	function getType( t : ComplexType, pos ) {
		switch(t) {
		case TPath(p):
			if( p.pack.length > 0 || p.sub != null || p.params.length > 0 )
				error("Unsupported type", pos);
			return switch( p.name ) {
			case "Float": TFloat;
			case "Float2": TFloat2;
			case "Float3": TFloat3;
			case "Float4": TFloat4;
			case "Matrix", "M44": TMatrix44({ t : null });
			case "Texture": TTexture;
			default:
				error("Unknown type '" + p.name + "'", pos);
			}
		default:
			error("Unsupported type", pos);
		}
		return null;
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
			const : null,
			pos : p,
		};
		#if neko
		var me = this;
		untyped v.__string = function() return neko.NativeString.ofString(name + ":"+me.typeStr(t));
		#end
		if( k != null ) {
			switch( k ) {
			case VTmp:
				cur.temps.push(v);
			case VInput:
				input.push(v);
				v = Reflect.copy(v);
				if( !isMatrix(v.type,true) )
					v.type = TFloat4;
			default:
			}
		}
		vars.set(name, v);
		indexes[tkind] += Tools.regSize(t);
		return v;
	}

	function makeFloat( i : Int ) {
		 return switch( i ) { case 1: TFloat; case 2: TFloat2; case 3: TFloat3; case 4: TFloat4; default: throw "assert"; };
	}
	
	function allocConst( cvals : Array<String>, p : Position ) {
		var swiz = [X, Y, Z, W];
		var type = makeFloat(cvals.length);
		// remove extra zeroes at end
		for( i in 0...cvals.length ) {
			var v = cvals[i];
			if( v.indexOf(".") < 0 ) v += ".";
			while( v.charCodeAt(v.length - 1) == "0".code )
				v = v.substr(0, v.length - 1);
			cvals[i] = v;
		}
		// find an already existing constant
		for( c in cur.consts ) {
			var s = [];
			for( v in cvals ) {
				for( i in 0...c.vals.length )
					if( c.vals[i] == v ) {
						s.push(swiz[i]);
						break;
					}
			}
			if( s.length == cvals.length )
				return { d : CVar(c.v, s), t : type, p : p };
		}
		// find an empty slot
		for( c in cur.consts )
			if( c.vals.length + cvals.length <= 4 ) {
				var s = [];
				for( v in cvals ) {
					s.push(swiz[c.vals.length]);
					c.vals.push(v);
				}
				return { d : CVar(c.v, s), t : type, p : p };
			}
		var v = allocVar("$c" + cur.consts.length, VParam, TFloat4, p);
		v.const = cvals;
		cur.consts.push( { v : v, vals : cvals } );
		return { d : CVar(v, swiz.splice(0,cvals.length)), t : type, p : p };
	}

	function parseDecl( e : Expr ) {
		switch( e.expr ) {
		case EVars(vl):
			var p = e.pos;
			for( v in vl )
				if( v.name == "input" )
					switch( v.type ) {
					case TAnonymous(fl):
						for( f in fl )
							switch( f.type ) {
							case FVar(t): allocVar(f.name, VInput, getType(t,p), p);
							default: error("Invalid input variable type", p);
							}
					default: error("Invalid type for shader input : should be anonymous", p);
					}
				else {
					if( v.type == null ) error("Missing type for variable '" + v.name + "'", p);
					allocVar(v.name, VVar, getType(v.type,p), p);
				}
		case EFunction(f):
			switch( f.name ) {
			case "vertex": vertex = f;
			case "fragment": fragment = f;
			default: error("Invalid function '" + f.name + "'", e.pos);
			}
		default:
			error("Unsupported declaration", e.pos);
		};
	}

	function buildShader( f : Function ) {
		cur = {
			vertex : vertexShader,
			pos : f.expr.pos,
			args : [],
			consts : [],
			tex : [],
			exprs : [],
			temps : [],
			tempSize : 0,
		};
		var pos = f.expr.pos;
		for( p in f.args ) {
			if( p.type == null ) error("Missing parameter type '" + p.name + "'", pos);
			if( p.value != null ) error("Unsupported default value", p.value.pos);
			var t = getType(p.type, pos);
			var v = allocVar(p.name, (t == TTexture) ? VTexture : VParam, t, pos);
			if( v.type == TTexture )
				cur.tex.push(v);
			else
				cur.args.push(v);
		}
		parseExpr(f.expr);
		cur.tempSize = indexes[Type.enumIndex(VTmp)];
		return cur;
	}

	function addAssign( e1 : CodeValue, e2 : CodeValue ) {
		unify(e2.t, e1.t, e2.p);
		checkRead(e2);
		switch( e1.d ) {
		case CVar(v, swiz):
			switch( v.kind ) {
			case VVar:
				if( !vertexShader ) error("You can't write a variable in fragment shader", e1.p);
				var bits = swizBits(swiz, v.type);
				if( v.write & bits != 0  ) error("Multiple writes to the same variable are not allowed", e1.p);
				v.write |= bits;
			case VParam:
				error("Constant values cannot be written", e1.p);
			case VInput:
				error("Input values cannot be written", e1.p);
			case VOut, VTmp:
				v.write |= swizBits(swiz, v.type);
			case VTexture:
				error("You can't write to a texture", e1.p);
			}
			if( swiz != null ) {
				var min = -1;
				for( s in swiz ) {
					var k = Type.enumIndex(s);
					if( k <= min ) error("Invalid write mask", e1.p);
					min = k;
				}
			}
		default:
		}
		cur.exprs.push( { v : e1, e : e2 } );
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

	function checkRead( e : CodeValue ) {
		switch( e.d ) {
		case CVar(v, swiz):
			switch( v.kind ) {
			case VOut: error("Output cannot be read", e.p);
			case VVar: if( vertexShader ) error("You cannot read variable in vertex shader", e.p); v.read = true;
			case VParam: v.read = true;
			case VTmp:
				if( v.write == 0 ) error("Variable '"+v.name+"'has not been initialized", e.p);
				var bits = swizBits(swiz, v.type);
				if( v.write & bits != bits ) error("Some fields of '"+v.name+"'have not been initialized", e.p);
				v.read = true;
			case VInput:
				if( !vertexShader ) error("You cannot read input variable in fragment shader", e.p);
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
			if( vertexShader ) error("You can't read from texture in vertex shader", e.p);
			t.read = true;
			checkRead(v);
		case CSwiz(v, _):
			checkRead(v);
		}
	}


	function parseExpr( e : Expr ) {
		switch( e.expr ) {
		case EBlock(el):
			var vold = new Hash();
			for( v in vars.keys() )
				vold.set(v, vars.get(v));
			for( e in el )
				parseExpr(e);
			vars = vold;
		case EBinop(op, e1, e2):
			switch( op ) {
			case OpAssign:
				addAssign(parseValue(e1), parseValue(e2));
			case OpAssignOp(op):
				addAssign(parseValue(e1), parseValue( { expr : EBinop(op, e1, e2), pos : e.pos } ));
			default:
				error("Operation should have side-effects", e.pos);
			}
		case EVars(vl):
			for( v in vl )
				if( v.expr == null ) {
					if( v.type == null ) error("Missing type for variable '" + v.name + "'", e.pos);
					allocVar(v.name, VTmp, getType(v.type, e.pos), e.pos);
				} else {
					var val = parseValue(v.expr);
					var vr = allocVar(v.name, VTmp, (v.type == null) ? val.t : getType(v.type, e.pos), e.pos);
					unify(val.t, vr.type, v.expr.pos);
					vr.write = fullBits(vr.type);
					var ve = { d : CVar(vr), t : vr.type, p : e.pos };
					addAssign(ve,val);
				}
		case ECall(v, params):
			switch( v.expr ) {
			case EConst(c):
				switch(c) {
				case CIdent(s):
					if( s == "kill" && params.length == 1 ) {
						var v = parseValue(params[0]);
						unify(v.t, TFloat, v.p);
						checkRead(v);
						if( cur.vertex ) error("Kill is only allowed in fragment shaders", e.pos);
						cur.exprs.push( { v : null, e : { d : CUnop(CKill,v), t : TFloat, p : e.pos } } );
						return;
					}
				default:
				}
			default:
			}
			error("Unsupported call", e.pos);
		default:
			error("Unsupported expression", e.pos);
		}
	}

	function getSwiz( s : String, t : VarType, p : Position ) {
		var chars = switch( t ) {
		case TFloat: "x";
		case TFloat2: "xy";
		case TFloat3: "xyz";
		case TFloat4: "xyzw";
		default: error("Can't access fields of " + typeStr(t), p);
		};
		var swiz = [];
		for( i in 0...s.length )
			switch( chars.indexOf(s.charAt(i)) ) {
			case 0: swiz.push(X);
			case 1: swiz.push(Y);
			case 2: swiz.push(Z);
			case 3: swiz.push(W);
			default: error("Unknown field " + s, p);
			}
		return swiz;
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
		switch( e2.d ) {
		case CVar(v, swiz):
			// if we have an operation on a single constant, then apply it to all members
			if( swiz != null && swiz.length == 1 && v.const != null ) {
				var cval = v.const[Type.enumIndex(swiz[0])];
				var cst = [];
				for( i in 0...Tools.floatSize(e1.t) )
					cst.push(cval);
				return makeOp(op, e1, allocConst(cst, e2.p), p);
			}
		default:
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

	function makeCall( n : String, params : Array<Expr>, p : Position ) {
		if( n == "div" && params.length == 2 ) {
			switch( params[0].expr ) {
			case EConst(c):
				switch( c ) {
				case CInt(v), CFloat(v):
					if( Std.parseFloat(v) == 1 ) {
						var e2 = parseValue(params[1]);
						switch( e2.d ) {
						case CUnop(op, v):
							// optimize 1 / sqrt(x)
							if( op == CSqrt )
								return makeUnop(CRsq, v, p);
						default:
						}
						// optimize 1 / x
						return makeUnop(CRcp, e2, p);
					}
				default:
				}
			default:
			}
		}
		if( n == "pow" && params.length == 2 ) {
			switch( params[0].expr ) {
			case EConst(c):
				switch( c ) {
				case CInt(v), CFloat(v):
					if( Std.parseFloat(v) == 2 ) {
						var e2 = parseValue(params[1]);
						return makeUnop(CExp, e2, p);
					}
				default:
				}
			default:
			}
		}
		if( n == "get" && params.length >= 2 ) {
			var v = parseValue(params.shift());
			unify(v.t, TTexture, v.p);
			var v = switch( v.d ) {
			case CVar(v, _): v;
			default: throw "assert";
			};
			var t = parseValue(params.shift());
			var flags = [];
			var idents = ["d2","cube","d3","mm_no","mm_near","mm_lineae","centroid","wrap","clamp","nearest","linear"];
			var values = [T2D,TCube,T3D,TMipMapDisable,TMipMapNearest,TMipMapLinear,TCentroidSample,TWrap,TClamp,TFilterNearest,TFilterLinear];
			for( p in params ) {
				switch( p.expr ) {
				case EConst(c):
					switch( c ) {
					case CIdent(sflag):
						var ip = Lambda.indexOf(idents, sflag);
						if( ip >= 0 ) {
							var v = values[ip];
							var sim = switch( v ) {
							case T2D, TCube, T3D: [T2D, TCube, T3D];
							case TMipMapDisable, TMipMapLinear, TMipMapNearest: [TMipMapDisable, TMipMapLinear, TMipMapNearest];
							case TCentroidSample: [TCentroidSample];
							case TClamp, TWrap: [TClamp, TWrap];
							case TFilterLinear, TFilterNearest: [TFilterLinear, TFilterNearest];
							}
							for( s in sim )
								if( flags.remove(s) ) {
									if( s == v )
										error("Duplicate texture flag", p.pos);
									else
										error("Conflicting texture flags " + idents[Lambda.indexOf(values, s)] + " and " + sflag, p.pos);
								}
							flags.push(v);
							continue;
						}
					default:
					}
				default:
				}
				error("Invalid parameter, should be "+idents.join("|"), p.pos);
			}
			return { d : CTex(v, t, flags), t : TFloat4, p : p };
		}
		var v = [];
		for( p in params )
			v.push(parseValue(p));
		var me = this;
		function checkParams(k) {
			if( params.length < k ) me.error(n + " require " + k + " parameters", p);
		}
		switch(n) {
		case "get": checkParams(2); // will cause an error
		case "type": checkParams(1); warn(typeStr(v[0].t), p); return v[0];

		case "inv","rcp": checkParams(1); return makeUnop(CRcp, v[0], p);
		case "sqt", "sqrt": checkParams(1); return makeUnop(CSqrt, v[0], p);
		case "rsq", "rsqrt": checkParams(1); return makeUnop(CRsq, v[0], p);
		case "log": checkParams(1); return makeUnop(CLog, v[0], p);
		case "exp": checkParams(1); return makeUnop(CExp, v[0], p);
		case "len", "length": checkParams(1); return makeUnop(CLen, v[0], p);
		case "sin": checkParams(1); return makeUnop(CSin, v[0], p);
		case "cos": checkParams(1); return makeUnop(CCos, v[0], p);
		case "abs": checkParams(1); return makeUnop(CAbs, v[0], p);
		case "neg": checkParams(1); return makeUnop(CNeg, v[0], p);
		case "sat", "saturate": checkParams(1); return makeUnop(CSat, v[0], p);
		case "frc", "frac": checkParams(1); return makeUnop(CFrac, v[0], p);
		case "int": checkParams(1);  return makeUnop(CInt,v[0], p);
		case "nrm", "norm", "normalize": checkParams(1); return makeUnop(CNorm, v[0], p);

		case "add": checkParams(2); return makeOp(CAdd, v[0], v[1], p);
		case "sub": checkParams(2); return makeOp(CSub, v[0], v[1], p);
		case "mul": checkParams(2); return makeOp(CMul, v[0], v[1], p);
		case "div": checkParams(2); return makeOp(CDiv, v[0], v[1], p);
		case "pow": checkParams(2); return makeOp(CPow, v[0], v[1], p);
		case "min": checkParams(2); return makeOp(CMin, v[0], v[1], p);
		case "max": checkParams(2); return makeOp(CMax, v[0], v[1], p);
		case "dp","dp3","dp4","dot": checkParams(2); return makeOp(CDot, v[0], v[1], p);
		case "crs", "cross": checkParams(2); return makeOp(CCross, v[0], v[1], p);
		
		case "lt", "slt": checkParams(2); return makeOp(CLt, v[0], v[1], p);
		case "gte", "sge": checkParams(2); return makeOp(CGte, v[0], v[1], p);
		case "gt", "sgt": checkParams(2); return makeOp(CLt, v[1], v[0], p);
		case "lte", "sle": checkParams(2); return makeOp(CGte, v[1], v[0], p);

		default:
		}
		return error("Unknown operation '" + n + "'", p);
	}

	function parseValue( e : Expr ) : CodeValue {
		switch( e.expr ) {
		case EField(ef, f):
			var v = parseValue(ef);
			switch( v.d ) {
			case CVar(v, swiz):
				if( swiz == null ) {
					swiz = getSwiz(f, v.type, e.pos);
					return { d : CVar(v,swiz), t : makeFloat(swiz.length), p : e.pos };
				}
			default:
			}
		case EConst(c):
			switch( c ) {
			case CType(i), CIdent(i):
				var v = vars.get(i);
				if( v == null ) error("Unknown identifier '" + i + "'", e.pos);
				return { d : CVar(v), t : v.type, p : e.pos };
			case CInt(v):
				return allocConst([v],e.pos);
			case CFloat(f):
				return allocConst([f],e.pos);
			default:
			}
		case EBinop(op, e1, e2):
			var op = switch( op ) {
			case OpMult: "mul";
			case OpAdd: "add";
			case OpDiv: "div";
			case OpSub: "sub";
			case OpLt: "lt";
			case OpLte: "lte";
			case OpGt: "gt";
			case OpGte: "gte";
			default: error("Unsupported operation", e.pos);
			};
			return makeCall(op, [e1, e2], e.pos);
		case EUnop(op, _, e1):
			if( op == OpNeg )
				return makeCall("neg", [e1], e.pos);
		case ECall(c, params):
			switch( c.expr ) {
			case EField(v, f):
				return makeCall(f, [v].concat(params), e.pos);
			case EConst(c):
				switch( c ) {
				case CIdent(i), CType(i):
					return makeCall(i, params, e.pos);
				default:
				}
			default:
			}
		case EArrayDecl(values):
			var consts = [];
			for( e in values ) {
				switch( e.expr ) {
				case EConst(c):
					switch( c ) {
					case CInt(i): consts.push(i); continue;
					case CFloat(f): consts.push(f); continue;
					default:
					}
				default:
				}
				error("Vector value should be constant", e.pos);
			}
			if( consts.length == 0 || consts.length > 4 )
				error("Vector size should be 1-4", e.pos);
			return allocConst(consts, e.pos);
		case EArray(e1, e2):
			var v = parseValue(e1);
			var i = switch( e2.expr ) {
			case EConst(c):
				switch(c) {
				case CInt(v): Std.parseInt(v);
				default: null;
				}
			default: null;
			};
			if( i == null )
				error("Array index should be constant", v.p);
			if( i < 0 || i > 3 )
				error("Array index out of bounds", v.p);
			if( !isMatrix(v.t) )
				error("You can only access vectors from a matrix", e1.pos);
			switch( v.d ) {
			case CVar(v, _):
				var v : Variable = {
					name : v.name+"["+i+"]",
					kind : v.kind,
					index : v.index + i,
					type : TFloat4,
					write : v.write,
					read : v.read,
					pos : e.pos,
					const : null,
				};
				return { d : CVar(v), t : TFloat4, p : e.pos };
			default:
			}
		case EParenthesis(k):
			var v = parseValue(k);
			v.p = e.pos;
			return v;
		default:
		}
		error("Unsupported value expression", e.pos);
		return null;
	}

}