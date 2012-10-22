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
package format.as1;

enum Action {
	AEnd;
	ANextFrame;
	APrevFrame;
	APlay;
	AStop;
	AToggleHighQuality;
	AStopSounds;
	AAddNum;
	ASubtract;
	AMultiply;
	ADivide;
	ACompareNum;
	AEqualNum;
	ALogicalAnd;
	ALogicalOr;
	ANot;
	AStringEqual;
	AStringLength;
	ASubString;
	APop;
	AToInt;
	AEval;
	ASet;
	ATellTarget;
	AStringAdd;
	AGetProperty;
	ASetProperty;
	ADuplicateMC;
	ARemoveMC;
	ATrace;
	AStartDrag;
	AStopDrag;
	AThrow;
	ACast;
	AImplements;
	AFSCommand2;
	ARandom;
	AMBStringLength;
	AOrd;
	AChr;
	AGetTimer;
	AMBStringSub;
	AMBOrd;
	AMBChr;
	ADeleteObj;
	ADelete;
	ALocalAssign;
	ACall;
	AReturn;
	AMod;
	ANew;
	ALocalVar;
	AInitArray;
	AObject;
	ATypeOf;
	ATargetPath;
	AEnum;
	AAdd;
	ACompare;
	AEqual;
	AToNumber;
	AToString;
	ADup;
	ASwap;
	AObjGet;
	AObjSet;
	AIncrement;
	ADecrement;
	AObjCall;
	ANewMethod;
	AInstanceOf;
	AEnum2;
	AAnd;
	AOr;
	AXor;
	AShl;
	AShr;
	AAsr;
	APhysEqual;
	AGreater;
	AStringGreater;
	AExtends;
	AGotoFrame( f : Int );
	AGetURL( url : String, target : String );
	ASetReg( reg : Int );
	AStringPool( strings : Array<String> );
	AWaitForFrame( frame : Int, skip : Int );
	ASetTarget( target : String );
	AGotoLabel( frame : String );
	AWaitForFrame2( frame : Int );
	AFunction2( infos : Function2Infos );
	ATry( infos : TryInfos );
	AWith( value : Int );
	APush( items : Array<PushItem> );
	AJump( delta : Int );
	AGetURL2( v : Int );
	AFunction( infos : FunctionInfos );
	ACondJump( delta : Int );
	ACallFrame; // no data
	AGotoFrame2( play : Bool, delta : Null<Int> );
	AUnknown( id : Int, data : haxe.io.Bytes );
}

enum PushItem {
	PString( s : String );
	PFloat( f : Float );
	PNull;
	PUndefined;
	PReg( r : Int );
	PBool( b : Bool );
	PDouble( f : Float );
	PInt( i : #if haxe3 Int #else haxe.Int32 #end );
	PStack( p : Int );
	PStack2( p : Int );
}

typedef FunctionInfos = {
	var name : String;
	var args : Array<String>;
	var codeLength : Int;
}

typedef Function2Infos = {
	var name : String;
	var args : Array<{ name : String, reg : Int }>;
	var flags : Int;
	var codeLength : Int;
	var nRegisters : Int;
}

enum TryStyle {
	TryVariable( s : String );
	TryRegister( r : Int );
}

typedef TryInfos = {
	var style : TryStyle;
	var tryLength : Int;
	var catchLength : Null<Int>;
	var finallyLength : Null<Int>;
}

typedef AS1 = Array<Action>;