package format.abc;
import format.abc.Data;

private class NullOutput extends haxe.io.Output {

	public var n : Int;

	public function new() {
		n = 0;
	}

	override function writeByte(c) {
		n++;
	}

	override function writeBytes(b,pos,len) {
		n += len;
		return len;
	}

}

class Context {

	var data : ABCData;
	var hstrings : Hash<Int>;
	var curClass : ClassDef;
	var curFunction : Function;
	var init : Function;
	var fieldSlot : Int;
	var registers : Array<Bool>;
	var bytepos : NullOutput;
	var opw : OpWriter;

	public var emptyString(default,null) : Index<String>;
	public var nsPublic(default,null) : Index<Namespace>;
	public var arrayProp(default,null) : Index<Name>;

	public function new() {
		bytepos = new NullOutput();
		opw = new OpWriter(bytepos);
		hstrings = new Hash();
		data = new ABCData();
		data.ints = new Array();
		data.uints = new Array();
		data.floats = new Array();
		data.strings = new Array();
		data.namespaces = new Array();
		data.nssets = new Array();
		data.metadatas = new Array();
		data.methodTypes = new Array();
		data.names = new Array();
		data.classes = new Array();
		data.functions = new Array();
		emptyString = string("");
		nsPublic = namespace(NPublic(emptyString));
		arrayProp = name(NMultiLate(nsset([nsPublic])));
		beginFunction([],null);
		ops([OThis,OScope]);
		init = curFunction;
		init.maxStack = 2;
		init.maxScope = 2;
	}

	public function int(i) {
		return lookup(data.ints,i);
	}

	public function uint(i) {
		return lookup(data.uints,i);
	}

	public function float(f) {
		return lookup(data.floats,f);
	}

	public function string( s : String ) : Index<String> {
		var n = hstrings.get(s);
		if( n == null ) {
			data.strings.push(s);
			n = data.strings.length;
			hstrings.set(s,n);
		}
		return Idx(n);
	}

	public function namespace(n) {
		return elookup(data.namespaces,n);
	}

	public function nsset( ns : NamespaceSet ) : Index<NamespaceSet> {
		for( i in 0...data.nssets.length ) {
			var s = data.nssets[i];
			if( s.length != ns.length )
				continue;
			var ok = true;
			for( j in 0...s.length )
				if( !Type.enumEq(s[j],ns[j]) ) {
					ok = false;
					break;
				}
			if( ok )
				return Idx(i + 1);
		}
		data.nssets.push(ns);
		return Idx(data.nssets.length);
	}

	public function name(n) {
		return elookup(data.names,n);
	}

	public function type(path) : Null<Index<Name>> {
		if( path == "*" )
			return null;
		var path = path.split(".");
		var cname = path.pop();
		var pid = string(path.join("."));
		var nameid = string(cname);
		var pid = namespace(NPublic(pid));
		var tid = name(NName(nameid,pid));
		return tid;
	}

	public function property(pname, ?ns) {
		var pid = string("");
		var nameid = string(pname);
		var pid = if( ns == null ) namespace(NPublic(pid)) else ns;
		var tid = name(NName(nameid,pid));
		return tid;
	}

	public function methodType(m) : Index<MethodType> {
		data.methodTypes.push(m);
		return Idx(data.methodTypes.length - 1);
	}

	function lookup<T>( arr : Array<T>, n : T ) : Index<T> {
		for( i in 0...arr.length )
			if( arr[i] == n )
				return Idx(i + 1);
		arr.push(n);
		return Idx(arr.length);
	}

	function elookup<T>( arr : Array<T>, n : T ) : Index<T> {
		for( i in 0...arr.length )
			if( Type.enumEq(arr[i],n) )
				return Idx(i + 1);
		arr.push(n);
		return Idx(arr.length);
	}

	public function getData() {
		return data;
	}

	function beginFunction(args,ret,?extra) : Index<Function> {
		curFunction = {
			type : methodType({ args : args, ret : ret, extra : extra }),
			nRegs : args.length + 1,
			initScope : 0,
			maxScope : 0,
			maxStack : 0,
			code : [],
			trys : [],
			locals : [],
		};
		data.functions.push(curFunction);
		registers = new Array();
		for( x in 0...curFunction.nRegs )
			registers.push(true);
		return Idx(data.functions.length - 1);
	}

	public function allocRegister() {
		for( i in 0...registers.length )
			if( !registers[i] ) {
				registers[i] = true;
				return i;
			}
		registers.push(true);
		curFunction.nRegs++;
		return registers.length - 1;
	}

	public function freeRegister(i) {
		registers[i] = false;
	}

	public function beginClass( path : String ) {
		endClass();
		var tpath = this.type(path);
		beginFunction([],null);
		var st = curFunction.type;
		op(ORetVoid);
		beginFunction([],null);
		var cst = curFunction.type;
		op(ORetVoid);
		fieldSlot = 1;
		curClass = {
			name : tpath,
			superclass : this.type("Object"),
			interfaces : [],
			isSealed : false,
			isInterface : false,
			isFinal : false,
			namespace : null,
			constructor : cst,
			statics : st,
			fields : [],
			staticFields : [],
		};
		data.classes.push(curClass);
		curFunction = null;
		return curClass;
	}

	function endClass() {
		if( curClass == null )
			return;
		curFunction = init;
		ops([
			OGetGlobalScope,
			OGetLex( this.type("Object") ),
			OScope,
			OGetLex( curClass.superclass ),
			OClassDef( Idx(data.classes.length - 1) ),
			OPopScope,
			OInitProp( curClass.name ),
		]);
		curFunction = null;
		curClass = null;
	}

	public function beginMethod( mname : String, targs, tret, ?isStatic, ?isOverride, ?isFinal ) {
		var m = beginFunction(targs,tret);
		var fl = if( isStatic ) curClass.staticFields else curClass.fields;
		fl.push({
			name : property(mname),
			slot : 0,
			kind : FMethod(curFunction.type,KNormal,isFinal,isOverride),
			metadatas : null,
		});
		return curFunction;
	}

	public function defineField( fname : String, t, ?isStatic ) : Slot {
		var fl = if( isStatic ) curClass.staticFields else curClass.fields;
		var slot = fieldSlot++;
		fl.push({
			name : property(fname),
			slot : slot,
			kind : FVar(t),
			metadatas : null,
		});
		return slot;
	}

	public function op(o) {
		curFunction.code.push(o);
		opw.write(o);
	}

	public function ops( ops : Array<OpCode> ) {
		for( i in 0...ops.length )
			op(ops[i]);
	}

	public function backwardJump() {
		var start = bytepos.n;
		var me = this;
		op(OLabel);
		return function(jcond) {
			me.op(OJump(jcond,start - me.bytepos.n - 4));
		};
	}

	public function jump( jcond ) {
		var ops = curFunction.code;
		var pos = ops.length;
		op(OJump(JTrue,-1));
		var start = bytepos.n;
		var me = this;
		return function() {
			ops[pos] = OJump(jcond,me.bytepos.n - start);
		};
	}

	public function finalize() {
		endClass();
		curFunction = init;
		op(ORetVoid);
		curFunction = null;
		curClass = null;
	}

}