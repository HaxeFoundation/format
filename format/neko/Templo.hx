package format.neko;

import format.neko.Value;

class ABuffer extends StringBuf implements ValueAbstract {
}

private class Iter {
	public var __it : Iterator<Dynamic>;
	public var current : Dynamic;
	public var index : Int;
	public var number : Int;
	public var first : Bool;
	public var last : Bool;
	public var odd : Bool;
	public var even : Bool;
	public var size : Null<Int>;
	public function new( it, size ) {
		__it = it;
		this.size = size;
		current = null;
		index = 0;
		number = 1;
		first = true;
		last = false;
		odd = true;
		even = false;
	}
}

class Templo {

	var _String : Value;
	var _Array : Value;
	var vm : format.neko.VM;

	public function new(ivm) {
		var me = this;
		this.vm = ivm;
		var pstring = new ValueObject();
		pstring.fields.set(vm.hashField("new"), VFunction(VFun1(function(v:Value) {
			return VProxy(me.vm.valueToString(v));
		})));
		var parray = new ValueObject();
		parray.fields.set(vm.hashField("new"), VFunction(VFun0(function() {
			return VProxy(new Array());
		})));
		parray.fields.set(vm.hashField("new1"), VFunction(VFun2(function(v:Value,len:Value) {
			switch(v) {
			case VArray(a):
				var vlen;
				switch( len ) { case VInt(i): vlen = i; default: return null; };
				var a2 = new Array();
				for( i in 0...vlen )
					a2.push(me.vm.unwrap(a[i]));
				return VProxy(a2);
			default:
				return null;
			};
		})));
		_String = VObject(pstring);
		_Array = VObject(parray);
	}

	function open() {
		return VAbstract(new ABuffer());
	}

	function add( b : Value, v : Value ) {
		vm._abstract(b, ABuffer).add(vm.valueToString(v));
		return VNull;
	}

	function close( b : Value ) {
		return VString(vm._abstract(b,ABuffer).toString());
	}

	function split( s : Value, sep : Value ) : Value {
		switch( s ) {
		case VString(s):
			switch(sep) {
			case VString(sep):
				var a = s.split(sep);
				var h = null, tl = null;
				for( i in a )
					if( tl == null ) {
						tl = [VString(i), null];
						h = VArray(tl);
					} else {
						var tmp = [VString(i), null];
						tl[1] = VArray(tmp);
						tl = tmp;
					}
				return h;
			default:
			}
		default:
		}
		return null;
	}

	function iter( v : Value ) : Value {
		var it : Iterator<Dynamic>;
		var size : Null<Int> = null;
		var data : Dynamic = switch( v ) {
		case VProxy(o): o;
		case VNull: throw "Cannot iterate on null";
		default: { };
		}
		if( data.iterator != null ) {
			var length : Dynamic = data.length;
			if( Std.is(length,Int) ) size = length;
			it = data.iterator();
		} else if( data.hasNext != null && data.next != null )
			it = data;
		else
			throw "The value must be iterable";
		return VProxy(new Iter(it,size));
	}

	function loop( vi : Value, callb : Value, b : Value,  ctx : Value ) {
		var i : Iter;
		switch(vi) {
		case VProxy(o): i = cast o;
		default: return null;
		}
		var it = i.__it;
		var k = 1;
		var even = false;
		while( it.hasNext() ) {
			var v = it.next();
			i.current = v;
			vm.call(VNull,callb,[vm.wrap(v),b,ctx]);
			// update fields
			i.first = false;
			i.index = k;
			k++;
			i.number = k;
			i.last = (k == i.size);
			i.odd = even;
			even = !even;
			i.even = even;
		}
		return VNull;
	}

	function use( file : Value, buf : Value, ctx : Value, content : Value ) {
		throw "TODO";
		return null;
	}

	function macros( file : Value, m : Value ) {
		throw "TODO";
		return null;
	}

	public static function makeLoader(vm) {
		var api = new Templo(vm);
		var loader = vm.defaultLoader();
		var vapi = new ValueObject();
		var field = function(n, v) vapi.fields.set(vm.hashField(n), v);
		var fun = function(n, v) field(n, VFunction(v));
		field("String", api._String);
		field("Array", api._Array);
		fun("open", VFun0(api.open));
		fun("add", VFun2(api.add));
		fun("close", VFun1(api.close));
		fun("split", VFun2(api.split));
		fun("iter", VFun1(api.iter));
		fun("loop", VFun4(api.loop));
		fun("use", VFun4(api.use));
		fun("macros", VFun2(api.macros));
		loader.fields.set(vm.hashField("__templo"), VObject(vapi));
		return loader;
	}

	public static function execute( vm : VM, data : Data, ctx : {} ) {
		var m = vm.load(data, format.neko.Templo.makeLoader(vm));
		var buf = new ABuffer();
		var v = vm.call(VObject(m.exports), m.exports.fields.get(vm.hashField("execute")), [VAbstract(buf), VProxy(ctx)]);
		return buf.toString();
	}

}
