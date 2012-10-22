/*
 * format - haXe File Formats
 * ABC and SWF support by Nicolas Cannasse
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
package format.abc;
import format.abc.Data;

class OpWriter {

	public var o : haxe.io.Output;

	public function new(o) {
		this.o = o;
	}

	public function writeInt( n : Int ) {
		var e = n >>> 28;
		var d = (n >> 21) & 0x7F;
		var c = (n >> 14) & 0x7F;
		var b = (n >> 7) & 0x7F;
		var a = n & 0x7F;
		if( b != 0 || c != 0 || d != 0 || e != 0 ) {
			o.writeByte(a | 0x80);
			if( c != 0 || d != 0 || e != 0 ) {
				o.writeByte(b | 0x80);
				if( d != 0 || e != 0 ) {
					o.writeByte(c | 0x80);
					if( e != 0 ) {
						o.writeByte(d | 0x80);
						o.writeByte(e);
					} else
						o.writeByte(d);
				} else
					o.writeByte(c);
			} else
				o.writeByte(b);
		} else
			o.writeByte(a);
	}

	#if haxe3
	public function writeInt32( n : Int ) {
		var e = n >>> 28;
		var d = (n >> 21) & 0x7F;
		var c = (n >> 14) & 0x7F;
		var b = (n >> 7) & 0x7F;
		var a = n & 0x7F;
		if( b != 0 || c != 0 || d != 0 || e != 0 ) {
			o.writeByte(a | 0x80);
			if( c != 0 || d != 0 || e != 0 ) {
				o.writeByte(b | 0x80);
				if( d != 0 || e != 0 ) {
					o.writeByte(c | 0x80);
					if( e != 0 ) {
						o.writeByte(d | 0x80);
						o.writeByte(e);
					} else
						o.writeByte(d);
				} else
					o.writeByte(c);
			} else
				o.writeByte(b);
		} else
			o.writeByte(a);
	}
	#else
	public function writeInt32( n : haxe.Int32 ) {
		var e = haxe.Int32.toInt(haxe.Int32.ushr(n,28));
		var n = haxe.Int32.toInt(haxe.Int32.and(n,haxe.Int32.ofInt((1 << 28) - 1)));
		var d = (n >> 21) & 0x7F;
		var c = (n >> 14) & 0x7F;
		var b = (n >> 7) & 0x7F;
		var a = n & 0x7F;
		if( b != 0 || c != 0 || d != 0 || e != 0 ) {
			o.writeByte(a | 0x80);
			if( c != 0 || d != 0 || e != 0 ) {
				o.writeByte(b | 0x80);
				if( d != 0 || e != 0 ) {
					o.writeByte(c | 0x80);
					if( e != 0 ) {
						o.writeByte(d | 0x80);
						o.writeByte(e);
					} else
						o.writeByte(d);
				} else
					o.writeByte(c);
			} else
				o.writeByte(b);
		} else
			o.writeByte(a);
	}
	#end

	function int( i ) {
		writeInt(i);
	}

	inline function b( v : Int ) {
		o.writeByte(v);
	}

	function reg( v : Int ) {
		o.writeByte(v);
	}

	function idx( i : Index<Dynamic> ) {
		switch( i ) {
		case Idx(i): int(i);
		}
	}

	function jumpCode(j) {
		return switch( j ) {
		case JNotLt: 0x0C;
		case JNotLte: 0x0D;
		case JNotGt: 0x0E;
		case JNotGte: 0x0F;
		case JAlways: 0x10;
		case JTrue: 0x11;
		case JFalse: 0x12;
		case JEq: 0x13;
		case JNeq: 0x14;
		case JLt: 0x15;
		case JLte: 0x16;
		case JGt: 0x17;
		case JGte: 0x18;
		case JPhysEq: 0x19;
		case JPhysNeq: 0x1A;
		}
	}

	function operationCode(o) {
		return switch( o ) {
		case OpAs: 0x87;
		case OpNeg: 0x90;
		case OpIncr: 0x91;
		case OpDecr: 0x93;
		case OpNot: 0x96;
		case OpBitNot: 0x97;
		case OpAdd: 0xA0;
		case OpSub: 0xA1;
		case OpMul: 0xA2;
		case OpDiv: 0xA3;
		case OpMod: 0xA4;
		case OpShl: 0xA5;
		case OpShr: 0xA6;
		case OpUShr: 0xA7;
		case OpAnd: 0xA8;
		case OpOr: 0xA9;
		case OpXor: 0xAA;
		case OpEq: 0xAB;
		case OpPhysEq: 0xAC;
		case OpLt: 0xAD;
		case OpLte: 0xAE;
		case OpGt: 0xAF;
		case OpGte: 0xB0;
		case OpIs: 0xB3;
		case OpIn: 0xB4;
		case OpIIncr: 0xC0;
		case OpIDecr: 0xC1;
		case OpINeg: 0xC4;
		case OpIAdd: 0xC5;
		case OpISub: 0xC6;
		case OpIMul: 0xC7;
		case OpMemGet8: 0x35;
		case OpMemGet16: 0x36;
		case OpMemGet32: 0x37;
		case OpMemGetFloat: 0x38;
		case OpMemGetDouble: 0x39;
		case OpMemSet8: 0x3A;
		case OpMemSet16: 0x3B;
		case OpMemSet32: 0x3C;
		case OpMemSetFloat: 0x3D;
		case OpMemSetDouble: 0x3E;
		case OpSign1: 0x50;
		case OpSign8: 0x51;
		case OpSign16: 0x52;
		}
	}

	public function write(op) {
		switch( op ) {
		case OBreakPoint:
			b(0x01);
		case ONop:
			b(0x02);
		case OThrow:
			b(0x03);
		case OGetSuper(v):
			b(0x04);
			idx(v);
		case OSetSuper(v):
			b(0x05);
			idx(v);
		case ODxNs(i):
			b(0x06);
			idx(i);
		case ODxNsLate:
			b(0x07);
		case ORegKill(r):
			b(0x08);
			reg(r);
		case OLabel:
			b(0x09);
		case OJump(j,delta):
			b(jumpCode(j));
			o.writeInt24(delta);
		case OSwitch(def,deltas):
			b(0x1B);
			o.writeInt24(def);
			int(deltas.length - 1);
			for( d in deltas )
				o.writeInt24(d);
		case OPushWith:
			b(0x1C);
		case OPopScope:
			b(0x1D);
		case OForIn:
			b(0x1E);
		case OHasNext:
			b(0x1F);
		case ONull:
			b(0x20);
		case OUndefined:
			b(0x21);
		case OForEach:
			b(0x23);
		case OSmallInt(v):
			b(0x24);
			o.writeInt8(v);
		case OInt(v):
			b(0x25);
			int(v);
		case OTrue:
			b(0x26);
		case OFalse:
			b(0x27);
		case ONaN:
			b(0x28);
		case OPop:
			b(0x29);
		case ODup:
			b(0x2A);
		case OSwap:
			b(0x2B);
		case OString(v):
			b(0x2C);
			idx(v);
		case OIntRef(v):
			b(0x2D);
			idx(v);
		case OUIntRef(v):
			b(0x2E);
			idx(v);
		case OFloat(v):
			b(0x2F);
			idx(v);
		case OScope:
			b(0x30);
		case ONamespace(v):
			b(0x31);
			idx(v);
		case ONext(r1,r2):
			b(0x32);
			int(r1);
			int(r2);
		case OFunction(f):
			b(0x40);
			idx(f);
		case OCallStack(n):
			b(0x41);
			int(n);
		case OConstruct(n):
			b(0x42);
			int(n);
		case OCallMethod(s,n):
			b(0x43);
			int(s);
			int(n);
		case OCallStatic(m,n):
			b(0x44);
			idx(m);
			int(n);
		case OCallSuper(p,n):
			b(0x45);
			idx(p);
			int(n);
		case OCallProperty(p,n):
			b(0x46);
			idx(p);
			int(n);
		case ORetVoid:
			b(0x47);
		case ORet:
			b(0x48);
		case OConstructSuper(n):
			b(0x49);
			int(n);
		case OConstructProperty(p,n):
			b(0x4A);
			idx(p);
			int(n);
		case OCallPropLex(p,n):
			b(0x4C);
			idx(p);
			int(n);
		case OCallSuperVoid(p,n):
			b(0x4E);
			idx(p);
			int(n);
		case OCallPropVoid(p,n):
			b(0x4F);
			idx(p);
			int(n);
		case OApplyType(n):
			b(0x53);
			int(n);
		case OObject(n):
			b(0x55);
			int(n);
		case OArray(n):
			b(0x56);
			int(n);
		case ONewBlock:
			b(0x57);
		case OClassDef(c):
			b(0x58);
			idx(c);
		case OGetDescendants(i):
			b(0x59);
			idx(i);
		case OCatch(c):
			b(0x5A);
			int(c);
		case OFindPropStrict(p):
			b(0x5D);
			idx(p);
		case OFindProp(p):
			b(0x5E);
			idx(p);
		case OFindDefinition(d):
			b(0x5F);
			idx(d);
		case OGetLex(p):
			b(0x60);
			idx(p);
		case OSetProp(p):
			b(0x61);
			idx(p);
		case OReg(r):
			switch( r ) {
			case 0: b(0xD0); // this
			case 1: b(0xD1);
			case 2: b(0xD2);
			case 3: b(0xD3);
			default:
				b(0x62);
				reg(r);
			}
		case OSetReg(r):
			switch( r ) {
			case 0: b(0xD4); // this
			case 1: b(0xD5);
			case 2: b(0xD6);
			case 3: b(0xD7);
			default:
				b(0x63);
				reg(r);
			}
		case OGetGlobalScope:
			b(0x64);
		case OGetScope(n):
			b(0x65);
			b(n);
		case OGetProp(p):
			b(0x66);
			idx(p);
		case OInitProp(p):
			b(0x68);
			idx(p);
		case ODeleteProp(p):
			b(0x6A);
			idx(p);
		case OGetSlot(s):
			b(0x6C);
			int(s);
		case OSetSlot(s):
			b(0x6D);
			int(s);
		case OToString:
			b(0x70);
		case OToXml:
			b(0x71);
		case OToXmlAttr:
			b(0x72);
		case OToInt:
			b(0x73);
		case OToUInt:
			b(0x74);
		case OToNumber:
			b(0x75);
		case OToBool:
			b(0x76);
		case OToObject:
			b(0x77);
		case OCheckIsXml:
			b(0x78);
		case OCast(t):
			b(0x80);
			idx(t);
		case OAsAny:
			b(0x82);
		case OAsString:
			b(0x85);
		case OAsType(t):
			b(0x86);
			idx(t);
		case OAsObject:
			b(0x89);
		case OIncrReg(r):
			b(0x92);
			reg(r);
		case ODecrReg(r):
			b(0x94);
			reg(r);
		case OTypeof:
			b(0x95);
		case OInstanceOf:
			b(0xB1);
		case OIsType(t):
			b(0xB2);
			idx(t);
		case OIncrIReg(r):
			b(0xC2);
			reg(r);
		case ODecrIReg(r):
			b(0xC3);
			reg(r);
		case OThis:
			b(0xD0);
		case OSetThis:
			b(0xD4);
		case ODebugReg(name,r,line):
			b(0xEF);
			b(1);
			idx(name);
			reg(r);
			int(line);
		case ODebugLine(line):
			b(0xF0);
			int(line);
		case ODebugFile(file):
			b(0xF1);
			idx(file);
		case OBreakPointLine(n):
			b(0xF2);
			int(n);
		case OTimestamp:
			b(0xF3);
		case OOp(op):
			b(operationCode(op));
		case OUnknown(byte):
			b(byte);
		}
	}

}