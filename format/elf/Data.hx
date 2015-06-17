package format.elf;

typedef Address = haxe.Int64;

typedef Header = {
	var is64 : Bool;
	var isBigEndian : Bool;
	var elfVersion : Int;
	var abiVersion : Int;
	var abiSubVersion : Int;
	var elfType : Int;
	var elfInstruction : Int;
	var entryPoint : Address;
	var programHeader : Address;
	var sectionHeader : Address;
	var flags : Int;
	var headerSize : Int;
	var programHeaderSize : Int;
	var programHeaderEntries : Int;
	var sectionHeaderSize : Int;
	var sectionHeaderEntries : Int;
	var sectionNameIndex : Int;
}

typedef Data = {
	var header : Header;
}