package format.elf;
import format.elf.Data;

class Reader {

	var i : haxe.io.Input;
	var is64 : Bool;
	var data : haxe.io.Bytes;

	public function new(i) {
		this.i = i;
	}

	public function read() : Data {
		var h = readHeader();
		data = i.read(h.sectionHeader.low - h.headerSize); // go to section header
		var sections = [for( i in 0...h.sectionHeaderEntries ) readSectionHeader()];
		return {
			header : h,
			sections : sections,
			data : data,
		};
	}

	function readAddress() : Address {
		return is64 ? haxe.Int64.make(i.readInt32(), i.readInt32()) : i.readInt32();
	}

	inline function read64() {
		return readAddress();
	}

	function readSectionHeader() {
		return {
			nameIndex : i.readInt32(),
			type : i.readInt32(),
			flags : read64(),
			address : readAddress(),
			offset : readAddress(),
			size : read64(),
			link : i.readInt32(),
			info : i.readInt32(),
			addressAlign : i.readInt32(),
			entSize : i.readInt32(),
		};
	}

	function readHeader() : Header {
		if( i.readString(4) != "\x7fELF" ) throw "Invalid ELF file";
		is64 = i.readByte() == 2;
		var isBE = i.readByte() == 2;
		return {
			is64 : is64,
			isBigEndian : isBE,
			elfVersion : i.readByte(),
			abiVersion : i.readByte(),
			abiSubVersion : i.readByte(),
			elfType : {
				i.readString(7); // unused
				i.readUInt16();
			},
			elfInstruction : i.readUInt16(),
			entryPoint : {
				var v = i.readInt32();
				if( v != 1 ) throw "Invalid version "+v;
				readAddress();
			},
			programHeader : readAddress(),
			sectionHeader : readAddress(),
			flags : i.readInt32(),
			headerSize : i.readUInt16(),
			programHeaderSize : i.readUInt16(),
			programHeaderEntries : i.readUInt16(),
			sectionHeaderSize : i.readUInt16(),
			sectionHeaderEntries : i.readUInt16(),
			sectionNameIndex : i.readUInt16(),
		};
	}

}
