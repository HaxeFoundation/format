import format.neko.Value;

class ABuffer extends StringBuf, implements ValueAbstract {
}

class TemploAPI {
	
	var String : Value;
	var Array : Value;
	var vm : format.neko.VM;
	
	public function new(vm) {
		this.vm = vm;
		
		// instances
		var ostring = new ValueObject();
		var oarray = new ValueObject();
		
		// statics
		var pstring = new ValueObject();
		var __s = vm.hashField("__s");
		pstring.fields.set(vm.hashField("new"), VFunction(VFun1(function(v:Value) {
			var str = new ValueObject(ostring);
			str.fields.set(__s, VString(vm.valueToString(v)));
			return VObject(str);
		})));
		var parray = new ValueObject();
		String = VObject(pstring);
		Array = VObject(parray);
	}
	
	function open() {
		return VAbstract(new ABuffer());
	}
	
	function add( b : Value, v : Value ) {
		vm.abstract(b, ABuffer).add(vm.valueToString(v));
		return VNull;
	}
	
	function close( b : Value ) {
		return VString(vm.abstract(b,ABuffer).toString());
	}
	
	function split( s : Value, sep : Value ) : Value {
		throw "TODO";
		return null;
	}
	
	function iter( v : Value ) : Value {
		throw "TODO";
		return null;
	}
	
	function loop( i : Value, callb : Value -> Value -> Dynamic -> Void, b : Value,  ctx : Dynamic ) {
		throw "TODO";
	}
	
	function use( file : Value, buf : StringBuf, ctx : Dynamic, content : StringBuf -> Dynamic -> Void ) {
		throw "TODO";
	}
	
	function macros( file : Value, m : Dynamic ) {
		throw "TODO";
	}

	public static function makeLoader(vm) {
		var api = new TemploAPI(vm);
		var loader = vm.defaultLoader();
		var vapi = new ValueObject();
		var field = function(n, v) vapi.fields.set(vm.hashField(n), v);
		var fun = function(n, v) field(n, VFunction(v));
		field("String", api.String);
		field("Array", api.Array);
		fun("open", VFun0(api.open));
		fun("add", VFun2(api.add));
		fun("close", VFun1(api.close));
		loader.fields.set(vm.hashField("__templo"), VObject(vapi));
		return loader;
	}
	
}


class Test {

	static function main() {
		var i = neko.io.File.read("tpl.mtt.n",true);
		var data = new format.neko.Reader(i).read();
		var vm = new format.neko.VM();
		var m = vm.load(data, TemploAPI.makeLoader(vm));
		var buf = new ABuffer();
		var ctx = new ValueObject();
		var v = vm.call(VObject(m.exports), m.exports.fields.get(vm.hashField("execute")), [VAbstract(buf), VObject(ctx)]);
		trace(buf.toString());
	}

}