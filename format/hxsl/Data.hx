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
package format.hxsl;

typedef Position = haxe.macro.Expr.Position;

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

enum Comp {
	X;
	Y;
	Z;
	W;
}

enum VarKind {
	VParam;
	VVar;
	VInput;
	VOut;
	VTmp;
	VTexture;
}

enum VarType {
	TFloat;
	TFloat2;
	TFloat3;
	TFloat4;
	TMatrix( w : Int, h : Int, transpose : { t : Null<Bool> } );
	TTexture;
}

typedef Variable = {
	var name : String;
	var type : VarType;
	var kind : VarKind;
	var index : Int;
	var read : Bool;
	var write : Int;
	var pos : Position;
}

enum CodeOp {
	CAdd;
	CSub;
	CMul;
	CDiv;
	CMin;
	CMax;
	CPow;
	CCross;
	CDot;
	CLt;
	CGte;
}

enum CodeUnop {
	CRcp;
	CSqrt;
	CRsq;
	CLog;
	CExp;
	CLen;
	CSin;
	CCos;
	CAbs;
	CNeg;
	CSat;
	CFrac;
	CInt;
	CNorm;
	CKill;
	CTrans;
}

// final hxsl

enum CodeValueDecl {
	CVar( v : Variable, ?swiz : Array<Comp> );
	COp( op : CodeOp, e1 : CodeValue, e2 : CodeValue );
	CUnop( op : CodeUnop, e : CodeValue );
	CTex( v : Variable, acc : CodeValue, flags : Array<TexFlag> );
	CSwiz( e : CodeValue, swiz : Array<Comp> );
}

typedef CodeValue = {
	var d : CodeValueDecl;
	var t : VarType;
	var p : Position;
}

typedef Code = {
	var vertex : Bool;
	var pos : Position;
	var args : Array<Variable>;
	var consts : Array<Array<String>>;
	var tex : Array<Variable>;
	var exprs : Array<{ v : Null<CodeValue>, e : CodeValue }>;
	var tempSize : Int;
}

// parsed hxsl

enum ParsedValueDecl {
	PVar( v : String );
	PConst( v : String );
	PLocal( v : ParsedVar );
	POp( op : CodeOp, e1 : ParsedValue, e2 : ParsedValue );
	PUnop( op : CodeUnop, e : ParsedValue );
	PTex( v : String, acc : ParsedValue, flags : Array<TexFlag> );
	PSwiz( e : ParsedValue, swiz : Array<Comp> );
	PIf( cond : ParsedValue, e1 : ParsedValue, e2 : ParsedValue );
	PVector( el : Array<ParsedValue> );
}

typedef ParsedValue = {
	var v : ParsedValueDecl;
	var p : Position;
}

typedef ParsedVar = {
	var n : String;
	var t : VarType;
	var p : Position;
}

typedef ParsedCode = {
	var vertex : Bool;
	var pos : Position;
	var args : Array<ParsedVar>;
	var exprs : Array<{ v : Null<ParsedValue>, e : ParsedValue, p : Position }>;
}

typedef ParsedHxsl = {
	var pos : Position;
	var input : Array<ParsedVar>;
	var vars : Array<ParsedVar>;
	var vertex : ParsedCode;
	var fragment : ParsedCode;
}

class Error {
	public var message : String;
	public var pos : Position;
	public function new(msg, p) {
		this.message = msg;
		this.pos = p;
	}
}

class Tools {
	
	public static function regSize( t : VarType ) {
		return switch( t ) {
		case TMatrix(w,h,t): t.t ? h : w;
		default: 1;
		}
	}
	
	
	public static function floatSize( t : VarType ) {
		return switch( t ) {
		case TFloat: 1;
		case TFloat2: 2;
		case TFloat3: 3;
		case TFloat4: 4;
		case TTexture: 0;
		case TMatrix(w,h,_): w*h;
		}
	}

	public static function makeFloat( i : Int ) {
		return switch( i ) {
			case 1: TFloat;
			case 2: TFloat2;
			case 3: TFloat3;
			case 4: TFloat4;
			default: throw "assert";
		};
	}
	
}