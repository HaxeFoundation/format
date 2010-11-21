/*
 * format - haXe File Formats
 * NekoVM emulator by Nicolas Cannasse
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
package format.neko;

enum Opcode {
	OAccNull;
	OAccTrue;
	OAccFalse;
	OAccThis;
	OAccInt;
	OAccStack;
	OAccGlobal;
	OAccEnv;
	OAccField;
	OAccArray;
	OAccIndex;
	OAccBuiltin;
	OSetStack;
	OSetGlobal;
	OSetEnv;
	OSetField;
	OSetArray;
	OSetIndex;
	OSetThis;
	OPush;
	OPop;
	OCall;
	OObjCall;
	OJump;
	OJumpIf;
	OJumpIfNot;
	OTrap;
	OEndTrap;
	ORet;
	OMakeEnv;
	OMakeArray;
	// value ops
	OBool;
	OIsNull;
	OIsNotNull;
	OAdd;
	OSub;
	OMult;
	ODiv;
	OMod;
	OShl;
	OShr;
	OUShr;
	OOr;
	OAnd;
	OXor;
	OEq;
	ONeq;
	OGt;
	OGte;
	OLt;
	OLte;
	ONot;
	// extra ops
	OTypeOf;
	OCompare;
	OHash;
	ONew;
	OJumpTable;
	OApply;
	OAccStack0;
	OAccStack1;
	OAccIndex0;
	OAccIndex1;
	OPhysCompare;
	OTailCall;
}

typedef DebugInfos = Array<Null<{ file : String, line : Int }>>;

enum Global {
	GlobalVar( v : String );
	GlobalFunction( pos : Int, nargs : Int );
	GlobalString( v : String );
	GlobalFloat( v : String );
	GlobalDebug( debug : DebugInfos );
}

typedef Data = {
	var globals : Array<Global>;
	var fields : Array<String>;
	var code : Array<Int>;
}