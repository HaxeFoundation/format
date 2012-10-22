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

class Reader {

	var i : haxe.io.Input;
	var chans : Array<PBJChannel>;

	public function new( i : haxe.io.Input ) {
		this.i = i;
		chans = [R,G,B,A,M2x2,M3x3,M4x4];
	}

	function getType( t ) {
		return switch( t ) {
		case 0x01: TFloat;
		case 0x02: TFloat2;
		case 0x03: TFloat3;
		case 0x04: TFloat4;
		case 0x05: TFloat2x2;
		case 0x06: TFloat3x3;
		case 0x07: TFloat4x4;
		case 0x08: TInt;
		case 0x09: TInt2;
		case 0x0A: TInt3;
		case 0x0B: TInt4;
		case 0x0C: TString;
		default: throw "Unknown type 0x"+StringTools.hex(t,2);
		}
	}

	function srcReg( src, size ) {
		var sw = src >> 16;
		var m = null;
		// 0x1B = 00 01 10 11
		if( sw != 0x1B ) {
			m = new Array();
			for( i in 0...size )
				m.push(chans[(sw >> (6 - i*2))&3]);
		}
		return reg(src & 0xFFFF,m);
	}

	function dstReg( dst, mask ) {
		var m = null;
		if( mask != 0xF ) {
			m = new Array();
			if( mask & 8 != 0 ) m.push(R);
			if( mask & 4 != 0 ) m.push(G);
			if( mask & 2 != 0 ) m.push(B);
			if( mask & 1 != 0 ) m.push(A);
		}
		return reg(dst,m);
	}

	function mReg( r, matrix ) {
		return reg(r & 0xFFFF,[chans[matrix + 3]]);
	}

	function reg(t,s) {
		if( t & 0x8000 != 0 )
			return RInt(t - 0x8000,s);
		return RFloat(t,s);
	}

	function readFloat() {
		i.bigEndian = true;
		var f = i.readFloat();
		i.bigEndian = false;
		return f;
	}
	
	inline function readInt() {
		#if haxe3
		return i.readInt32();
		#else
		return i.readUInt30();
		#end
	}

	function readValue( t ) {
		return switch( t ) {
		case TFloat:
			PFloat(readFloat());
		case TFloat2:
			PFloat2(readFloat(),readFloat());
		case TFloat3:
			PFloat3(readFloat(),readFloat(),readFloat());
		case TFloat4:
			PFloat4(readFloat(),readFloat(),readFloat(),readFloat());
		case TFloat2x2:
			var a = new Array();
			for( n in 0...4 )
				a.push(readFloat());
			PFloat2x2(a);
		case TFloat3x3:
			var a = new Array();
			for( n in 0...9 )
				a.push(readFloat());
			PFloat3x3(a);
		case TFloat4x4:
			var a = new Array();
			for( n in 0...16 )
				a.push(readFloat());
			PFloat4x4(a);
		case TInt:
			PInt(i.readUInt16());
		case TInt2:
			PInt2(i.readUInt16(),i.readUInt16());
		case TInt3:
			PInt3(i.readUInt16(),i.readUInt16(),i.readUInt16());
		case TInt4:
			PInt4(i.readUInt16(),i.readUInt16(),i.readUInt16(),i.readUInt16());
		case TString:
			PString(i.readUntil(0));
		};
	}

	function assert( v1 : Dynamic, v2 : Dynamic ) {
		if( v1 != v2 ) throw "Assert "+Std.string(v1)+" != "+Std.string(v2);
	}

	function readOp( op ) {
		var dst = i.readUInt16();
		var mask = i.readByte();
		var size = (mask & 3) + 1;
		var matrix = (mask >> 2) & 3;
		var src = i.readUInt24();
		assert( i.readByte(), 0 );
		mask >>= 4;
		if( matrix != 0 ) {
			assert( src >> 16, 0 ); // no swizzle
			assert( size , 1 );
			var dst = if( mask == 0 ) mReg(dst,matrix) else dstReg(dst,mask);
			return op(dst,mReg(src,matrix));
		}
		return op(dstReg(dst,mask),srcReg(src,size));
	}

	public function read() : PBJ {
		var version : Null<Int> = null;
		var name = null;
		var pbjMetas = new Array();
		var metas = pbjMetas;
		var params = new Array();
		var code = new Array();
		var op;
		while( true ) {
			try {
				op = i.readByte();
			} catch( e : Dynamic ) {
				break;
			}
			switch( op ) {
			// opcodes
			case 0x00:
				assert( readInt(), 0 );
				assert( i.readUInt24(), 0 );
				code.push(OpNop);
			case 0x01: code.push(readOp(OpAdd));
			case 0x02: code.push(readOp(OpSub));
			case 0x03: code.push(readOp(OpMul));
			case 0x04: code.push(readOp(OpRcp));
			case 0x05: code.push(readOp(OpDiv));
			case 0x06: code.push(readOp(OpAtan2));
			case 0x07: code.push(readOp(OpPow));
			case 0x08: code.push(readOp(OpMod));
			case 0x09: code.push(readOp(OpMin));
			case 0x0A: code.push(readOp(OpMax));
			case 0x0B: code.push(readOp(OpStep));
			case 0x0C: code.push(readOp(OpSin));
			case 0x0D: code.push(readOp(OpCos));
			case 0x0E: code.push(readOp(OpTan));
			case 0x0F: code.push(readOp(OpASin));
			case 0x10: code.push(readOp(OpACos));
			case 0x11: code.push(readOp(OpATan));
			case 0x12: code.push(readOp(OpExp));
			case 0x13: code.push(readOp(OpExp2));
			case 0x14: code.push(readOp(OpLog));
			case 0x15: code.push(readOp(OpLog2));
			case 0x16: code.push(readOp(OpSqrt));
			case 0x17: code.push(readOp(OpRSqrt));
			case 0x18: code.push(readOp(OpAbs));
			case 0x19: code.push(readOp(OpSign));
			case 0x1A: code.push(readOp(OpFloor));
			case 0x1B: code.push(readOp(OpCeil));
			case 0x1C: code.push(readOp(OpFract));
			case 0x1D: code.push(readOp(OpMov));
			case 0x1E: code.push(readOp(OpFloatToInt));
			case 0x1F: code.push(readOp(OpIntToFloat));
			case 0x20: code.push(readOp(OpMatrixMatrixMult));
			case 0x21: code.push(readOp(OpVectorMatrixMult));
			case 0x22: code.push(readOp(OpMatrixVectorMult));
			case 0x23: code.push(readOp(OpNormalize));
			case 0x24: code.push(readOp(OpLength));
			case 0x25: code.push(readOp(OpDistance));
			case 0x26: code.push(readOp(OpDotProduct));
			case 0x27: code.push(readOp(OpCrossProduct));
			case 0x28: code.push(readOp(OpEqual));
			case 0x29: code.push(readOp(OpNotEqual));
			case 0x2A: code.push(readOp(OpLessThan));
			case 0x2B: code.push(readOp(OpLessThanEqual));
			case 0x2C: code.push(readOp(OpLogicalNot));
			case 0x2D: code.push(readOp(OpLogicalAnd));
			case 0x2E: code.push(readOp(OpLogicalOr));
			case 0x2F: code.push(readOp(OpLogicalXor));
			case 0x30:
				var dst = i.readUInt16();
				var mask = i.readByte();
				var src = i.readUInt24();
				var tf = i.readByte();
				assert( mask & 0xF, 1 );
				code.push(OpSampleNearest(dstReg(dst,mask>>4),srcReg(src,2),tf));
			case 0x31:
				var dst = i.readUInt16();
				var mask = i.readByte();
				var src = i.readUInt24();
				var tf = i.readByte();
				assert( mask & 0xF, 1 );
				code.push(OpSampleLinear(dstReg(dst,mask>>4),srcReg(src,2),tf));
			case 0x32:
				var dst = i.readUInt16();
				var mask = i.readByte();
				assert( mask & 0xF, 0 );
				var dst = dstReg(dst,mask >> 4);
				switch( dst ) {
				case RInt(_,_):
					code.push(OpLoadInt(dst,i.readInt32()));
				case RFloat(_,_):
					code.push(OpLoadFloat(dst,readFloat()));
				}
			case 0x33:
				throw "Loops are not supported";
			case 0x34:
				assert( i.readUInt24(), 0 );
				var src = i.readUInt24();
				assert( i.readByte(), 0 );
				code.push(OpIf(srcReg(src,1)));
			case 0x35:
				assert( readInt(), 0 );
				assert( i.readUInt24(), 0 );
				code.push(OpElse);
			case 0x36:
				assert( readInt(), 0 );
				assert( i.readUInt24(), 0 );
				code.push(OpEndIf);
			case 0x37: code.push(readOp(OpFloatToBool));
			case 0x38: code.push(readOp(OpBoolToFloat));
			case 0x39: code.push(readOp(OpIntToBool));
			case 0x3A: code.push(readOp(OpBoolToInt));
			case 0x3B: code.push(readOp(OpVectorEqual));
			case 0x3C: code.push(readOp(OpVectorNotEqual));
			case 0x3D: code.push(readOp(OpBoolAny));
			case 0x3E: code.push(readOp(OpBoolAll));
			// datas
			case 0xA0, 0xA2:
				var type = i.readByte();
				var key = i.readUntil(0);
				var value = readValue(getType(type));
				metas.push({ key : key, value : value });
			case 0xA1:
				var qualifier = i.readByte();
				var type = getType(i.readByte());
				var reg = i.readUInt16();
				var mask = i.readByte();
				var name = i.readUntil(0);
				switch( type ) {
				case TFloat2x2: assert(mask,2); mask = 0xF;
				case TFloat3x3: assert(mask,3); mask = 0xF;
				case TFloat4x4: assert(mask,4); mask = 0xF;
				default: assert(mask >> 4, 0);
				}
				if( qualifier != 2 ) assert(qualifier,1);
				metas = new Array();
				params.push({ name : name, metas : metas, p : Parameter(type,qualifier == 2,dstReg(reg,mask)) });
			case 0xA3:
				var index = i.readByte();
				var channels = i.readByte();
				var name = i.readUntil(0);
				metas = new Array();
				params.push({ name : name, metas : metas, p : Texture(channels,index) });
			case 0xA4:
				assert( name, null );
				name = i.readString(i.readUInt16());
			case 0xA5:
				assert( version, null );
				version = #if haxe3 i.readInt32() #else i.readInt31() #end;
			default:
				throw "Unknown opcode 0x"+StringTools.hex(op,2);
			}
		}
		return {
			name : name,
			version : version,
			metadatas : pbjMetas,
			parameters : params,
			code : code,
		};
	}

}