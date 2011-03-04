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

private typedef Temp = {
	var liveBits : Array<Int>;
	var bitsDefPos : Array<Int>;
	var assignedTo : Int;
}

class Compiler {

	var code : Array<Opcode>;
	var tempCount : Int;
	var tempMax : Int;
	var curPos : Position;
	var temps : Array<Temp>;
	var codePos : Int;
	var assignRegisters : Bool;
	var startRegister : Int;

	public function new() {
	}

	public dynamic function error( msg : String, p : Position ) {
		throw msg;
	}

	function allocTemp( t ) {
		var index = tempCount;
		tempCount += Tools.regSize(t);
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

	function delta( r : Reg, n : Int, ?s) {
		return { t : r.t, index : r.index + n, swiz : (s == null) ? r.swiz : s };
	}
	
	function swizOpt( r : Reg, s ) {
		if( r.swiz == null ) r.swiz = s;
		return r;
	}
	
	function swizBits( s : Swizzle ) {
		if( s == null )
			return 15;
		var b = 0;
		for( s in s )
			b |= 1 << Type.enumIndex(s);
		return b;
	}

	public function compile( c : Code ) : Data {
		code = [];
		tempMax = format.agal.Tools.getProps(RTemp, !c.vertex).count;
		tempCount = c.tempSize;
		for( e in c.exprs ) {
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
		#if debug
		var old = code.copy();  // used by DEBUG below
		#end
		
		uniqueReg();
		
		curPos = c.pos;
		temps = [];
		assignRegisters = false;
		compileLiveness();

		assignRegisters = true;
		startRegister = 0;
		compileLiveness();
		
		// DEBUG
		/*
		#if debug
		for( i in 0...temps.length ) {
			var bits = temps[i].liveBits;
			var lifes = [];
			var p = 0;
			while( true ) {
				while( p < bits.length && bits[p] == null )
					p++;
				if( p >= bits.length ) break;
				var k = bits[p];
				var start = p;
				while( bits[p] == k )
					p++;
				lifes.push(start + "-"+ (p - 1)+" : "+k);
			}
			trace("T" + i + " " + Std.string(lifes));
		}
		for( i in 0...code.length ) {
			var a = format.agal.Tools.opStr(old[i]);
			var b = format.agal.Tools.opStr(code[i]);
			trace("@"+i+"   "+StringTools.rpad(a," ",30) + (a == b ? "" : b));
		}
		#end
		*/
		
		// remove no-ops
		var i = 0;
		while( i < code.length ) {
			var c = code[i++];
			switch( c ) {
			case OMov(dst, v):
				if( dst.index == v.index && dst.t == v.t && swizBits(dst.swiz) == swizBits(v.swiz) ) {
					code.remove(c);
					i--;
				}
			default:
				// TODO : group dp4/dp3 into m44/m34/m44 ?
			}
		}
			
		return {
			fragmentShader : !c.vertex,
			code : code,
		};
	}
	
	function uniqueReg() {
		function cp(r:Reg) {
			return { t : r.t, index : r.index, swiz : r.swiz };
		}
		for( i in 0...code.length )
			code[i] = switch( code[i] ) {
			case OKil(r): OKil(cp(r));
			case OTex(d, v, fl): OTex(cp(d), cp(v), fl);
			case OMov(d, v), ORcp(d, v), OFrc(d, v), OSqt(d, v), ORsq(d, v), OLog(d, v), OExp(d, v), ONrm(d, v), OSin(d, v), OCos(d, v), OAbs(d, v), ONeg(d, v), OSat(d, v):
				Type.createEnum(Opcode, Type.enumConstructor(code[i]), [cp(d), cp(v)]);
			case OAdd(d, a, b), OSub(d, a, b), OMul(d, a, b), ODiv(d, a, b), OMin(d, a, b), OMax(d, a, b), OPow(d, a, b), OCrs(d, a, b), ODp3(d, a, b), OSge(d, a, b), OSlt(d, a, b), ODp4(d,a,b), OM33(d, a, b),  OM44(d, a, b), OM34(d,a,b):
				Type.createEnum(Opcode, Type.enumConstructor(code[i]), [cp(d), cp(a), cp(b)]);
			};
	}
	
	function compileLiveness() {
		for( i in 0...code.length ) {
			codePos = i;
			switch( code[i] ) {
			case OKil(r):
				oread(r);
			case OTex(d, v, _), OMov(d, v), ORcp(d, v), OFrc(d,v),OSqt(d,v), ORsq(d,v), OLog(d,v),OExp(d,v), ONrm(d,v), OSin(d,v), OCos(d,v), OAbs(d,v), ONeg(d,v), OSat(d,v):
				oread(v);
				owrite(d);
			case OAdd(d, a, b), OSub(d, a, b), OMul(d, a, b), ODiv(d, a, b), OMin(d, a, b), OMax(d, a, b),
				OPow(d, a, b), OCrs(d, a, b), ODp3(d, a, b), OSge(d, a, b), OSlt(d, a, b), ODp4(d,a,b):
				oread(a);
				oread(b);
				owrite(d);
			case OM33(d, a, b),  OM44(d, a, b), OM34(d,a,b):
				if( a.t == RTemp || b.t == RTemp ) throw "assert";
				owrite(d);
			}
		}
	}
	
	function oread( r : Reg ) {
		if( r.t != RTemp ) return;
		var t = temps[r.index];
		if( t == null ) throw "assert";
		var s = if( r.swiz == null ) [X, Y, Z, W] else r.swiz;
		if( assignRegisters ) {
			if( t.assignedTo < 0 ) throw "assert";
			r.index = t.assignedTo;
			return;
		}
		// if we need to read some components at some time
		// make sure that we reserve all the components as soon
		// as the first one is written
		var minPos = null;
		var mask = 0;
		for( s in s ) {
			var bit = Type.enumIndex(s);
			var pos = t.bitsDefPos[bit];
			if( minPos == null || pos < minPos ) minPos = pos;
			mask |= 1 << bit;
		}
		if( minPos < 0 ) throw "assert";
		for( p in minPos+1...codePos ) {
			var k = t.liveBits[p];
			if( k == null ) k = 0;
			t.liveBits[p] = k | mask;
		}
	}

	function owrite( r : Reg ) {
		if( r.t != RTemp ) return;
		var t = temps[r.index];
		if( assignRegisters ) {
			// if we are already live, use our id
			if( t.liveBits[codePos] != null ) {
				r.index = t.assignedTo;
				return;
			}
			// allocate a new temp id by looking the other live variable components
			var tid = -1;
			var found = false;
			// make sure that we reserve all the components we need
			var reserved = t.liveBits[codePos + 1];
			if( reserved == null ) reserved = 0;
			var mask = swizBits(r.swiz) | reserved;
			while( !found ) {
				found = true;
				tid++;
				for( t in temps ) {
					var bits = t.liveBits[codePos];
					if( bits != null && bits & mask != 0 && t.assignedTo == tid ) {
						found = false;
						break;
					}
				}
			}
			t.assignedTo = tid;
			r.index = tid;
			if( tid >= tempMax ) error("Maximum number of temp vars reached", curPos);
			return;
		}
		if( t == null ) {
			t = { liveBits : [], bitsDefPos : [ -1, -1, -1, -1], assignedTo : -1 };
			temps[r.index] = t;
		}
		if( r.swiz == null )
			for( i in 0...4 )
				t.bitsDefPos[i] = codePos;
		else
			for( s in r.swiz )
				t.bitsDefPos[Type.enumIndex(s)] = codePos;
	}
	
	function project( dst : Reg, r1 : Reg, r2 : Reg ) {
		code.push(ODp4( { t : dst.t, index : dst.index, swiz : [X] }, r1, r2));
		code.push(ODp4( { t : dst.t, index : dst.index, swiz : [Y] }, r1, delta(r2, 1)));
		code.push(ODp4( { t : dst.t, index : dst.index, swiz : [Z] }, r1, delta(r2, 2)));
		return ODp4( { t : dst.t, index : dst.index, swiz : [W] }, r1, delta(r2, 3));
	}

	function project3( dst : Reg, r1 : Reg, r2 : Reg ) {
		code.push(ODp3( { t : dst.t, index : dst.index, swiz : [X] }, r1, r2));
		code.push(ODp3( { t : dst.t, index : dst.index, swiz : [Y] }, r1, delta(r2, 1)));
		return ODp3( { t : dst.t, index : dst.index, swiz : [Z] }, r1, delta(r2, 2));
	}

	function matrix44multiply( rt : VarType, dst : Reg, r1 : Reg, r2 : Reg ) {
		switch( rt ) {
		case TMatrix(_,_,t):
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

	function matrix33multiply( rt : VarType, dst : Reg, r1 : Reg, r2 : Reg ) {
		switch( rt ) {
		case TMatrix(_,_,t):
			if( t.t ) {
				// result must be transposed, let's inverse operands
				var tmp = r1;
				r1 = r2;
				r2 = tmp;
			}
		default:
		}
		// for some reason, using three OM33 here trigger an error (?)
		code.push(project3(dst,r1,r2));
		code.push(project3(delta(dst, 1), delta(r1, 1), r2));
		return project3(delta(dst, 2), delta(r1, 2), r2);
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
	
	// we have to make sure that we don't have MXX macros when one of the sources is a temp var
	// or else that might break our temp optimization algorithm because each column might be
	// assigned to a different temporary, and since we can't read+write on the same source without
	// causing issues
	function matrixOp( op : Reg -> Reg -> Reg -> Opcode, num : Int, dst : Reg, a : Reg, b : Reg ) {
		for( i in 0...num )
			code.push(op(delta(dst, 0, [[X, Y, Z, W][i]]), a, delta(b, i)));
		return code.pop();
	}

	function compileTo( dst : Reg, e : CodeValue ) {
		switch( e.d ) {
		case CVar(_), CSwiz(_):
			var r = compileSrc(e);
			mov(dst, r, e.t);
		case COp(op, e1, e2):
			var v1 = compileSrc(e1);
			var v2 = compileSrc(e2);
			// it is not allowed to apply an operation on two constants or two vars at the same time : use a temp var
			if( (v1.t == RConst && v2.t == RConst) || (v1.t == RVar && v2.t == RVar) ) {
				var t = allocTemp(e1.t);
				mov(t, v1, e1.t);
				v1 = t;
			}
			code.push((switch(op) {
			case CAdd: OAdd;
			case CDiv: ODiv;
			case CMin: OMin;
			case CMax: OMax;
			case CDot: if( e1.t == TFloat4 ) ODp4 else ODp3;
			case CCross: OCrs;
			case CMul:
				switch( e2.t ) {
				case TMatrix(_):
					switch( e1.t ) {
					case TFloat4: if( v1.t == RTemp || v2.t == RTemp ) callback(matrixOp,ODp4,4) else OM44;
					case TFloat3: if( v1.t == RTemp || v2.t == RTemp ) callback(matrixOp,e.t == TFloat4 ? ODp4 : ODp3,3) else if( e.t == TFloat4 ) OM34 else OM33;
					case TMatrix(w, h, _):
						if( w == 4 && h == 4 )
							callback(matrix44multiply, e.t);
						else if( w == 3 && h == 3 )
							callback(matrix33multiply, e.t);
						else
							throw "assert";
					default:
						throw "assert";
					}
				default:
					OMul;
				}
			case CSub: OSub;
			case CPow: OPow;
			case CGte: OSge;
			case CLt: OSlt;
			})(dst, v1, v2));
		case CUnop(op, p):
			var v = compileSrc(p);
			switch( op ) {
			case CNorm:
				// normalize into a varying require temp var
				if( dst.t == RVar ) {
					var t = allocTemp(p.t);
					code.push(ONrm(t, v));
					mov(dst, t, p.t);
					return;
				}
			case CLen:
				// compile length(x) as x.dot(x)
				var t = allocTemp(p.t);
				mov(t, v, p.t);
				code.push((p.t == TFloat4 ? ODp4 : ODp3)(dst, t, t));
				return;
			default:
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
			case CInt,CTrans: throw "assert";
			})(dst, v));
		case CTex(v, acc, flags):
			var vtmp = compileSrc(acc);
			// getting texture from a const is not allowed
			if( vtmp.t == RConst ) {
				var t = allocTemp(acc.t);
				mov(t, vtmp, acc.t);
				vtmp = t;
			}
			var tflags = [];
			switch( v.type ) {
			case TTexture(cube):
				if( cube ) tflags.push(TCube);
			default:
			}
			for( f in flags )
				tflags.push(switch(f) {
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
			return { t : v.t, swiz : convertSwiz(swiz), index : v.index };
		case COp(_), CTex(_), CUnop(_):
			var t = allocTemp(e.t);
			compileTo(t, e);
			return t;
		}
	}

}
