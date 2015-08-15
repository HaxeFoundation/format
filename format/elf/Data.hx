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

typedef SectionHeader = {
	var nameIndex : Int;
	var type : Int;
	var flags : haxe.Int64;
	var address : Address;
	var offset : Address;
	var size : haxe.Int64;
	var link : Int;
	var info : Int;
	var addressAlign : Int;
	var entSize : Int;
}

typedef Data = {
	var header : Header;
	var sections : Array<SectionHeader>;
	var data : haxe.io.Bytes;
}