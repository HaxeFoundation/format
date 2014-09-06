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

enum Opcode {
	OMov( dst : Reg, v : Reg );
	OAdd( dst : Reg, a : Reg, b : Reg );
	OSub( dst : Reg, a : Reg, b : Reg );
	OMul( dst : Reg, a : Reg, b : Reg );
	ODiv( dst : Reg, a : Reg, b : Reg );
	ORcp( dst : Reg, v : Reg );
	OMin( dst : Reg, a : Reg, b : Reg );
	OMax( dst : Reg, a : Reg, b : Reg );
	OFrc( dst : Reg, v : Reg );
	OSqt( dst : Reg, v : Reg );
	ORsq( dst : Reg, v : Reg );
	OPow( dst : Reg, a : Reg, b : Reg );
	OLog( dst : Reg, v : Reg );
	OExp( dst : Reg, v : Reg );
	ONrm( dst : Reg, v : Reg );
	OSin( dst : Reg, v : Reg );
	OCos( dst : Reg, v : Reg );
	OCrs( dst : Reg, a : Reg, b : Reg );
	ODp3( dst : Reg, a : Reg, b : Reg );
	ODp4( dst : Reg, a : Reg, b : Reg );
	OAbs( dst : Reg, v : Reg );
	ONeg( dst : Reg, v : Reg );
	OSat( dst : Reg, v : Reg );
	OM33( dst : Reg, a : Reg, b : Reg );
	OM44( dst : Reg, a : Reg, b : Reg );
	OM34( dst : Reg, a : Reg, b : Reg );
	// agal 2
	ODdx( dst : Reg, v : Reg );
	ODdy( dst : Reg, v : Reg );
	OIfe( a : Reg, b : Reg );
	OIne( a : Reg, b : Reg );
	OIfg( a : Reg, b : Reg );
	OIfl( a : Reg, b : Reg );
	OEls;
	OEif;
	// --
	OUnused;
	OKil( v : Reg );
	OTex( dst : Reg, pt : Reg, tex : Tex );
	OSge( dst : Reg, a : Reg, b : Reg );
	OSlt( dst : Reg, a : Reg, b : Reg );
	OSgn( dst : Reg, v : Reg );
	OSeq( dst : Reg, a : Reg, b : Reg );
	OSne( dst : Reg, a : Reg, b : Reg );
}

typedef Reg = {
	var t : RegType;
	var index : Int;
	var swiz : Swizzle;
	var access : Null<{ t : RegType, comp : C, offset : Int }>;
}

typedef Swizzle = Null<Array<C>>; // length 1-4

enum C {
	X;
	Y;
	Z;
	W;
}

enum RegType {
	RAttr;
	RConst;
	RTemp;
	ROut;
	RVar;
	RTexture;
	RDepth;
}

typedef Tex = {
	var index : Int;
	var flags : Null<Array<TexFlag>>;
}

enum TexFlag {
	T2D; // default
	TCube;
	T3D;
	TMipMapDisable; // default
	TMipMapNearest;
	TMipMapLinear;
	TWrap;
	TClamp;	// default
	TClampURepeatV;
	TRepeatUClampV;
	TFilterNearest;
	TFilterLinear; // default
	TFilterAnisotropic2x;
	TFilterAnisotropic4x;
	TFilterAnisotropic8x;
	TFilterAnisotropic16x;
	TRgba; // default
	TDxt1;
	TDxt5;
	TVideo;
	TCentroid; // default;
	TSingle; 		  // Float texture?
	TIgnoreSampler;   // see Context3D.setSamplerStateAt
	TLodBias( v : Float );
}

typedef Data = {
	@:optional var version : Int;
	var code : Array<Opcode>;
	var fragmentShader : Bool;
}
