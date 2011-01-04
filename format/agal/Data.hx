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
	OMov( dst : Dest, v : Src );
	OAdd( dst : Dest, a : Src, b : Src );
	OSub( dst : Dest, a : Src, b : Src );
	OMul( dst : Dest, a : Src, b : Src );
	ODiv( dst : Dest, a : Src, b : Src );
	ORcp( dst : Dest, v : Src );
	OMin( dst : Dest, a : Src, b : Src );
	OMax( dst : Dest, a : Src, b : Src );
	OFrc( dst : Dest, v : Src );
	OSqt( dst : Dest, v : Src );
	ORsq( dst : Dest, v : Src );
	OPow( dst : Dest, a : Src, b : Src );
	OLog( dst : Dest, v : Src );
	OExp( dst : Dest, v : Src );
	ONrm( dst : Dest, v : Src );
	OSin( dst : Dest, v : Src );
	OCos( dst : Dest, v : Src );
	OCrs( dst : Dest, a : Src, b : Src );
	ODp3( dst : Dest, a : Src, b : Src );
	ODp4( dst : Dest, a : Src, b : Src );
	OAbs( dst : Dest, v : Src );
	ONeg( dst : Dest, v : Src );
	OSat( dst : Dest, v : Src );
	OM33( dst : Dest, a : Src, b : Src );
	OM44( dst : Dest, a : Src, b : Src );
	OM34( dst : Dest, a : Src, b : Src );
	OTex( dst : Dest, pt : Src, tex : Tex );
}

typedef Dest = {
	var t : RegType;
	var index : Int;
	var mask : WriteMask;
}

typedef WriteMask = Null<Array<C>>; // length 1-4

typedef Src = {
	var t : RegType;
	var index : Int;
	var swiz : Swizzle;
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
	TCentroidSample;
	TWrap;
	TClamp;	// default
	TFilterNearest;
	TFilterLinear; // default
}

typedef Data = {
	var code : Array<Opcode>;
	var fragmentShader : Bool;
}
