package format.hxb;

import haxe.ds.Vector;
import haxe.io.Bytes;
import format.hxb.Data;
import haxe.ds.ReadOnlyArray;
import haxe.io.Input;
import haxe.ds.Option;

class Reader {
	var i:Input;
	var api:Null<ReaderApi>;
	var stringPool:Vector<String> = null;
	var classes:Vector<Class> = null;
	var enums:Vector<Enum> = null;
	var typedefs:Vector<Typedef> = null;
	var abstracts:Vector<Abstract> = null;
	var anonFields:Vector<ClassField> = null;
	var module:Null<Module> = null;

	public function new(i:Input) {
		this.i = i;
	}

	inline function fail(reason:String):Dynamic {
		throw new HxbReaderException(reason);
	}

	// Primitives
	// TODO: these probably want to be while loops

	function readUleb128() {
		final b = i.readByte();
		return if (b >= 0x80) {
			(b & 0x7F) | (readUleb128() << 7);
		} else {
			b;
		}
	}

	function readLeb128() {
		function read(acc:Int, shift:Int) {
			final b = i.readByte();
			final acc = ((b & 0x7F) << shift) | acc;
			return if (b >= 0x80) {
				read(acc, shift + 7);
			} else {
				if (b & 0x40 != 0) {
					acc | (~0 << (shift + 7));
				} else {
					acc;
				}
			}
		}
	}

	function readString() {
		return stringPool[readUleb128()];
	}

	function readOption<T>(f:() -> T) {
		return if (i.readByte() == 0) {
			None;
		} else {
			Some(f());
		}
	}

	// Compounds

	function readList<T>(f:() -> T) {
		var a = [];
		a.resize(readUleb128());
		for (k in 0...a.length) {
			a[k] = f();
		}
		return a;
	}

	function readPath() {
		return {
			pack: readList(readString),
			name: readString()
		}
	}

	function readFullPath() {
		return {
			pack: readList(readString),
			name: readString(),
			typeName: readString()
		}
	}

	function readPos() {
		return {
			file: readString(),
			min: readUleb128(),
			max: readUleb128(),
		}
	}

	// Type parameters

	function readTypeParameterHost():TypeParameterHost {
		return switch (i.readByte()) {
			case 0: Type;
			case 1: Constructor;
			case 2: Method;
			case 3: EnumConstructor;
			case 4: AnonField;
			case 5: Local;
			case i: fail('Unknown type parameter host byte: $i');
		}
	}

	function readTypeParametersForward() {
		final length = readUleb128();
		final params = new Vector(length);
		for (i in 0...length) {
			final ttp = {
				path: readPath(),
				pos: readPos(),
				host: readTypeParameterHost()
			}
			params[i] = ttp;
		}

		return params;
	}

	// Fields

	function readClassFieldForward():ClassField {
		return {
			name: readString(),
			pos: readPos(),
			namePos: readPos(),
			overloads: readList(readClassFieldForward)
		}
	}

	function readEnumFieldForward():EnumField {
		return {
			name: readString(),
			pos: readPos(),
			namePos: readPos(),
			index: readUleb128()
		}
	}

	// Chunks

	function readSTR() {
		final length = readUleb128();
		stringPool = new Vector(length);
		for (index in 0...length) {
			stringPool[index] = i.readString(readUleb128());
		}
		return {
			strings: stringPool
		}
	}

	function readMDF() {
		return {
			path: readPath(),
			file: readString(),
			numAnons: readUleb128(),
			numMonos: readUleb128()
		};
	}

	function readMTF() {
		final types = readList(function() {
			final kind = i.readByte();
			final m = {
				path: readPath(),
				pos: readPos(),
				namePos: readPos(),
				params: readTypeParametersForward()
			}

			final kind = switch (kind) {
				case 0:
					final c = {
						flags: readUleb128(),
						constructor: readOption(readClassFieldForward),
						fields: readList(readClassFieldForward),
						statics: readList(readClassFieldForward),
					}
					Class(c);
				case 1:
					final en = {
						fields: readList(readEnumFieldForward)
					}
					Enum(en);
				case 2:
					final td = {}
					Typedef(td);
				case 3:
					final a = {}
					Abstract(a);
				case i:
					fail('Unknown module type byte: $i');
			}
			return {
				m: m,
				kind: kind
			}
		});

		return {
			types: types
		}
	}

	function readCLR() {
		final length = readUleb128();
		classes = new Vector(length);
		for (index in 0...length) {
			final path = readFullPath();
			classes[index] = switch (api.resolveModuleType(path.pack, path.name, path.typeName)) {
				case Some({m: m, kind: Class(c)}): {m: m, c: c};
				case Some(_): fail('Unexpected type where class was expected: ${Tools.joinFullPath(path)}');
				case None: fail('Could not resolve module type ${Tools.joinFullPath(path)}');
			}
		}
	}

	function readENR() {
		final length = readUleb128();
		enums = new Vector(length);
		for (index in 0...length) {
			final path = readFullPath();
			enums[index] = switch (api.resolveModuleType(path.pack, path.name, path.typeName)) {
				case Some({m: m, kind: Enum(en)}): {m: m, en: en};
				case Some(_): fail('Unexpected type where enum was expected: ${Tools.joinFullPath(path)}');
				case None: fail('Could not resolve module type ${Tools.joinFullPath(path)}');
			}
		}
	}

	function readABR() {
		final length = readUleb128();
		abstracts = new Vector(length);
		for (index in 0...length) {
			final path = readFullPath();
			abstracts[index] = switch (api.resolveModuleType(path.pack, path.name, path.typeName)) {
				case Some({m: m, kind: Abstract(a)}): {m: m, a: a};
				case Some(_): fail('Unexpected type where abstract was expected: ${Tools.joinFullPath(path)}');
				case None: fail('Could not resolve module type ${Tools.joinFullPath(path)}');
			}
		}
	}

	function readTDR() {
		final length = readUleb128();
		typedefs = new Vector(length);
		for (index in 0...length) {
			final path = readFullPath();
			typedefs[index] = switch (api.resolveModuleType(path.pack, path.name, path.typeName)) {
				case Some({m: m, kind: Typedef(td)}): {m: m, td: td};
				case Some(_): fail('Unexpected type where typedef was expected: ${Tools.joinFullPath(path)}');
				case None: fail('Could not resolve module type ${Tools.joinFullPath(path)}');
			}
		}
	}

	function readAFR() {
		anonFields = new Vector(readUleb128());
		for (k in 0...anonFields.length) {
			anonFields[k] = readClassFieldForward();
		}
	}

	function readChunkData<T>(kind:ChunkKind, size:Int) {
		switch (kind) {
			case STR:
				readSTR();
			case MDF:
				final mdf = readMDF();
				module = {
					MDF: mdf,
					MTF: null,
				};
				api.addModule(module);
			case MTF:
				module.MTF = readMTF();
			case CLR:
				readCLR();
			case ENR:
				readENR();
			case ABR:
				readABR();
			case TDR:
				readTDR();
			case AFR:
				readAFR();
			case EOM:

			case _:
				if (size > 0) {
					final buffer = Bytes.alloc(size);
					i.readBytes(buffer, 0, size);
				}
		}
	}

	public function read(api:ReaderApi) {
		this.api = api;
		this.module = null;
		final magic = i.readString(3);
		if (magic != "hxb") {
			fail('Expected magic to be hxb, but it is $magic');
		}
		final version = i.readByte();
		while (true) {
			final chunkName = i.readString(3);
			final chunkSize = i.readInt32();
			final chunkKind = ChunkKind.fromString(chunkName);
			if (chunkKind == EOM) {
				break;
			}
			readChunkData(chunkKind, chunkSize);
		}
		return module;
	}
}
