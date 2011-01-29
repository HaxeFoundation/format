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

	public function new() {
	}

	public dynamic function error( msg : String, p : Position ) {
		throw msg;
	}

	function allocTemp( t, p ) {
		var index = tempCount;
		tempCount += Tools.regSize(t);
		if( tempCount > tempMax )
			error("Maximum temporary count reached", p);
		return { t : RTemp, index : index, swiz : initSwiz(t) };
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
			var d = switch( e.v.d ) {
			case CVar(v, swiz): reg(v,swiz);
			default: throw "assert";
			}
			tempCount = c.tempSize;
			// fragment shader does not allow direct operations to output
			if( !c.vertex && d.t == ROut )
				switch( e.e.d ) {
				case COp(_), CTex(_), CUnop(_):
					var t = allocTemp(e.v.t,e.e.p);
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
		var tmp = allocTemp(t,p);
		code.push(OFrc(tmp, src));
		return OSub(dst, src, tmp);
	}

	function compileTo( dst : Reg, e : CodeValue ) {
		switch( e.d ) {
		case CVar(_), CSwiz(_):
			mov(dst, compileSrc(e), e.t);
		case COp(op, e1, e2):
			var v1 = compileSrc(e1);
			var v2 = compileSrc(e2);
			// it is not allowed to apply an operation on two constants or two vars at the same time : use a temp var
			if( (v1.t == RConst && v2.t == RConst) || (v1.t == RVar && v2.t == RVar) ) {
				var t = allocTemp(e1.t,e1.p);
				mov(t, v1, e1.t);
				v1 = t;
			}
			code.push((switch(op) {
			case CAdd: OAdd;
			case CDiv: ODiv;
			case CMin: OMin;
			case CMax: OMax;
			case CDot: if( e1.t == TFloat4 ) ODp4 else ODp3;
			case CCrs: OCrs;
			case CMul:
				if( isMatrix(e2.t) ) {
					if( e1.t == TFloat4 )
						OM44
					else if( isMatrix(e1.t) )
						callback(matrix44multiply,e.t)
					else
						throw "assert";
				} else
					OMul;
			case CSub: OSub;
			case CPow: OPow;
			})(dst, v1, v2));
		case CUnop(op, p):
			var v = compileSrc(p);
			code.push((switch(op) {
			case CRcp: ORcp;
			case CSqt: OSqt;
			case CRsq: ORsq;
			case CLog: OLog;
			case CExp: OExp;
			case CLen: ONrm;
			case CSin: OSin;
			case CCos: OCos;
			case CAbs: OAbs;
			case CNeg: ONeg;
			case CSat: OSat;
			case CFrc: OFrc;
			case CInt: callback(toInt,p.t,p.p);
			})(dst, v));
		case CTex(v, acc, flags):
			var vtmp = compileSrc(acc);
			// getting texture from a const is not allowed
			if( vtmp.t == RConst ) {
				var t = allocTemp(acc.t,acc.p);
				mov(t, vtmp, acc.t);
				vtmp = t;
			}
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
			var t = allocTemp(e.t,e.p);
			compileTo(t, e);
			return t;
		}
	}

}
