class Test {
	
	static function main() {
		#if neko
		var i = neko.io.File.read("tpl.mtt.n", true);
		#else
		var i = new haxe.io.BytesInput(haxe.Resource.getBytes("tpl.mtt.n"));
		#end
		var data = new format.neko.Reader(i).read();
		var vm = new format.neko.VM();
		var ctx = {
			api : { version : function(x) return x },
			//logged : true,
		};
		trace(format.neko.Templo.execute(vm, data, ctx));
	}

}