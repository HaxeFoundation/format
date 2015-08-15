
class Test  {

 	static function main() {
		var i = sys.io.File.read("neko");
		var elf = new format.elf.Reader(i).read();
		var fields = Reflect.fields(elf.header);
		fields.sort(Reflect.compare);
		for( f in fields ) {
			trace(f + " : " + Reflect.field(elf.header, f));
		}

		var sstrings = elf.sections[elf.header.sectionNameIndex];
		var stringTable = elf.data.sub(sstrings.offset.low - elf.header.headerSize, sstrings.size.low);

		for( s in elf.sections ) {
			trace("SECTION "+stringTable.sub(s.nameIndex,stringTable.length-s.nameIndex).toString().split("\x00")[0]);
			var fields = Reflect.fields(s);
			fields.sort(Reflect.compare);
			for( f in fields ) {
				trace("  "+f + " : " + Reflect.field(s, f));
			}
		}
	}

}