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
	var tempCount : Int;
	var helpers : Hash<Data.ParsedCode>;
	var ret : { v : CodeValue };
	var allowTextureRead : Bool;

	public var config : { inlTranspose : Bool, inlInt : Bool, allowAllWMasks : Bool };

	public function new() {
		tempCount = 0;
		vars = new Hash();
		config = { inlTranspose : true, inlInt : true, allowAllWMasks : false };
		indexes = [0, 0, 0, 0, 0, 0];
		ops = new Array();
		for( o in initOps() )
			ops[Type.enumIndex(o.op)] = o.types;
	}

	function initOps() {
		var mat4 = TMatrix(4, 4, { t : false } );
		var mat4_t = TMatrix(4, 4, { t : true } );
		var mat3 = TMatrix(3, 3, { t : false } );
		var mat3_t = TMatrix(3, 3, { t : true } );

		var floats = [
			{ p1 : TFloat, p2 : TFloat, r : TFloat },
			{ p1 : TFloat2, p2 : TFloat2, r : TFloat2 },
			{ p1 : TFloat3, p2 : TFloat3, r : TFloat3 },
			{ p1 : TFloat4, p2 : TFloat4, r : TFloat4 },
		];
		var ops = [];
		for( o in Lambda.map(Type.getEnumConstructs(CodeOp), function(c) return Type.createEnum(CodeOp, c)) )
			ops.push({ op : o, types : switch( o ) {
				case CAdd, CSub, CDiv, CPow, CMod: floats;
				case CMin, CMax, CLt, CGte: floats;
				case CDot: [ { p1 : TFloat4, p2 : TFloat4, r : TFloat }, { p1 : TFloat3, p2 : TFloat3, r : TFloat } ];
				case CCross: [ { p1 : TFloat3, p2 : TFloat3, r : TFloat3 }];
				case CMul: floats.concat([
					{ p1 : TFloat4, p2 : mat4_t, r : TFloat4 },
					{ p1 : TFloat3, p2 : mat3_t, r : TFloat3 },
					{ p1 : TFloat3, p2 : mat4_t, r : TFloat3 }, // only use the 3x4 part of the matrix
					{ p1 : mat4, p2 : mat4_t, r : mat4 },
					{ p1 : mat3, p2 : mat3_t, r : mat3 },
					{ p1 : mat4_t, p2 : mat4, r : mat4_t },
					{ p1 : mat3_t, p2 : mat3, r : mat3_t },
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
		switch( t ) {
		case TMatrix(r, c, t):
			return "M" + r + "" + c + (t.t ? "T" : "");
		case TTexture(cube):
			return cube ? "CubeTexture" : "Texture";
		default:
			return Std.string(t).substr(1);
		}

	}

	public function compile( h : ParsedHxsl ) : Data {
		allocVar("out", VOut, TFloat4, h.pos);

		helpers = h.helpers;

		var input = [];
		for( v in h.input )
			input.push(allocVar(v.n, VInput, v.t, v.p));

		for( v in h.vars )
			allocVar(v.n, VVar, v.t, v.p);

		var vertex = compileShader(h.vertex,true);
		var fragment = compileShader(h.fragment,false);

		return { input : input, vertex : vertex, fragment : fragment };
	}

	function compileShader( c : ParsedCode, vertex : Bool ) : Code {
		cur = {
			vertex : vertex,
			pos : c.pos,
			consts : [],
			args : [],
			exprs : [],
			tex : [],
			tempSize : 0,
		};
		for( v in c.args )
			switch( v.t ) {
			case TTexture(_):
				if( cur.vertex ) error("You can't use a texture inside a vertex shader", v.p);
				cur.tex.push(allocVar(v.n, VTexture, v.t, v.p));
			default:
				cur.args.push(allocVar(v.n, VParam, v.t, v.p));
			}

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

	function saveVars() {
		var old = new Hash();
		for( v in vars.keys() )
			old.set(v, vars.get(v));
		return old;
	}

	function closeBlock( old : Hash<Variable> ) {
		for( v in vars )
			if( v.kind == VTmp && old.get(v.name) != v && !v.read )
				warn("Unused local variable '" + v.name + "'", v.pos);
		vars = old;
	}

	function compileAssign( v : Null<ParsedValue>, e : ParsedValue, p : Position ) {
		if( v == null ) {
			switch( e.v ) {
			case PBlock(el):
				var old = saveVars();
				for( e in el )
					compileAssign(e.v, e.e, e.p);
				closeBlock(old);
				return;
			case PReturn(v):
				if( ret == null ) error("Unexpected return", e.p);
				if( ret.v != null ) error("Duplicate return", e.p);
				ret.v = compileValue(v);
				checkRead(ret.v);
				return;
			default:
			}
			var e = compileValue(e);
			switch( e.d ) {
			case CUnop(op, _):
				if( op == CKill ) {
					checkRead(e);
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
		var v = compileValue(v,true);
		unify(e.t, v.t, e.p);
		addAssign(v, e, p);
	}

	function addAssign( v : CodeValue, e : CodeValue, p : Position ) {
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
			case VOut:
				if( !cur.vertex && vr.write != 0 ) error("You must use a single write for fragment shader output", v.p);
				vr.write |= bits;
			case VTmp:
				vr.write |= bits;
				vr.assign = null;
				switch( e.d ) {
				case CVar(v2, s2):
					if( v2.kind != VTmp && bits == fullBits(vr.type) ) {
						if( s2 == null ) s2 = [X, Y, Z, W];
						vr.assign = { v : v2, s : s2 };
					}
				default:
				}
			case VTexture:
				error("You can't write to a texture", v.p);
			}
			if( swiz != null ) {
				var min = -1;
				for( s in swiz ) {
					var k = Type.enumIndex(s);
					if( k <= min || (!config.allowAllWMasks && swiz.length > 1 && k != min + 1) ) error("Unsupported write mask", v.p);
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
		if( vars.exists(name) && k != VTmp ) error("Duplicate variable '" + name + "'", p);
		var tkind = Type.enumIndex(k);
		var v : Variable = {
			name : name,
			type : t,
			kind : k,
			index : indexes[tkind],
			pos : p,
			read : false,
			write : if( k == null ) fullBits(t) else switch( k ) { case VInput, VParam: fullBits(t); default: 0; },
			assign : null,
		};
		#if neko
		var me = this;
		untyped v.__string = function() return neko.NativeString.ofString(__this__.name + ":"+me.typeStr(__this__.type));
		#end
		vars.set(name, v);
		indexes[tkind] += Tools.regSize(t);
		return v;
	}

	function allocTemp( t, p ) {
		return allocVar("$t" + tempCount++, VTmp, t, p);
	}

	function allocConst( cvals : Array<String>, p : Position ) : CodeValue {
		var swiz = [X, Y, Z, W];
		// remove extra zeroes at end
		for( i in 0...cvals.length ) {
			var v = cvals[i];
			if( v.indexOf(".") < 0 ) v += ".";
			while( v.charCodeAt(v.length - 1) == "0".code )
				v = v.substr(0, v.length - 1);
			cvals[i] = v;
		}
		// find an already existing constant
		for( index in 0...cur.consts.length ) {
			var c = cur.consts[index];
			var s = [];
			for( v in cvals ) {
				for( i in 0...c.length )
					if( c[i] == v ) {
						s.push(swiz[i]);
						break;
					}
			}
			if( s.length == cvals.length )
			return makeConst(index,s,p);
		}
		// find an empty slot
		for( i in 0...cur.consts.length ) {
			var c = cur.consts[i];
			if( c.length + cvals.length <= 4 ) {
				var s = [];
				for( v in cvals ) {
					s.push(swiz[c.length]);
					c.push(v);
				}
				return makeConst(i,s,p);
			}
		}
		var index = cur.consts.length;
		cur.consts.push(cvals);
		return makeConst(index, swiz.splice(0, cvals.length), p);
	}

	function makeConst(index:Int, swiz, p) {
		var v : Variable = {
			name : "$c" + index,
			kind : VParam,
			type : TFloat4,
			index : index + indexes[Type.enumIndex(VParam)],
			read : true,
			write : 0,
			pos : p,
			assign : null,
		};
		return { d : CVar(v, swiz), t : Tools.makeFloat(swiz.length), p : p };
	}

	function constSwiz(k,count) {
		var s = [];
		var e = [X, Y, Z, W][k];
		for( i in 0...count ) s.push(e);
		return s;
	}

	function checkVars() {
		var shader = (cur.vertex ? "vertex" : "fragment")+" shader";
		for( v in vars ) {
			var p = v.pos;
			switch( v.kind ) {
			case VOut:
				if( v.write == 0 ) error("Output is not written by " + shader, p);
				if( v.write != fullBits(v.type) ) error("Some output components are not written by " + shader, p);
				v.write = 0; // reset status between two shaders
			case VVar:
				if( cur.vertex ) {
					if( v.write == 0 ) {
						// delay error
					} else if( v.write != fullBits(v.type) )
						error("Some components of variable '" + v.name + "' are not written by vertex shader", p);
					else if( v.write != 15 ) {
						// force the output write
						padWrite(v);
					}
				} else {
					if( !v.read && v.write == 0 )
						warn("Variable '" + v.name + "' is not used", p);
					else if( !v.read )
						warn("Variable '" + v.name + "' is not read by " + shader, p);
					else if( v.write == 0 )
						error("Variable '" + v.name + "' is not written by vertex shader", p);
				}
			case VInput:
				if( cur.vertex && !v.read ) {
					warn("Input '" + v.name + "' is not used by " + shader, p);
					// force the input read
					addAssign( { d : CVar(allocTemp(TFloat4, p)), t : TFloat4, p : p }, { d : CVar(v), t : TFloat4, p : p }, p);
				}
			case VTmp:
				if( !v.read ) warn("Unused local variable '" + v.name+"'", p);
			case VParam:
				if( !v.read ) warn("Parameter '" + v.name + "' not used by " + shader, p);
			case VTexture:
				if( !v.read ) {
					warn("Unused texture " + v.name, p);
					// force the texture read
					var t = { d : CVar(allocTemp(TFloat4, p)), t : TFloat4, p : p };
					var cst = switch( v.type ) {
					case TTexture(cube): cube ? ["0","0","0"] : ["0","0"];
					default: throw "assert";
					}
					addAssign(t, { d : CTex(v,allocConst(cst,p),[]), t : TFloat4, p : p }, p);
				}
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
						// only allow "mov" extension if we are sure that the variable is padded with "1"
						if( v2.kind == VInput || v2.kind == VVar ) {
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
						}
					default:
					}
				}
			default:
			}
		}
		// store 1-values into remaining components
		var missing = [], ones = [];
		for( i in Tools.floatSize(v.type)...4 ) {
			missing.push(Type.createEnumIndex(Comp, i));
			ones.push("1");
		}
		var c = allocConst(ones,v.pos);
		checkRead(c);
		cur.exprs.push( { v : { d : CVar(v, missing), t : Tools.makeFloat(missing.length), p : v.pos }, e : c } );
	}

	function rowVar( v : Variable, row : Int ) {
		var v2 = Reflect.copy(v);
		v2.name += "[" + row + "]";
		v2.index += row;
		v2.type = Tools.makeFloat(switch( v.type ) {
		case TMatrix(r, c, t): if( t.t ) r else c;
		default: -1;
		});
		return v2;
	}

	function isGoodSwiz( s : Array<Comp> ) {
		if( s == null ) return true;
		var cur = 0;
		for( x in s )
			if( Type.enumIndex(x) != cur++ )
				return false;
		return true;
	}

	function isUnsupportedWriteMask( s : Array<Comp> ) {
		return s != null && s.length > 1 && (s[0] != X || s[1] != Y || (s.length > 2 && (s[2] != Z || (s.length > 3 && s[3] != W))));
	}

	function checkRead( e : CodeValue ) {
		switch( e.d ) {
		case CVar(v, swiz):
			switch( v.kind ) {
			case VOut: error("Output cannot be read", e.p);
			case VVar: if( cur.vertex ) error("You cannot read variable in vertex shader", e.p); v.read = true;
			case VParam: v.read = true;
			case VTmp:
				if( v.write == 0 ) error("Variable '"+v.name+"' has not been initialized", e.p);
				var bits = swizBits(swiz, v.type);
				if( v.write & bits != bits ) error("Some fields of '"+v.name+"' have not been initialized", e.p);
				v.read = true;
			case VInput:
				if( !cur.vertex ) error("You cannot read input variable in fragment shader", e.p);
				v.read = true;
			case VTexture:
				if( !allowTextureRead )
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
		case CBlock(_, v):
			checkRead(v);
		}
	}

	function compileValue( e : ParsedValue, ?isTarget ) : CodeValue {
		switch( e.v ) {
		case PBlock(_), PReturn(_):
			throw "assert";
		case PVar(vname):
			var v = vars.get(vname);
			if( v == null ) error("Unknown variable '" + vname + "'", e.p);
			var swiz = null;
			var t = v.type;
			if( isTarget )
				v.assign = null;
			else if( v.assign != null ) {
				v.read = true;
				swiz = v.assign.s;
				v = v.assign.v;
			}
			return { d : CVar(v,swiz), t : t, p : e.p };
		case PConst(i):
			return allocConst([i], e.p);
		case PLocal(v):
			var v = allocVar(v.n, VTmp, v.t, v.p);
			return { d : CVar(v), t : v.type, p : e.p };
		case PSwiz(v, s):
			// compile e[row].col
			if( s.length == 1 ) switch( v.v ) {
			case PRow(v, index):
				var v = compileValue(v,isTarget);
				switch( v.t ) {
				case TMatrix(r, c, t):
					if( t.t == null ) t.t = false;
					if( index < 0 || index >= r ) error("You can't access row " + index + " on " + typeStr(v.t), e.p);
					for( s in s ) if( Type.enumIndex(s) >= c ) error("You can't access colum " + Std.string(s) + " on " + typeStr(v.t), e.p);
					// inverse row/col
					if( t.t ) {
						var s2 = [[X,Y,Z,W][index]];
						index = Type.enumIndex(s[0]);
						s = s2;
						var tmp = r;
						r = c;
						c = r;
					}
					switch( v.d ) {
					case CVar(vr, _):
						checkRead(v);
						var v2 = rowVar(vr, index);
						return { d : CVar(v2, s), t : TFloat, p : e.p };
					default:
						// we could use a temp but there's a lot of calculus lost anyway, so let's the user think about it
						error("You can't access matrix row on a complex expression", e.p);
					}
				default:
					// let's fall through, we will get an error anyway
				}
			default:
			}
			var v = compileValue(v,isTarget);
			// check swizzling according to value type
			var count = switch( v.t ) {
			case TFloat: 1;
			case TFloat2: 2;
			case TFloat3, TColor3: 3;
			case TFloat4, TColor: 4;
			case TMatrix(_), TTexture(_): 0;
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
				return { d : CVar(v, ns), t : Tools.makeFloat(s.length), p : e.p };
			default:
				return { d : CSwiz(v, s), t : Tools.makeFloat(s.length), p : e.p };
			}
		case POp(op, e1, e2):
			return makeOp(op, e1, e2, e.p);
		case PUnop(op, e1):
			return makeUnop(op, e1, e.p);
		case PTex(vname, acc, flags):
			var v = vars.get(vname);
			if( v == null ) error("Unknown texture '" + vname + "'", e.p);
			var acc = compileValue(acc);
			switch( v.type ) {
			case TTexture(cube):
				unify(acc.t, cube?TFloat3:(Lambda.has(flags,TSingle) ? TFloat : TFloat2), acc.p);
			default: error("'"+vname + "' is not a texture", e.p);
			}
			return { d : CTex(v, acc, flags), t : TFloat4, p : e.p };
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
			return { d : COp(CAdd, e1, e2), t : e1.t, p : e.p };
		case PVector(values):
			return compileVector(values, e.p);
		case PRow(v, index):
			var v = compileValue(v);
			switch( v.t ) {
			case TMatrix(r, c, t):
				if( index < 0 || index >= c ) error("You can't read row " + index + " on " + typeStr(v.t), e.p);
				if( t.t == null ) t.t = false;
				switch( v.d ) {
				case CVar(vr, swiz):
					if( t.t ) error("You can't read a row from a transposed matrix", e.p); // TODO : use temp
					checkRead(v);
					var vr = rowVar(vr, index);
					return { d : CVar(vr), t : vr.type, p : e.p };
				default:
					error("You can't read a row from a complex expression", e.p); // TODO : use temp
				}
			default:
				unify(v.t, TMatrix(4, 4, { t : null } ), v.p);
			}
			throw "assert"; // unreachable
		case PCall(n,vl):
			var h = helpers.get(n);
			if( h == null ) error("Unknown function '" + n + "'", e.p);
			var vals = [];
			allowTextureRead = true;
			for( v in vl )
				vals.push(compileValue(v));
			allowTextureRead = false;
			if( h.args.length != vl.length ) error("Function " + n + " requires " + h.args.length + " arguments", e.p);
			var old = saveVars();
			// only allow access to globals/output from within out helper functions
			for( v in old )
				switch( v.kind ) {
				case VTmp, VTexture, VParam: vars.remove(v.name);
				case VOut, VInput, VVar:
				}
			// init args
			for( i in 0...h.args.length ) {
				var value = vals[i];
				var a = h.args[i];
				unify(value.t, a.t, value.p);
				switch( a.t ) {
				case TTexture(_):
					switch( value.d ) {
					case CVar(v, _):
						// copy variable
						vars.set(a.n, v);
					default:
						error("Invalid texture access", value.p);
					}
				default:
					var v = allocVar(a.n, VTmp, a.t, a.p);
					addAssign( { d : CVar(v), t : v.type, p : v.pos }, value, value.p );
				}
			}
			// compile block
			var rold = ret;
			ret = { v : null };
			for( e in h.exprs )
				compileAssign(e.v, e.e, e.p);
			var v = ret.v;
			if( v == null )
				error("Missing return", h.pos);
			ret = rold;
			closeBlock(old);
			return { d : v.d, t : v.t, p : e.p };
		};
	}

	function compileVector(values:Array<ParsedValue>, p) {
		if( values.length == 0 || values.length > 4 )
			error("Vector size should be 1-4", p);
		var consts = [];
		var exprs = [];
		for( i in 0...values.length ) {
			var e = values[i];
			switch( e.v ) {
			case PConst(c): consts.push(c);
			default: exprs[i] = compileValue(e);
			}
		}
		// all values are constants
		if( consts.length == values.length )
			return allocConst(consts, p);
		// declare a new temporary
		var v = allocTemp(Tools.makeFloat(values.length),p);
		// assign expressions first
		var old = cur.exprs;
		cur.exprs = [];
		var write = [];
		for( i in 0...values.length ) {
			var e = exprs[i];
			var c = [X, Y, Z, W][i];
			if( e == null ) {
				write.push(c);
				continue;
			}
			unify(e.t,TFloat,e.p);
			addAssign( { d : CVar(v, [c]), t : TFloat, p : e.p }, e, p);
		}
		// assign constants if any
		if( write.length > 0 ) {
			if( isUnsupportedWriteMask(write) )
				for( i in 0...write.length )
					addAssign( { d : CVar(v, [write[i]]), t : TFloat, p : p }, allocConst([consts[i]], p), p);
			else
				addAssign( { d : CVar(v, write), t : Tools.makeFloat(write.length), p : p }, allocConst(consts, p), p);
		}
		// return temporary
		var ret = { d : CVar(v), t : v.type, p : p };
		var sub = { d : CBlock(cur.exprs, ret), t : ret.t, p : p };
		cur.exprs = old;
		return sub;
	}

	function tryUnify( t1 : VarType, t2 : VarType ) {
		if( t1 == t2 ) return true;
		switch( t1 ) {
		case TMatrix(r,c,t1):
			switch( t2 ) {
			case TMatrix(r2, c2, t2):
				if( r != r2 || c != c2 ) return false;
				if( t1.t == null ) {
					if( t2.t == null ) t2.t = false;
					t1.t = t2.t;
					return true;
				}
				return( t1.t == t2.t );
			default:
			}
		case TTexture(c1):
			switch( t2 ) {
			case TTexture(c2): return c1 == c2;
			default:
			}
		case TFloat3, TColor3:
			return (t2 == TFloat3 || t2 == TColor3);
		case TFloat4, TColor:
			return (t2 == TFloat4 || t2 == TColor);
		default:
		}
		return false;
	}

	function unify(t1, t2, p) {
		if( !tryUnify(t1, t2) ) {
			// if we only have the transpose flag different, let's print a nice error message
			switch(t1) {
			case TMatrix(r, c, t):
				switch( t2 ) {
				case TMatrix(r2, c2, t):
					if( r == r2 && c == c2 && t.t != null ) {
						if( t.t )
							error("Matrix is transposed by another operation", p);
						else
							error("Matrix is not transposed by a previous operation", p);
					}
				default:
				}
			default:
			}
			// default error message
			error(typeStr(t1) + " should be " +typeStr(t2), p);
		}
	}
	
	function makeConstOp( op : CodeOp, v1 : String, v2 : String, p : Position ) {
		var me = this;
		function makeConst(f:Float->Float->Float) {
			var r = f(Std.parseFloat(v1), Std.parseFloat(v2));
			if( r + 1 == r ) r = 0; // NaN / Infinite
			return { v : PConst(Std.string(r)), p : p };
		}
		return switch( op ) {
		case CAdd: makeConst(function(x, y) return x + y);
		case CSub: makeConst(function(x, y) return x - y);
		case CMul: makeConst(function(x, y) return x * y);
		case CMin: makeConst(function(x, y) return x < y ? x : y);
		case CMax: makeConst(function(x, y) return x < y ? y : x);
		case CLt: makeConst(function(x, y) return x < y ? 1 : 0);
		case CGte: makeConst(function(x, y) return x >= y ? 1 : 0);
		case CDot: makeConst(function(x, y) return x * y);
		case CDiv: makeConst(function(x, y) return x / y);
		case CPow: makeConst(function(x, y) return Math.pow(x,y));
		case CMod: makeConst(function(x, y) return x % y);
		case CCross: null;
		};
	}
	

	function makeOp( op : CodeOp, e1 : ParsedValue, e2 : ParsedValue, p : Position ) {

		switch( e1.v ) {
		case PConst(v1):
			switch( e2.v ) {
			case PConst(v2):
				var c = makeConstOp(op, v1, v2, p);
				if( c != null )
					return compileValue(c);
			default:
			}
		default:
		}
		
		switch( op ) {
		// optimize 1 / sqrt(x) && 1 / x
		case CDiv:
			switch( e1.v ) {
			case PConst(c):
				if( Std.parseFloat(c) == 1 ) {
					switch( e2.v ) {
					case PUnop(op, v):
						if( op == CSqrt )
							return makeUnop(CRsq, v, p);
					default:
					}
					return makeUnop(CRcp, e2, p);
				}
			default:
			}
		// optimize 2^x
		case CPow:
			switch( e1.v ) {
			case PConst(c):
				if( Std.parseFloat(c) == 2 )
					return makeUnop(CExp, e2, p);
			default:
			}
		default:
		}

		var e1 = compileValue(e1);
		var e2 = compileValue(e2);

		// look for a valid operation as listed in "ops"
		var types = ops[Type.enumIndex(op)];
		var first = null;
		for( t in types ) {
			if( isCompatible(e1.t, t.p1) && isCompatible(e2.t, t.p2) ) {
				if( first == null ) first = t;
				if( tryUnify(e1.t, t.p1) && tryUnify(e2.t, t.p2) )
					return { d : COp(op, e1, e2), t : t.r, p : p };
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
					return { d : COp(op,e1,{ d : CSwiz(e2, swiz), t : e1.t, p : e2.p }), t : e1.t, p : p };
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
					return { d : COp(op,{ d : CSwiz(e1, swiz), t : e2.t, p : e1.p }, e2), t : e2.t, p : p };
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

	function makeConstUnop( op : CodeUnop, v : String, p : Position ) {
		var me = this;
		function makeConst(f:Float->Float) {
			var r = f(Std.parseFloat(v));
			if( r + 1 == r ) r = 0; // NaN / Infinite
			return { v : PConst(Std.string(r)), p : p };
		}
		return switch( op ) {
		case CNorm, CTrans, CKill: null; // invalid
		case CInt: makeConst(function(x) return Std.int(x));
		case CFrac: makeConst(function(x) return x % 1.);
		case CExp: makeConst(Math.exp);
		case CAbs: makeConst(Math.abs);
		case CRsq: makeConst(function(x) return 1 / Math.sqrt(x));
		case CRcp: makeConst(function(x) return 1 / x);
		case CLog: makeConst(Math.log);
		case CSqrt: makeConst(Math.sqrt);
		case CSin: makeConst(Math.sin);
		case CCos: makeConst(Math.cos);
		case CSat: makeConst(Math.cos);
		case CNeg: makeConst(function(x) return -x);
		case CLen: makeConst(function(x) return x);
		};
	}
	
	function makeUnop( op : CodeUnop, e : ParsedValue, p : Position ) {

		// compile constant expression
		switch( e.v ) {
		case PConst(v):
			var c = makeConstUnop(op, v, p);
			if( c != null )
				return compileValue(c);
		default:
		}
		
		var e = compileValue(e);
		var rt = e.t;
		switch( op ) {
		case CNorm: rt = TFloat3;
		case CLen: rt = TFloat;
		case CTrans:
			switch( e.t ) {
			case TMatrix(r, c, t):
				// transpose-free ?
				if( t.t == null ) {
					t.t = true;
					e.p = p;
					return e;
				}
				if( config.inlTranspose ) {
					var v = switch( e.d ) {
					case CVar(v, _): v;
					default: error("You cannot transpose a complex expression", e.p);
					}
					var t0 = null;
					var tr = Tools.makeFloat(r);
					var vrow = [];
					for( s in 0...r )
						vrow.push(rowVar(v, s));
					for( i in 0...c ) {
						var t = allocTemp(tr, p);
						t.read = true; // will be readed by the matrix we build
						if( t0 == null ) t0 = t;
						for( s in 0...r )
							addAssign( { d : CVar(t,[[X, Y, Z, W][s]]), t : TFloat, p : p }, { d : CVar(vrow[s],[[X,Y,Z,W][i]]), t : TFloat, p : p }, p);
					}
					var vmt = Reflect.copy(t0);
					vmt.type = TMatrix(c, r, { t : !t.t } );
					vmt.write = fullBits(vmt.type);
					return { d : CVar(vmt), t : vmt.type, p : p };
				}
				return { d : CUnop(CTrans, e), t : TMatrix(c, r, { t : !t.t } ), p : p };
			default:
			}
		case CInt:
			// inline int(t) as t - frc(t)
			if( config.inlInt ) {
				if( !isFloat(e.t) )
					unify(e.t, TFloat4, e.p); // force error
				var v = allocTemp(e.t, p);
				var ev = { d : CVar(v), t : e.t, p : p };
				addAssign( ev, e, p);
				var efrc = { d : CUnop(CFrac, e), t : e.t, p : p };
				return { d : COp(CSub, ev, efrc), t : e.t, p : p };
			}
		default:
		}
		if( !isFloat(e.t) )
			unify(e.t, TFloat4, e.p); // force error
		return { d : CUnop(op, e), t : rt, p : p };
	}

	function isFloat( t : VarType ) {
		return switch( t ) {
		case TFloat, TFloat2, TFloat3, TFloat4, TColor3, TColor: true;
		default: false;
		};
	}

	function isCompatible( t1 : VarType, t2 : VarType ) {
		if( t1 == t2 ) return true;
		switch( t1 ) {
		case TMatrix(r,c,t1):
			switch( t2 ) {
			case TMatrix(r2,c2,t2):
				return r2 == r && c2 == c && ( t1.t == null || t2.t == null || t1.t == t2.t );
			default:
			}
		case TFloat3, TColor3:
			return (t2 == TFloat3 || t2 == TColor3);
		case TFloat4, TColor:
			return (t2 == TFloat4 || t2 == TColor);
		default:
		}
		return false;
	}

}