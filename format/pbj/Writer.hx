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
package format.pbj;
import format.pbj.Data;

class Writer {

	var o : haxe.io.Output;

	public function new( o : haxe.io.Output ) {
		this.o = o;
	}

	function getTypeCode(t) {
		return switch(t) {
		case TFloat: 0x01;
		case TFloat2: 0x02;
		case TFloat3: 0x03;
		case TFloat4: 0x04;
		case TFloat2x2: 0x05;
		case TFloat3x3: 0x06;
		case TFloat4x4: 0x07;
		case TInt: 0x08;
		case TInt2: 0x09;
		case TInt3: 0x0A;
		case TInt4: 0x0B;
		case TString: 0x0C;
		};
	}

	function regCode(r) {
		return switch(r) {
		case RFloat(n,_): n;
		case RInt(n,_): n + 0x8000;
		}
	}

	function getMatrixBits(t) {
		return switch(t) {
		case TFloat2x2: 1;
		case TFloat3x3: 2;
		case TFloat4x4: 3;
		default: 0;
		};
	}

	function getSizeBits(t) {
		return switch(t) {
		case TFloat,TInt: 0;
		case TFloat2,TInt2: 1;
		case TFloat3,TInt3: 2;
		case TFloat4,TInt4: 3;
		default: 0;
		};
	}


	function assert( v1 : Dynamic, v2 : Dynamic ) {
		if( v1 != v2 ) throw "Assert "+Std.string(v1)+" != "+Std.string(v2);
	}

	function writeFloat(v) {
		o.bigEndian = true;
		o.writeFloat(v);
		o.bigEndian = false;
	}

	function writeValue( v ) {
		switch( v ) {
		case PFloat(f):
			writeFloat(f);
		case PFloat2(f1,f2):
			writeFloat(f1);
			writeFloat(f2);
		case PFloat3(f1,f2,f3):
			writeFloat(f1);
			writeFloat(f2);
			writeFloat(f3);
		case PFloat4(f1,f2,f3,f4):
			writeFloat(f1);
			writeFloat(f2);
			writeFloat(f3);
			writeFloat(f4);
		case PFloat2x2(a):
			assert( a.length, 4 );
			for( f in a )
				writeFloat(f);
		case PFloat3x3(a):
			assert( a.length, 9 );
			for( f in a )
				writeFloat(f);
		case PFloat4x4(a):
			assert( a.length, 16 );
			for( f in a )
				writeFloat(f);
		case PInt(i):
			o.writeUInt16(i);
		case PInt2(i1,i2):
			o.writeUInt16(i1);
			o.writeUInt16(i2);
		case PInt3(i1,i2,i3):
			o.writeUInt16(i1);
			o.writeUInt16(i2);
			o.writeUInt16(i3);
		case PInt4(i1,i2,i3,i4):
			o.writeUInt16(i1);
			o.writeUInt16(i2);
			o.writeUInt16(i3);
			o.writeUInt16(i4);
		case PString(s):
			o.writeString(s);
			o.writeByte(0);
		}
	}

	function writeMeta( m : PBJMeta ) {
		var t = Tools.getValueType(m.value);
		o.writeByte(getTypeCode(t));
		o.writeString(m.key);
		o.writeByte(0);
		writeValue(m.value);
	}

	function destMask( e : Array<PBJChannel> ) {
		if( e == null ) return 0xF;
		var mask = 0;
		for( c in e )
			switch( c ) {
			case R:
				if( mask != 0 ) throw "Can't swizzle dest reg";
				mask |= 8;
			case G:
				if( mask & 7 != 0 ) throw "Can't swizzle dest reg";
				mask |= 4;
			case B:
				if( mask & 3 != 0 ) throw "Can't swizzle dest reg";
				mask |= 2;
			case A:
				if( mask & 1 != 0 ) throw "Can't swizzle dest reg";
				mask |= 1;
			case M4x4, M3x3, M2x2:
				return 0;
			}
		return mask;
	}

	function srcSwizzle( e : Array<PBJChannel>, size ) {
		// 0x1B = 00 01 10 11
		if( e == null ) return 0x1B;
		var mask = 0;
		for( c in e ) {
			mask <<= 2;
			switch( c ) {
			case R:
			case G: mask |= 1;
			case B: mask |= 2;
			case A: mask |= 3;
			case M4x4,M3x3,M2x2: return 0; // no swizzle
			}
		}
		return mask << ((4 - size) * 2);
	}

	function writeDest(dst,size) {
		var mask = destMask(switch(dst) { case RInt(_,e), RFloat(_,e): e; });
		o.writeUInt16(regCode(dst));
		o.writeByte(mask << 4 | size);
	}

	function writeSrc(src,size) {
		o.writeUInt16(regCode(src));
		o.writeByte(srcSwizzle(switch(src) { case RInt(_,e), RFloat(_,e): e; },size));
	}

	function writeOp(code,dst,src) {
		o.writeByte(code);
		o.writeUInt16(regCode(dst));
		var dste = switch(dst) { case RInt(_,e), RFloat(_,e): e; };
		var srce = switch(src) { case RInt(_,e), RFloat(_,e): e; };
		var maskBits = destMask(dste);
		var sizeBits = ((srce == null) ? 4 : srce.length) - 1;
		if( srce != null && srce.length == 1 )
			switch( srce[0] ) {
			case M2x2: sizeBits = 4;
			case M3x3: sizeBits = 8;
			case M4x4: sizeBits = 12;
			default:
			}
		o.writeByte(maskBits << 4 | sizeBits);
		o.writeUInt16(regCode(src));
		o.writeByte(srcSwizzle(srce,if( srce == null ) 4 else srce.length));
		o.writeByte(0);
	}

	function writeCode( c ) {
		switch( c ) {
		case OpNop:
			o.writeByte(0x00);
			writeInt(0);
			o.writeUInt24(0);
		case OpAdd(d,s): writeOp(0x01,d,s);
		case OpSub(d,s): writeOp(0x02,d,s);
		case OpMul(d,s): writeOp(0x03,d,s);
		case OpRcp(d,s): writeOp(0x04,d,s);
		case OpDiv(d,s): writeOp(0x05,d,s);
		case OpAtan2(d,s): writeOp(0x06,d,s);
		case OpPow(d,s): writeOp(0x07,d,s);
		case OpMod(d,s): writeOp(0x08,d,s);
		case OpMin(d,s): writeOp(0x09,d,s);
		case OpMax(d,s): writeOp(0x0A,d,s);
		case OpStep(d,s): writeOp(0x0B,d,s);
		case OpSin(d,s): writeOp(0x0C,d,s);
		case OpCos(d,s): writeOp(0x0D,d,s);
		case OpTan(d,s): writeOp(0x0E,d,s);
		case OpASin(d,s): writeOp(0x0F,d,s);
		case OpACos(d,s): writeOp(0x10,d,s);
		case OpATan(d,s): writeOp(0x11,d,s);
		case OpExp(d,s): writeOp(0x12,d,s);
		case OpExp2(d,s): writeOp(0x13,d,s);
		case OpLog(d,s): writeOp(0x14,d,s);
		case OpLog2(d,s): writeOp(0x15,d,s);
		case OpSqrt(d,s): writeOp(0x16,d,s);
		case OpRSqrt(d,s): writeOp(0x17,d,s);
		case OpAbs(d,s): writeOp(0x18,d,s);
		case OpSign(d,s): writeOp(0x19,d,s);
		case OpFloor(d,s): writeOp(0x1A,d,s);
		case OpCeil(d,s): writeOp(0x1B,d,s);
		case OpFract(d,s): writeOp(0x1C,d,s);
		case OpMov(d,s): writeOp(0x1D,d,s);
		case OpFloatToInt(d,s): writeOp(0x1E,d,s);
		case OpIntToFloat(d,s): writeOp(0x1F,d,s);
		case OpMatrixMatrixMult(d,s): writeOp(0x20,d,s);
		case OpVectorMatrixMult(d,s): writeOp(0x21,d,s);
		case OpMatrixVectorMult(d,s): writeOp(0x22,d,s);
		case OpNormalize(d,s): writeOp(0x23,d,s);
		case OpLength(d,s): writeOp(0x24,d,s);
		case OpDistance(d,s): writeOp(0x25,d,s);
		case OpDotProduct(d,s): writeOp(0x26,d,s);
		case OpCrossProduct(d,s): writeOp(0x27,d,s);
		case OpEqual(d,s): writeOp(0x28,d,s);
		case OpNotEqual(d,s): writeOp(0x29,d,s);
		case OpLessThan(d,s): writeOp(0x2A,d,s);
		case OpLessThanEqual(d,s): writeOp(0x2B,d,s);
		case OpLogicalNot(d,s): writeOp(0x2C,d,s);
		case OpLogicalAnd(d,s): writeOp(0x2D,d,s);
		case OpLogicalOr(d,s): writeOp(0x2E,d,s);
		case OpLogicalXor(d,s): writeOp(0x2F,d,s);
		case OpSampleNearest(d,s,tex):
			o.writeByte(0x30);
			writeDest(d,1);
			writeSrc(s,2);
			o.writeByte(tex);
		case OpSampleLinear(d,s,tex):
			o.writeByte(0x31);
			writeDest(d,1);
			writeSrc(s,2);
			o.writeByte(tex);
		case OpLoadInt(reg,v):
			o.writeByte(0x32);
			writeDest(reg,0);
			o.writeInt32(v);
		case OpLoadFloat(reg,v):
			o.writeByte(0x32);
			writeDest(reg,0);
			o.bigEndian = true;
			o.writeFloat(v);
			o.bigEndian = false;
		case OpIf(reg):
			o.writeByte(0x34);
			o.writeUInt24(0);
			writeSrc(reg,1);
			o.writeByte(0);
		case OpElse:
			o.writeByte(0x35);
			writeInt(0);
			o.writeUInt24(0);
		case OpEndIf:
			o.writeByte(0x36);
			writeInt(0);
			o.writeUInt24(0);
		case OpFloatToBool(d,s): writeOp(0x37,d,s);
		case OpBoolToFloat(d,s): writeOp(0x38,d,s);
		case OpIntToBool(d,s): writeOp(0x39,d,s);
		case OpBoolToInt(d,s): writeOp(0x3A,d,s);
		case OpVectorEqual(d,s): writeOp(0x3B,d,s);
		case OpVectorNotEqual(d,s): writeOp(0x3C,d,s);
		case OpBoolAny(d,s): writeOp(0x3D,d,s);
		case OpBoolAll(d,s): writeOp(0x3E,d,s);
		}
	}

	inline function writeInt(v : Int) {
		#if haxe3
		o.writeInt32(v);
		#else
		o.writeUInt30(v);
		#end
	}

	public function write( p : PBJ ) {
		o.writeByte(0xA5);
		writeInt(p.version);
		o.writeByte(0xA4);
		o.writeUInt16(p.name.length);
		o.writeString(p.name);
		for( m in p.metadatas ) {
			o.writeByte(0xA0);
			writeMeta(m);
		}
		for( p in p.parameters ) {
			switch( p.p ) {
			case Parameter(type,out,reg):
				o.writeByte(0xA1);
				o.writeByte(out ? 2 : 1);
				o.writeByte(getTypeCode(type));
				o.writeUInt16(regCode(reg));
				var e = switch( reg ) { case RInt(_,e),RFloat(_,e): e; };
				switch( type ) {
				case TFloat2x2: assert(e,null); o.writeByte(2);
				case TFloat3x3: assert(e,null); o.writeByte(3);
				case TFloat4x4: assert(e,null); o.writeByte(4);
				default: o.writeByte(destMask(e));
				}
			case Texture(channels,index):
				o.writeByte(0xA3);
				o.writeByte(index);
				o.writeByte(channels);
			}
			o.writeString(p.name);
			o.writeByte(0);
			for( m in p.metas ) {
				o.writeByte(0xA2);
				writeMeta(m);
			}
		}
		for( c in p.code )
			writeCode(c);
	}

}