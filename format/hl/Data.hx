package format.hl;

enum CodeFlag {
	HasDebug;
}

typedef Data = {
	var version : Int;
	var flags : haxe.EnumFlags<CodeFlag>;
	var ints : Array<Int>;
	var floats : Array<Float>;
	var strings : Array<String>;
	var debugFiles : Array<String>;
	var types : Array<HLType>;
	var globals : Array<HLType>;
	var natives : Array<NativeFunction>;
	var functions : Array<HLFunction>;
	var constants : Array<HLConstant>;
	var entryPoint : Int;
}

enum HLType {
	HVoid;
	HUi8;
	HUi16;
	HI32;
	HI64;
	HF32;
	HF64;
	HBool;
	HBytes;
	HDyn;
	HFun( fun : FunPrototype );
	HObj( proto : ObjPrototype );
	HArray;
	HType;
	HRef( t : HLType );
	HVirtual( fields : Array<{ name : String, t : HLType }> );
	HDynObj;
	HAbstract( name : String );
	HEnum( proto : EnumPrototype );
	HNull( t : HLType );
	// only for reader
	HAt( i : Int );
}

typedef FunPrototype = {
	var args : Array<HLType>;
	var ret : HLType;
}

typedef ObjPrototype = {
	var name : String;
	var tsuper : HLType;
	var fields : Array<{ name : String, t : HLType }>;
	var proto : Array<{ name : String, findex : Int, pindex : Int }>;
	var globalValue : Null<Int>;
	var bindings : Array<{ fid : Int, mid : Index<FunTable> }>;
}

typedef EnumPrototype = {
	var name : String;
	var globalValue : Null<Int>;
	var constructs : Array<{ name : String, params : Array<HLType> }>;
}

typedef NativeFunction = {
	var lib : String;
	var name : String;
	var t : HLType;
	var findex : Int;
}

typedef HLFunction = {
	var t : HLType;
	var findex : Int;
	var regs : Array<HLType>;
	var ops : Array<Opcode>;
	var debug : Array<Int>;
	var assigns : Array<{ varName : Index<String>, position : Index<Opcode> }>;
}

typedef HLConstant = {
	var global : Int;
	var fields : Array<Int>;
}

typedef FunTable = Array<AnyFunction>;

enum AnyFunction {
	FHL( f : HLFunction );
	FNative( f : NativeFunction );
}

typedef Reg = Int;
typedef Index<T> = Int;
typedef ObjField = Void;
typedef Global = Void;
typedef EnumConstruct = Void;

enum Opcode {
	OMov( dst : Reg, a : Reg );
	OInt( dst : Reg, i : Index<Int> );
	OFloat( dst : Reg, i : Index<Float> );
	OBool( dst : Reg, b : Bool );
	OBytes( dst : Reg, i : Index<String> );
	OString( dst : Reg, i : Index<String> );
	ONull( dst : Reg );
	OAdd( dst : Reg, a : Reg, b : Reg );
	OSub( dst : Reg, a : Reg, b : Reg );
	OMul( dst : Reg, a : Reg, b : Reg );
	OSDiv( dst : Reg, a : Reg, b : Reg );
	OUDiv( dst : Reg, a : Reg, b : Reg );
	OSMod( dst : Reg, a : Reg, b : Reg );
	OUMod( dst : Reg, a : Reg, b : Reg );
	OShl( dst : Reg, a : Reg, b : Reg );
	OSShr( dst : Reg, a : Reg, b : Reg );
	OUShr( dst : Reg, a : Reg, b : Reg );
	OAnd( dst : Reg, a : Reg, b : Reg );
	OOr( dst : Reg, a : Reg, b : Reg );
	OXor( dst : Reg, a : Reg, b : Reg );
	ONeg( dst : Reg, a : Reg );
	ONot( dst : Reg, a : Reg );
	OIncr( dst : Reg );
	ODecr( dst : Reg );
	OCall0( dst : Reg, i : Index<FunTable> );
	OCall1( dst : Reg, i : Index<FunTable>, a : Reg );
	OCall2( dst : Reg, i : Index<FunTable>, a : Reg, b : Reg );
	OCall3( dst : Reg, i : Index<FunTable>, a : Reg, b : Reg, c : Reg );
	OCall4( dst : Reg, i : Index<FunTable>, a : Reg, b : Reg, c : Reg, d : Reg );
	OCallN( dst : Reg, i : Index<FunTable>, args : Array<Reg> );
	OCallMethod( dst : Reg, i : Index<ObjField>, args : Array<Reg> );
	OCallThis( dst : Reg, i : Index<ObjField>, args : Array<Reg> );
	OCallClosure( dst : Reg, obj : Reg, args : Array<Reg> );
	OStaticClosure( dst : Reg, i : Index<FunTable> );
	OInstanceClosure( dst : Reg, i : Index<FunTable>, a : Reg );
	OVirtualClosure( dst : Reg, a : Reg, i : Index<ObjField> );
	OGetGlobal( dst : Reg, i : Index<Global> );
	OSetGlobal( i : Index<Global>, a : Reg );
	OField( dst : Reg, a : Reg, i : Index<ObjField> );
	OSetField( dst : Reg, i : Index<ObjField>, a : Reg );
	OGetThis( dst : Reg, i : Index<ObjField> );
	OSetThis( i : Index<ObjField>, a : Reg );
	ODynGet( dst : Reg, a : Reg, i : Index<String> );
	ODynSet( dst : Reg, i : Index<String>, a : Reg );
	OJTrue( dst : Reg, offset : Int );
	OJFalse( dst : Reg, offset : Int );
	OJNull( dst : Reg, offset : Int );
	OJNotNull( dst : Reg, offset : Int );
	OJSLt( dst : Reg, a : Reg, offset : Int );
	OJSGte( dst : Reg, a : Reg, offset : Int );
	OJSGt( dst : Reg, a : Reg, offset : Int );
	OJSLte( dst : Reg, a : Reg, offset : Int );
	OJULt( dst : Reg, a : Reg, offset : Int );
	OJUGte( dst : Reg, a : Reg, offset : Int );
	OJNotLt( dst : Reg, a : Reg, offset : Int );
	OJNotGte( dst : Reg, a : Reg, offset : Int );
	OJEq( dst : Reg, a : Reg, offset : Int );
	OJNotEq( dst : Reg, a : Reg, offset : Int );
	OJAlways( offset : Int );
	OToDyn( dst : Reg, a : Reg );
	OToSFloat( dst : Reg, a : Reg );
	OToUFloat( dst : Reg, a : Reg );
	OToInt( dst : Reg, a : Reg );
	OSafeCast( dst : Reg, a : Reg );
	OUnsafeCast( dst : Reg, a : Reg );
	OToVirtual( dst : Reg, a : Reg );
	OLabel;
	ORet( dst : Reg );
	OThrow( dst : Reg );
	ORethrow( dst : Reg );
	OSwitch( dst : Reg, cases : Array<Int>, end : Int );
	ONullCheck( dst : Reg );
	OTrap( dst : Reg, end : Int );
	OEndTrap( last : Bool );
	OGetUI8( dst : Reg, a : Reg, b : Reg );
	OGetUI16( dst : Reg, a : Reg, b : Reg );
	OGetMem( dst : Reg, a : Reg, b : Reg );
	OGetArray( dst : Reg, a : Reg, b : Reg );
	OSetUI8( dst : Reg, a : Reg, b : Reg );
	OSetUI16( dst : Reg, a : Reg, b : Reg );
	OSetMem( dst : Reg, a : Reg, b : Reg );
	OSetArray( dst : Reg, a : Reg, b : Reg );
	ONew( dst : Reg );
	OArraySize( dst : Reg, a : Reg );
	OType( dst : Reg, t : Index<HLType> );
	OGetType( dst : Reg, a : Reg );
	OGetTID( dst : Reg, a : Reg );
	ORef( dst : Reg, a : Reg );
	OUnref( dst : Reg, a : Reg );
	OSetref( dst : Reg, a : Reg );
	OMakeEnum( dst : Reg, i : Index<EnumConstruct>, a : Array<Reg> );
	OEnumAlloc( dst : Reg, i : Index<EnumConstruct> );
	OEnumIndex( dst : Reg, a : Reg );
	OEnumField( dst : Reg, a : Reg, i : Index<EnumConstruct>, param : Int );
	OSetEnumField( dst : Reg, param : Int, a : Reg );
	OAssert;
	ORefData( dst : Reg, src : Reg );
	ORefOffset( dst : Reg, src : Reg, offset : Reg );
	ONop;
}
