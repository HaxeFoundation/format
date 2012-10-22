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

enum Index<T> {
	Idx( v : Int );
}

enum Namespace {
	NPrivate( ns : Index<String> );
	NNamespace( ns : Index<String> );
	NPublic( ns : Index<String> );
	NInternal( ns : Index<String> );
	NProtected( ns : Index<String> );
	NExplicit( ns : Index<String> );
	NStaticProtected( ns : Index<String> );
}

typedef NamespaceSet = Array<Index<Namespace>>

enum Name {
	NName( name : Index<String>, ns : Index<Namespace> );
	NMulti( name : Index<String>, ns : Index<NamespaceSet> );
	NRuntime( name : Index<String> );
	NRuntimeLate;
	NMultiLate( nset : Index<NamespaceSet> );
	NAttrib( n : Name );
	NParams( n : IName, params : Array<IName> );
}

typedef MethodType = {
	var args : Array<Null<IName>>;
	var ret : Null<IName>;
	var extra : Null<MethodTypeExtra>;
}

typedef MethodTypeExtra = {
	var native : Bool;
	var variableArgs : Bool;
	var argumentsDefined : Bool;
	var usesDXNS : Bool;
	var newBlock : Bool;
	var unused : Bool;
	var debugName : Null<Index<String>>;
	var defaultParameters : Null<Array<Value>>;
	var paramNames : Null<Array<Null<Index<String>>>>;
}

enum Value {
	VNull;
	VBool( b : Bool );
	VString( i : Index<String> );
	VInt( i : Index<#if haxe3 Int #else haxe.Int32 #end> );
	VUInt( i : Index<#if haxe3 Int #else haxe.Int32 #end> );
	VFloat( f : Index<Float> );
	VNamespace( kind : Int, ns : Index<Namespace> );
}

typedef TryCatch = {
	var start : Int;
	var end : Int;
	var handle : Int;
	var type : Null<IName>;
	var variable : Null<IName>;
}

typedef Function = {
	var type : Index<MethodType>;
	var maxStack : Int;
	var nRegs : Int;
	var initScope : Int;
	var maxScope : Int;
	var code : haxe.io.Bytes;
	var trys : Array<TryCatch>;
	var locals : Array<Field>;
}

typedef Field = {
	var name : IName;
	var slot : Slot;
	var kind : FieldKind;
	var metadatas : Null<Array<Index<Metadata>>>;
}

enum MethodKind {
	KNormal;
	KGetter;
	KSetter;
}

enum FieldKind {
	FVar( ?type : Null<IName>, ?value : Value, ?const : Bool );
	FMethod( type : Index<MethodType>, k : MethodKind, ?isFinal : Bool, ?isOverride : Bool );
	FClass( c : Index<ClassDef> );
	FFunction( f : Index<MethodType> );
}

typedef ClassDef = {
	var name : IName;
	var superclass : Null<IName>;
	var interfaces : Array<IName>;
	var constructor : Index<MethodType>;
	var fields : Array<Field>;
	var namespace : Null<Index<Namespace>>;
	var isSealed : Bool;
	var isFinal : Bool;
	var isInterface : Bool;
	var statics : Index<MethodType>;
	var staticFields : Array<Field>;
}

typedef Metadata = {
	var name : Index<String>;
	var data : Array<{ n : Null<Index<String>>, v : Index<String> }>;
}

typedef Init = {
	var method : Index<MethodType>;
	var fields : Array<Field>;
}

class ABCData {
	public var ints : Array<#if haxe3 Int #else haxe.Int32 #end>;
	public var uints : Array<#if haxe3 Int #else haxe.Int32 #end>;
	public var floats : Array<Float>;
	public var strings : Array<String>;
	public var namespaces : Array<Namespace>;
	public var nssets : Array<NamespaceSet>;
	public var names : Array<Name>;
	public var methodTypes : Array<MethodType>;
	public var metadatas : Array<Metadata>;
	public var classes : Array<ClassDef>;
	public var inits : Array<Init>;
	public var functions : Array<Function>;

	public function get<T>( t : Array<T>, i : Index<T> ) : T {
		return switch( i ) { case Idx(n): t[n-1]; };
	}

	public function new() {
	}
}

typedef IName = Index<Name>
typedef Slot = Int
typedef Register = Int

enum OpCode {
	OBreakPoint;
	ONop;
	OThrow;
	OGetSuper( v : IName );
	OSetSuper( v : IName );
	ODxNs( v : Index<String> );
	ODxNsLate;
	ORegKill( r : Register );
	OLabel;
	OJump( j : JumpStyle, delta : Int );
	OSwitch( def : Int, deltas : Array<Int> );
	OPushWith;
	OPopScope;
	OForIn;
	OHasNext;
	ONull;
	OUndefined;
	OForEach;
	OSmallInt( v : Int );
	OInt( v : Int );
	OTrue;
	OFalse;
	ONaN;
	OPop;
	ODup;
	OSwap;
	OString( v : Index<String> );
	OIntRef( v : Index<#if haxe3 Int #else haxe.Int32 #end> );
	OUIntRef( v : Index<#if haxe3 Int #else haxe.Int32 #end> );
	OFloat( v : Index<Float> );
	OScope;
	ONamespace( v : Index<Namespace> );
	ONext( r1 : Register, r2 : Register );
	OFunction( f : Index<MethodType> );
	OCallStack( nargs : Int );
	OConstruct( nargs : Int );
	OCallMethod( slot : Slot, nargs : Int );
	OCallStatic( meth : Index<MethodType>, nargs : Int );
	OCallSuper( name : IName, nargs : Int );
	OCallProperty( name : IName, nargs : Int );
	ORetVoid;
	ORet;
	OConstructSuper( nargs : Int );
	OConstructProperty( name : IName, nargs : Int );
	OCallPropLex( name : IName, nargs : Int );
	OCallSuperVoid( name : IName, nargs : Int );
	OCallPropVoid( name : IName, nargs : Int );
	OApplyType( nargs : Int );
	OObject( nfields : Int );
	OArray( nvalues : Int );
	ONewBlock;
	OClassDef( c : Index<ClassDef> );
	OGetDescendants( c : IName );
	OCatch( c : Int );
	OFindPropStrict( p : IName );
	OFindProp( p : IName );
	OFindDefinition( d : IName );
	OGetLex( p : IName );
	OSetProp( p : IName );
	OReg( r : Register );
	OSetReg( r : Register );
	OGetGlobalScope;
	OGetScope( n : Int );
	OGetProp( p : IName );
	OInitProp( p : IName );
	ODeleteProp( p : IName );
	OGetSlot( s : Slot );
	OSetSlot( s : Slot );
	OToString;
	OToXml;
	OToXmlAttr;
	OToInt;
	OToUInt;
	OToNumber;
	OToBool;
	OToObject;
	OCheckIsXml;
	OCast( t : IName );
	OAsAny;
	OAsString;
	OAsType( t : IName );
	OAsObject;
	OIncrReg( r : Register );
	ODecrReg( r : Register );
	OTypeof;
	OInstanceOf;
	OIsType( t : IName );
	OIncrIReg( r : Register );
	ODecrIReg( r : Register );
	OThis;
	OSetThis;
	ODebugReg( name : Index<String>, r : Register, line : Int );
	ODebugLine( line : Int );
	ODebugFile( file : Index<String> );
	OBreakPointLine( n : Int );
	OTimestamp;
	OOp( op : Operation );
	OUnknown( byte : Int );
}

enum JumpStyle {
	JNotLt;
	JNotLte;
	JNotGt;
	JNotGte;
	JAlways;
	JTrue;
	JFalse;
	JEq;
	JNeq;
	JLt;
	JLte;
	JGt;
	JGte;
	JPhysEq;
	JPhysNeq;
}

enum Operation {
	OpAs;
	OpNeg;
	OpIncr;
	OpDecr;
	OpNot;
	OpBitNot;
	OpAdd;
	OpSub;
	OpMul;
	OpDiv;
	OpMod;
	OpShl;
	OpShr;
	OpUShr;
	OpAnd;
	OpOr;
	OpXor;
	OpEq;
	OpPhysEq;
	OpLt;
	OpLte;
	OpGt;
	OpGte;
	OpIs;
	OpIn;
	OpIIncr;
	OpIDecr;
	OpINeg;
	OpIAdd;
	OpISub;
	OpIMul;
	OpMemGet8;
	OpMemGet16;
	OpMemGet32;
	OpMemGetFloat;
	OpMemGetDouble;
	OpMemSet8;
	OpMemSet16;
	OpMemSet32;
	OpMemSetFloat;
	OpMemSetDouble;
	OpSign1;
	OpSign8;
	OpSign16;
}
