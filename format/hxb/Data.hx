package format.hxb;

import haxe.ds.Vector;
import haxe.ds.Option;
import haxe.Exception;

class HxbReaderException extends Exception {}

// Primitives

class Todo {}

class NoData {
	public function new() {}
}

// Compounds

typedef Path = {
	var pack:Array<String>;
	var name:String;
}

typedef FullPath = Path & {
	var typeName:String;
}

typedef Pos = {
	var file:String;
	var min:Int;
	var max:Int;
}

// Module types

enum ModuleTypeKind {
	Class(c:ClassData);
	Enum(en:EnumData);
	Typedef(td:TypedefData);
	Abstract(a:AbstractData);
}

typedef ModuleType = {
	var path:Path;
	var pos:Pos;
	var namePos:Pos;
	var params:Vector<TypeParameter>;
}

typedef ModuleTypeWithKind = {
	var m:ModuleType;
	var kind:ModuleTypeKind;
}

typedef ClassData = {
	var flags:Int;
	var constructor:Option<ClassField>;
	var fields:Array<ClassField>;
	var statics:Array<ClassField>;
}

typedef EnumData = {
	var fields:Array<EnumField>;
}

typedef TypedefData = {};
typedef AbstractData = {};

typedef Class = {
	var m:ModuleType;
	var c:ClassData;
}

typedef Enum = {
	var m:ModuleType;
	var en:EnumData;
}

typedef Typedef = {
	var m:ModuleType;
	var td:TypedefData;
}

typedef Abstract = {
	var m:ModuleType;
	var a:AbstractData;
}

// Type parameters

enum TypeParameterHost {
	Type;
	Constructor;
	Method;
	EnumConstructor;
	AnonField;
	Local;
}

typedef TypeParameter = {
	var path:Path;
	var pos:Pos;
	var host:TypeParameterHost;
}

// Type instances
typedef Monomorph = {
	var type:Option<TypeInstance>;
}

enum TypeInstance {
	TInst(c:Class, params:Array<TypeInstance>);
	TEnum(en:Enum, params:Array<TypeInstance>);
	TAbstract(a:Abstract, params:Array<TypeInstance>);
	TType(td:Typedef, params:Array<TypeInstance>);
	TMono(mono:Monomorph);
	TDynamic;
	TDynamicAccess(t:TypeInstance);
}

// Fields

typedef ClassField = {
	var name:String;
	var pos:Pos;
	var namePos:Pos;
	var overloads:Array<ClassField>;
}

typedef EnumField = {
	var name:String;
	var pos:Pos;
	var namePos:Pos;
	var index:Int;
}

// Chunks

typedef MDF = {
	var path:Path;
	var file:String;
	var numAnons:Int;
	var numMonos:Int;
}

typedef MTF = {
	var types:Array<ModuleTypeWithKind>;
}

typedef Module = {
	var MDF:MDF;
	var MTF:Null<MTF>;
}

enum abstract ChunkKind(String) {
	final STR;
	final DOC;
	final MDF;
	final MTF;
	final CLR;
	final ENR;
	final ABR;
	final TDR;
	final AFR;
	final CLD;
	final END;
	final ABD;
	final TDD;
	final EOT;
	final EFR;
	final CFR;
	final CFD;
	final EFD;
	final AFD;
	final EOF;
	final EXD;
	final EOM;

	static public function fromString(s:String):ChunkKind {
		return switch (s) {
			case "STR": STR;
			case "DOC": DOC;
			case "MDF": MDF;
			case "MTF": MTF;
			case "CLR": CLR;
			case "ENR": ENR;
			case "ABR": ABR;
			case "TDR": TDR;
			case "AFR": AFR;
			case "CLD": CLD;
			case "END": END;
			case "ABD": ABD;
			case "TDD": TDD;
			case "EOT": EOT;
			case "EFR": EFR;
			case "CFR": CFR;
			case "CFD": CFD;
			case "EFD": EFD;
			case "AFD": AFD;
			case "EOF": EOF;
			case "EXD": EXD;
			case "EOM": EOM;
			case _: throw new HxbReaderException('Unknown chunk kind: $s');
		}
	}
}
