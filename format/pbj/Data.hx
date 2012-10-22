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

enum PBJChannel {
	R;
	G;
	B;
	A;
	M2x2;
	M3x3;
	M4x4;
}

enum PBJReg {
	RInt( n : Int, ?s : Array<PBJChannel> );
	RFloat( n : Int, ?s : Array<PBJChannel> );
}

enum PBJType {
	TFloat;
	TFloat2;
	TFloat3;
	TFloat4;
	TFloat2x2;
	TFloat3x3;
	TFloat4x4;
	TInt;
	TInt2;
	TInt3;
	TInt4;
	TString;
}

enum PBJConst {
	PFloat( f : Float );
	PFloat2( f1 : Float, f2 : Float );
	PFloat3( f1 : Float, f2 : Float, f3 : Float );
	PFloat4( f1 : Float, f2 : Float, f3 : Float, f4 : Float );
	PFloat2x2( f : Array<Float> );
	PFloat3x3( f : Array<Float> );
	PFloat4x4( f : Array<Float> );
	PInt( i : Int );
	PInt2( i1 : Int, i2 : Int );
	PInt3( i1 : Int, i2 : Int, i3 : Int );
	PInt4( i1 : Int, i2 : Int, i3 : Int, i4 : Int );
	PString( s : String );
}

private typedef R = PBJReg;

enum PBJOpcode {
	OpNop;
	OpAdd( dst : R, src : R );
	OpSub( dst : R, src : R );
	OpMul( dst : R, src : R );
	OpRcp( dst : R, src : R );
	OpDiv( dst : R, src : R );
	OpAtan2( dst : R, src : R );
	OpPow( dst : R, src : R );
	OpMod( dst : R, src : R );
	OpMin( dst : R, src : R );
	OpMax( dst : R, src : R );
	OpStep( dst : R, src : R );
	OpSin( dst : R, src : R );
	OpCos( dst : R, src : R );
	OpTan( dst : R, src : R );
	OpASin( dst : R, src : R );
	OpACos( dst : R, src : R );
	OpATan( dst : R, src : R );
	OpExp( dst : R, src : R );
	OpExp2( dst : R, src : R );
	OpLog( dst : R, src : R );
	OpLog2( dst : R, src : R );
	OpSqrt( dst : R, src : R );
	OpRSqrt( dst : R, src : R );
	OpAbs( dst : R, src : R );
	OpSign( dst : R, src : R );
	OpFloor( dst : R, src : R );
	OpCeil( dst : R, src : R );
	OpFract( dst : R, src : R );
	OpMov( dst : R, src : R );
	OpFloatToInt( dst : R, src : R );
	OpIntToFloat( dst : R, src : R );
	OpMatrixMatrixMult( dst : R, src : R );
	OpVectorMatrixMult( dst : R, src : R );
	OpMatrixVectorMult( dst : R, src : R );
	OpNormalize( dst : R, src : R );
	OpLength( dst : R, src : R );
	OpDistance( dst : R, src : R );
	OpDotProduct( dst : R, src : R );
	OpCrossProduct( dst : R, src : R );
	OpEqual( dst : R, src : R );
	OpNotEqual( dst : R, src : R );
	OpLessThan( dst : R, src : R );
	OpLessThanEqual( dst : R, src : R );
	OpLogicalNot( dst : R, src : R );
	OpLogicalAnd( dst : R, src : R );
	OpLogicalOr( dst : R, src : R );
	OpLogicalXor( dst : R, src : R );
	OpSampleNearest( dst : R, src : R, srcTexture : Int );
	OpSampleLinear( dst : R, src : R, srcTexture : Int );
	OpLoadInt( dst : R, v : #if haxe3 Int #else haxe.Int32 #end );
	OpLoadFloat( dst : R, v : Float );
	OpIf( cond : R );
	OpElse;
	OpEndIf;
	// boolean operations, not supported by FP10
	OpFloatToBool( dst : R, src : R );
	OpBoolToFloat( dst : R, src : R );
	OpIntToBool( dst : R, src : R );
	OpBoolToInt( dst : R, src : R );
	OpVectorEqual( dst : R, src : R );
	OpVectorNotEqual( dst : R, src : R );
	OpBoolAny( dst : R, src : R );
	OpBoolAll( dst : R, src : R );
}

typedef PBJMeta = {
	var key : String;
	var value : PBJConst;
}

enum PBJParam {
	Parameter( type : PBJType, out : Bool, reg : PBJReg );
	Texture( channels : Int, index : Int );
}

typedef PBJ = {
	var version : Int;
	var name : String;
	var metadatas : Array<PBJMeta>;
	var parameters : Array<{ name : String, metas : Array<PBJMeta>, p : PBJParam }>;
	var code : Array<PBJOpcode>;
}
