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
package format.agal;
import format.agal.Data;
import format.hxsl.Data;

class Compiler {

	var code : Array<Opcode>;
	var tempCount : Int;
	var tempMax : Int;
	var curPos : Position;

	public function new() {
	}

	public dynamic function error( msg : String, p : Position ) {
		throw msg;
	}

	function allocTemp( t ) {
		return { t : RTemp, index : -(Tools.regSize(t) + tempCount * 32), swiz : initSwiz(t) };
	}
	
	function checkTmp( r : Reg ) {
		if( r.index >= 0 ) return;
		// restore temp count
		tempCount = ( -r.index) >> 5;
		var index = tempCount;
		tempCount += (-r.index) & 31;
		if( tempCount > tempMax )
			error("Maximum temporary count reached", curPos);
		r.index = index;
	}

	function initSwiz( t : VarType ) {
		return switch( t ) { case TFloat: [X]; case TFloat2: [X, Y]; case TFloat3: [X, Y, Z]; default: null; };
	}

	function convertSwiz( swiz : Array<Comp> ) : Array<C> {
		if( swiz == null ) return null;
		var sz = [];
		for( s in swiz )
			switch( s ) {
			case X: sz.push(X);
			case Y: sz.push(Y);
			case Z: sz.push(Z);
			case W: sz.push(W);
			}
		return sz;
	}
	
	function reg( v : Variable, ?swiz ) {
		var swiz = if( swiz == null ) initSwiz(v.type) else convertSwiz(swiz);
		var t = switch( v.kind ) {
		case VParam: RConst;
		case VOut: ROut;
		case VTmp: RTemp;
		case VVar: RVar;
		case VInput: RAttr;
		case VTexture: throw "assert";
		}
		return { t : t, index : v.index, swiz : swiz };
	}

	function delta( r : Reg, n : Int) {
		return { t : r.t, index : r.index + n, swiz : r.swiz };
	}

	function swizOpt( r : Reg, s ) {
		if( r.swiz == null ) r.swiz = s;
		return r;
	}

	public function compile( c : Code ) : Data {
		code = [];
		tempMax = format.agal.Tools.getProps(RTemp, !c.vertex).count;
		for( e in c.exprs ) {
			tempCount = c.tempSize;
			curPos = e.e.p;
			if( e.v == null ) {
				// assume dest not check
				compileTo({ t : ROut, index : -1, swiz : null }, e.e);
				continue;
			}
			var d = switch( e.v.d ) {
			case CVar(v, swiz): reg(v,swiz);
			default: throw "assert";
			}
			// fragment shader does not allow direct operations to output
			if( !c.vertex && d.t == ROut )
				switch( e.e.d ) {
				case COp(_), CTex(_), CUnop(_):
					var t = allocTemp(e.v.t);
					compileTo(t, e.e);
					mov(d, t, e.v.t);
					continue;
				case CVar(_), CSwiz(_):
				}
			compileTo(d, e.e);
		}
		return {
			fragmentShader : !c.vertex,
			code : code,
		};
	}

	function isMatrix( t : VarType ) {
		return switch( t ) {
		case TMatrix44(_): true;
		default: false;
		}
	}

	function project( dst : Reg, r1 : Reg, r2 : Reg ) {
		code.push(ODp4( { t : dst.t, index : dst.index, swiz : [X] }, r1, r2));
		code.push(ODp4( { t : dst.t, index : dst.index, swiz : [Y] }, r1, delta(r2, 1)));
		code.push(ODp4( { t : dst.t, index : dst.index, swiz : [Z] }, r1, delta(r2, 2)));
		return ODp4( { t : dst.t, index : dst.index, swiz : [W] }, r1, delta(r2, 3));
	}

	function matrix44multiply( rt : VarType, dst : Reg, r1 : Reg, r2 : Reg ) {
		switch( rt ) {
		case TMatrix44(t):
			if( t.t ) {
				// result must be transposed, let's inverse operands
				var tmp = r1;
				r1 = r2;
				r2 = tmp;
			}
		default:
		}
		// for some reason, using four OM44 here trigger an error (?)
		code.push(project(dst,r1,r2));
		code.push(project(delta(dst, 1), delta(r1, 1), r2));
		code.push(project(delta(dst, 2), delta(r1, 2), r2));
		return project(delta(dst, 3), delta(r1, 3), r2);
	}

	function mov( dst : Reg, src : Reg, t : VarType ) {
		switch( t ) {
		case TFloat:
			code.push(OMov(swizOpt(dst,[X]), src));
		case TFloat2:
			code.push(OMov(swizOpt(dst,[X,Y]), src));
		case TFloat3:
			code.push(OMov(swizOpt(dst,[X,Y,Z]), src));
		default:
			for( i in 0...Tools.regSize(t) )
				code.push(OMov(delta(dst,i), delta(src,i)));
		}
	}

	function toInt( t : VarType, p : Position, dst : Reg, src : Reg ) {
		var tmp = allocTemp(t);
		checkTmp(tmp);
		code.push(OFrc(tmp, src));
		return OSub(dst, src, tmp);
	}

	function compileTo( dst : Reg, e : CodeValue ) {
		switch( e.d ) {
		case CVar(_), CSwiz(_):
			var r = compileSrc(e);
			checkTmp(dst);
			mov(dst, r, e.t);
		case COp(op, e1, e2):
			var v1 = compileSrc(e1);
			var v2 = compileSrc(e2);
			// it is not allowed to apply an operation on two constants or two vars at the same time : use a temp var
			if( (v1.t == RConst && v2.t == RConst) || (v1.t == RVar && v2.t == RVar) ) {
				var t = allocTemp(e1.t);
				checkTmp(t);
				mov(t, v1, e1.t);
				v1 = t;
			}
			checkTmp(dst);
			code.push((switch(op) {
			case CAdd: OAdd;
			case CDiv: ODiv;
			case CMin: OMin;
			case CMax: OMax;
			case CDot: if( e1.t == TFloat4 ) ODp4 else ODp3;
			case CCross: OCrs;
			case CMul:
				if( isMatrix(e2.t) ) {
					switch( e1.t ) {
					case TFloat4: OM44;
					case TFloat3: if( e.t == TFloat4 ) OM34 else OM33;
					case TMatrix44(_): callback(matrix44multiply, e.t);
					default: throw "assert";
					}
				} else
					OMul;
			case CSub: OSub;
			case CPow: OPow;
			case CGte: OSge;
			case CLt: OSlt;
			})(dst, v1, v2));
		case CUnop(op, p):
			switch( op ) {
			case CLen:
				compileTo(dst, { d : COp(CDot, p, p), p : e.p, t : e.t } );
				return;
			default:
			}
			var v = compileSrc(p);
			checkTmp(dst);
			if( dst.t == RVar && op == CNorm ) {
				var t = allocTemp(p.t);
				checkTmp(t);
				code.push(ONrm(t, v));
				mov(dst, t, p.t);
				return;
			}
			code.push((switch(op) {
			case CRcp: ORcp;
			case CSqrt: OSqt;
			case CRsq: ORsq;
			case CLog: OLog;
			case CExp: OExp;
			case CLen: throw "assert";
			case CSin: OSin;
			case CCos: OCos;
			case CAbs: OAbs;
			case CNeg: ONeg;
			case CSat: OSat;
			case CFrac: OFrc;
			case CNorm: ONrm;
			case CKill: function(dst, v) return OKil(v);
			case CInt: callback(toInt,p.t,p.p);
			})(dst, v));
		case CTex(v, acc, flags):
			var vtmp = compileSrc(acc);
			// getting texture from a const is not allowed
			if( vtmp.t == RConst ) {
				var t = allocTemp(acc.t);
				checkTmp(t);
				mov(t, vtmp, acc.t);
				vtmp = t;
			}
			checkTmp(dst);
			var tflags = [];
			for( f in flags )
				tflags.push(switch(f) {
				case T2D: T2D;
				case TCube: TCube;
				case T3D: T3D;
				case TMipMapDisable: TMipMapDisable;
				case TMipMapNearest: TMipMapNearest;
				case TMipMapLinear: TMipMapLinear;
				case TCentroidSample: TCentroidSample;
				case TWrap: TWrap;
				case TClamp: TClamp;
				case TFilterNearest: TFilterNearest;
				case TFilterLinear: TFilterLinear;
				});
			code.push(OTex(dst, vtmp, { index : v.index, flags : tflags } ));
		}
	}

	function compileSrc( e : CodeValue ) {
		switch( e.d ) {
		case CVar(v, swiz):
			return reg(v, swiz);
		case CSwiz(e, swiz):
			var v = compileSrc(e);
			//if( v.swiz != null )
			//	throw "assert";
			return { t : v.t, swiz : convertSwiz(swiz), index : v.index };
		case COp(_), CTex(_), CUnop(_):
			var t = allocTemp(e.t);
			compileTo(t, e);
			return t;
		}
	}

}
