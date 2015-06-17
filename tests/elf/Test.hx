
class Test  {

 	static function main() {
		var i = sys.io.File.read("neko");
		var data = new format.elf.Reader(i).read();
		var fields = Reflect.fields(data.header);
		fields.sort(Reflect.compare);
		for( f in fields ) {
			trace(f + " : " + Reflect.field(data.header, f));
		}
	}

}