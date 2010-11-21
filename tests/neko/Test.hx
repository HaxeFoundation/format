class Test {

	static function main() {
		var i = neko.io.File.read("test.bin",true);
		var data = new format.neko.Reader(i).read();
		var vm = new format.neko.VM();
		vm.load(data);
	}

}