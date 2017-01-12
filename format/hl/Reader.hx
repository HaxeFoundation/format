package format.hl;
import format.hl.Data;

class Reader {

	var version : Int;
	var i : haxe.io.Input;
	var strings : Array<String>;
	var types : Array<HLType>;
	var debugFiles : Array<String>;
	var flags : haxe.EnumFlags<CodeFlag>;
	var args1 : Array<Dynamic>;
	var args2 : Array<Dynamic>;
	var args3 : Array<Dynamic>;
	var args4 : Array<Dynamic>;
	var readCode : Bool;

	public function new( readCode = true ) {
		this.readCode = readCode;
		args1 = [0];
		args2 = [0,0];
		args3 = [0, 0, 0];
		args4 = [0, 0, 0, 0];
	}

	inline function READ() {
		return i.readByte();
	}

	function index() {
		var b = READ();
		if( (b & 0x80) == 0 )
			return b & 0x7F;
		if( (b & 0x40) == 0 ) {
			var v = READ() | ((b & 31) << 8);
			return (b & 0x20) == 0 ? v : -v;
		}
		var c = READ();
		var d = READ();
		var e = READ();
		var v = ((b & 31) << 24) | (c << 16) | (d << 8) | e;
		return (b & 0x20) == 0 ? v : -v;
	}

	function uindex() {
		var v = index();
		if( v < 0 ) throw "Expected uindex but got " + v;
		return v;
	}

	function readStrings(n) {
		var size = i.readInt32();
		var data = i.read(size);
		var out = [];
		var pos = 0;
		for( _ in 0...n ) {
			var sz = uindex();
			var str = data.getString(pos, sz);
			pos += sz + 1;
			out.push(str);
		}
		return out;
	}

	function getString() {
		var i = index();
		var s = strings[i];
		if( s == null ) throw "No string @" + i;
		return s;
	}

	function getType() {
		var i = index();
		var t = types[i];
		if( t == null ) throw "No type @" + i;
		return t;
	}

	function readType() {
		switch( READ() ) {
		case 0:
			return HVoid;
		case 1:
			return HUi8;
		case 2:
			return HUi16;
		case 3:
			return HI32;
		case 4:
			return HF32;
		case 5:
			return HF64;
		case 6:
			return HBool;
		case 7:
			return HBytes;
		case 8:
			return HDyn;
		case 9:
			return HFun({ args : [for( i in 0...READ() ) HAt(uindex())], ret : HAt(uindex()) });
		case 10:
			var p : ObjPrototype = {
				name : getString(),
				tsuper : null,
				fields : [],
				proto : [],
				globalValue : null,
			};
			var sup = index();
			if( sup >= 0 ) {
				p.tsuper = types[sup];
				if( p.tsuper == null ) throw "assert";
			}
			p.globalValue = uindex() - 1;
			if( p.globalValue < 0 ) p.globalValue = null;
			var nfields = uindex();
			var nproto = uindex();
			p.fields = [for( i in 0...nfields ) { name : getString(), t : HAt(uindex()) }];
			p.proto = [for( i in 0...nproto ) { name : getString(), findex : uindex(), pindex : index() }];
			return HObj(p);
		case 11:
			return HArray;
		case 12:
			return HType;
		case 13:
			return HRef(getType());
		case 14:
			return HVirtual([for( i in 0...uindex() ) { name : getString(), t : HAt(uindex()) }]);
		case 15:
			return HDynObj;
		case 16:
			return HAbstract(getString());
		case 17:
			var name = getString();
			var global = uindex() - 1;
			return HEnum({
				name : name,
				globalValue : global < 0 ? null : global,
				constructs : [for( i in 0...uindex() ) { name : getString(), params : [for( i in 0...uindex() ) HAt(uindex())] }],
			});
		case 18:
			return HNull(getType());
		case x:
			throw "Unsupported type value " + x;
		}
	}

	function fixType( t : HLType ) {
		switch( t ) {
		case HAt(i):
			return types[i];
		default:
			return t;
		}
	}

	function readFunction() : HLFunction {
		var t = getType();
		var idx = uindex();
		var nregs = uindex();
		var nops = uindex();
		return {
			t : t,
			findex : idx,
			regs : [for( i in 0...nregs ) getType()],
			ops : readCode ? [for( i in 0...nops ) readOp()] : skipOps(nops),
			debug : readDebug(nops),
		};
	}

	function skipOps(nops) {
		for( i in 0...nops ) {
			var op = READ();
			var args = OP_ARGS[op];
			if( args < 0 ) {
				switch( op ) {
				case 29, 30, 31, 32, 93:
					index();
					index();
					for( i in 0...uindex() ) index();
				case 69:
					// OSwitch
					uindex();
					for( i in 0...uindex() ) uindex();
					uindex();
				default:
					throw "Don't know how to handle opcode " + op + "("+Type.getEnumConstructs(Opcode)[op]+")";
				}
			} else {
				for( i in 0...args )
					index();
			}
		}
		return null;
	}

	function readOp() {
		var op = READ();
		var args = OP_ARGS[op];
		switch( args ) {
		case -1:
			switch( op ) {
			case 29, 30, 31, 32, 93:
				args3[0] = index();
				args3[1] = index();
				args3[2] = [for( i in 0...uindex() ) index()];
				return Type.createEnumIndex(Opcode, op, args3);
			case 69:
				// OSwitch
				args3[0] = uindex();
				args3[1] = [for( i in 0...uindex() ) uindex()];
				args3[2] = uindex();
				return Type.createEnumIndex(Opcode, op, args3);
			default:
				throw "Don't know how to handle opcode " + op + "("+Type.getEnumConstructs(Opcode)[op]+")";
			}
		case 1:
			args1[0] = index();
			return Type.createEnumIndex(Opcode, op, args1);
		case 2:
			args2[0] = index();
			args2[1] = index();
			return Type.createEnumIndex(Opcode, op, args2);
		case 3:
			args3[0] = index();
			args3[1] = index();
			args3[2] = index();
			return Type.createEnumIndex(Opcode, op, args3);
		case 4:
			args4[0] = index();
			args4[1] = index();
			args4[2] = index();
			args4[3] = index();
			return Type.createEnumIndex(Opcode, op, args4);
		default:
			return Type.createEnumIndex(Opcode, op, [for( i in 0...args ) index()]);
		}
	}

	function readDebug( nops ) {
		if( !flags.has(HasDebug) )
			return null;
		var curfile = -1, curline = 0;
		var debug = [];
		var i = 0;
		while( i < nops ) {
			var c = READ();
			if( (c & 1) != 0 ) {
				c >>= 1;
				curfile = (c << 8) | READ();
				if( curfile >= debugFiles.length )
					throw "Invalid debug file";
			} else if( (c & 2) != 0 ) {
				var delta = c >> 6;
				var count = (c >> 2) & 15;
				if( i + count > nops )
					throw "Outside range";
				while( count-- > 0 ) {
					debug[i<<1] = curfile;
					debug[(i<<1)|1] = curline;
					i++;
				}
				curline += delta;
			} else if( (c & 4) != 0 ) {
				curline += c >> 3;
				debug[i<<1] = curfile;
				debug[(i<<1)|1] = curline;
				i++;
			} else {
				var b2 = READ();
				var b3 = READ();
				curline = (c >> 3) | (b2 << 5) | (b3 << 13);
				debug[i<<1] = curfile;
				debug[(i<<1)|1] = curline;
				i++;
			}
		}
		return debug;
	}

	public function read( i : haxe.io.Input ) : Data {
		this.i = i;
		if( i.readString(3) != "HLB" )
			throw "Invalid HL file";
		version = READ();
		if( version > 1 )
			throw "HL Version " + version + " is not supported";
		flags = haxe.EnumFlags.ofInt(uindex());
		var nints = uindex();
		var nfloats = uindex();
		var nstrings = uindex();
		var ntypes = uindex();
		var nglobals = uindex();
		var nnatives = uindex();
		var nfunctions = uindex();
		var entryPoint = uindex();
		var ints = [for( _ in 0...nints ) i.readInt32()];
		var floats = [for( _ in 0...nfloats ) i.readDouble()];
		strings = readStrings(nstrings);
		debugFiles = null;
		if( flags.has(HasDebug) )
			debugFiles = readStrings(uindex());
		types = [];
		for( i in 0...ntypes )
			types[i] = readType();
		for( i in 0...ntypes )
			switch( types[i] ) {
			case HFun(f):
				for( i in 0...f.args.length ) f.args[i] = fixType(f.args[i]);
				f.ret = fixType(f.ret);
			case HObj(p):
				for( f in p.fields )
					f.t = fixType(f.t);
			case HVirtual(fl):
				for( f in fl )
					f.t = fixType(f.t);
			case HEnum(e):
				for( c in e.constructs )
					for( i in 0...c.params.length )
						c.params[i] = fixType(c.params[i]);
			default:
			}
		return {
			version : version,
			flags : flags,
			ints : ints,
			floats : floats,
			strings : strings,
			debugFiles : debugFiles,
			types : types,
			entryPoint : entryPoint,
			globals : [for( i in 0...nglobals ) getType()],
			natives : [for( i in 0...nnatives ) { lib : getString(), name : getString(), t : getType(), findex : uindex() }],
			functions : [for( i in 0...nfunctions ) readFunction()],
		};
	}


	static var OP_ARGS = [
		2,
		2,
		2,
		2,
		2,
		2,
		1,

		3,
		3,
		3,
		3,
		3,
		3,
		3,
		3,
		3,
		3,
		3,
		3,
		3,

		2,
		2,
		1,
		1,

		2,
		3,
		4,
		5,
		6,
		-1,
		-1,
		-1,
		-1,

		2,
		3,
		3,

		 2,
		2,
		3,
		3,
		2,
		2,
		3,
		3,
		3,

		2,
		2,
		2,
		2,
		3,
		3,
		3,
		3,
		3,
		3,
		3,
		3,
		1,

		2,
		2,
		2,
		2,
		2,
		2,
		2,

		0,
		1,
		1,
		1,
		-1,
		1,
		2,
		1,

		3,
		3,
		3,
		3,
		3,
		3,
		3,
		3,
		3,
		3,
		3,
		3,

		1,
		2,
		2,
		2,
		2,

		2,
		2,
		2,

		-1,
		2,
		2,
		4,
		3,
	];

}
