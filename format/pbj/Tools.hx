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

class Tools {

	static function ext( e : Array<PBJChannel> ) {
		if( e == null )
			return "";
		var str = ".";
		for( c in e )
			switch(c) {
			case R: str += "r";
			case G: str += "g";
			case B: str += "b";
			case A: str += "a";
			case M2x2: str += "2x2";
			case M3x3: str += "3x3";
			case M4x4: str += "4x4";
			}
		return str;
	}

	public static function dumpReg(r) {
		return switch(r) {
		case RInt(n,e): "i"+n+ext(e);
		case RFloat(n,e): "f"+n+ext(e);
		}
	}

	static function call( p : String, vl : Array<Dynamic> ) {
		return p + "("+ vl.join(",") + ")";
	}

	public static function dumpValue(v) {
		return switch(v) {
		case PFloat(f): Std.string(f);
		case PFloat2(f1,f2): call("float2",[f1,f2]);
		case PFloat3(f1,f2,f3): call("float3",[f1,f2,f3]);
		case PFloat4(f1,f2,f3,f4): call("float4",[f1,f2,f3,f4]);
		case PFloat2x2(f): call("float2x2",f);
		case PFloat3x3(f): call("float4x4",f);
		case PFloat4x4(f): call("float4x4",f);
		case PInt(i): Std.string(i);
		case PInt2(i1,i2): call("int2",[i1,i2]);
		case PInt3(i1,i2,i3): call("int3",[i1,i2,i3]);
		case PInt4(i1,i2,i3,i4): call("int4",[i1,i2,i3,i4]);
		case PString(s): "'"+s+"'";
		}
	}

	public static function getValueType(v) {
		return switch( v ) {
		case PFloat(_): TFloat;
		case PFloat2(_,_): TFloat2;
		case PFloat3(_,_,_): TFloat3;
		case PFloat4(_,_,_,_): TFloat4;
		case PFloat2x2(_): TFloat2x2;
		case PFloat3x3(_): TFloat3x3;
		case PFloat4x4(_): TFloat4x4;
		case PInt(_): TInt;
		case PInt2(_,_): TInt2;
		case PInt3(_,_,_): TInt3;
		case PInt4(_,_,_,_): TInt4;
		case PString(_): TString;
		}
	}

	public static function getMatrixMaskBits(n) {
		return switch( n ) {
		case 1: 196;
		case 2: 232;
		case 3: 252;
		default: -1;
		}
	}

	public static function dumpType(t) {
		return Type.enumConstructor(t).substr(1).toLowerCase();
	}

	public static function dumpOpCode(c) {
		return switch( c ) {
		case OpNop: "nop";
		case OpSampleNearest(dst,src,tex): "sampleNearest " + dumpReg(dst) + ", text" + tex + "[" + dumpReg(src) + "]";
		case OpSampleLinear(dst,src,tex): "sampleLinear " + dumpReg(dst) + ", text" + tex + "[" + dumpReg(src) + "]";
		case OpLoadInt(dst,v): "loadint " + dumpReg(dst)+ ", " + v;
		case OpLoadFloat(dst,v): "loadfloat " + dumpReg(dst)+ ", " + v;
		case OpIf(r): "if "+dumpReg(r);
		case OpElse: "else";
		case OpEndIf: "endif";
		default:
			var op = Type.enumConstructor(c).substr(2).toLowerCase();
			var regs = Type.enumParameters(c);
			op+" "+dumpReg(regs[0])+", "+dumpReg(regs[1]);
		}
	}

	public static function dump( p : PBJ ) {
		var buf = new StringBuf();
		buf.add("version : "+p.version+"\n");
		buf.add("name : '"+p.name+"'"+"\n");
		for( m in p.metadatas )
			buf.add("  meta "+m.key+" : "+dumpValue(m.value)+"\n");
		for( p in p.parameters ) {
			switch( p.p ) {
			case Parameter(type,out,reg):
				buf.add("  param "+(out?"out":"in ")+" "+dumpReg(reg)+" "+dumpType(type)+"\t"+p.name+"\n");
			case Texture(channels,index):
				buf.add("  text"+index+" "+channels+"-channels"+"\t"+p.name+"\n");
			}
			for( m in p.metas )
				buf.add("    meta "+m.key+" : "+dumpValue(m.value)+"\n");
		}
		buf.add("code :\n");
		for( o in p.code )
			buf.add("  "+dumpOpCode(o)+"\n");
		return buf.toString();
	}


}