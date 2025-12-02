import format.hxb.ReaderApi;
import format.hxb.Data;
import format.hxb.Tools;
import haxe.zip.Entry;
import haxe.io.Input;
import haxe.io.BytesInput;
import haxe.ds.Option;
import haxe.io.Bytes;

using StringTools;

class Api implements ReaderApi {
	var moduleCache:Map<String, Module> = new Map();
	var binaryCache:Map<String, Bytes> = new Map();

	public function new() {}

	function modulePath(module:Module) {
		return Tools.joinPath(module.MDF.path);
	}

	public function addModule(module:Module) {
		moduleCache[modulePath(module)] = module;
	}

	function findTypeInModule(module:Module, typeName:String) {
		for (moduleType in module.MTF.types) {
			if (moduleType.m.path.name == typeName) {
				return Some(moduleType);
			}
		}

		return None;
	}

	public function resolveModuleType(pack:Array<String>, moduleName:String, typeName:String) {
		final moduleKey = Tools.joinPackAndName(pack, moduleName);
		final module = moduleCache[moduleKey];
		if (module != null) {
			return findTypeInModule(module, typeName);
		} else {
			final bytes = binaryCache[moduleKey];
			if (bytes == null) {
				return None;
			}
			final module = readHxb(bytes);
			moduleCache[modulePath(module)] = module;
			return findTypeInModule(module, typeName);
		}
	}

	public function addHxb(pack:Array<String>, moduleName:String, data:Bytes) {
		final moduleKey = Tools.joinPackAndName(pack, moduleName);
		binaryCache[moduleKey] = data;
	}

	function readHxb(data:Bytes) {
		var i = new BytesInput(data);
		var reader = new format.hxb.Reader(i);
		var res = reader.read(this);
		i.close();
		return res;
	}
}

function main() {
	var api = new Api();

	var input:Input = sys.io.File.read("tests/hxb/eval.zip");
	// input = new BytesInput(input.readAll());
	try {
		var zip = haxe.zip.Reader.readZip(input);
		for (entry in zip) {
			var path = new haxe.io.Path(entry.fileName);
			var targetedPack = path.dir.split("/");
			var target = targetedPack.shift();
			if (target != "eval") {
				continue;
			}
			api.addHxb(targetedPack, path.file, entry.data);
		}
	} catch (e:Dynamic) {
		trace(e);
	}
	input.close();

	var template = api.resolveModuleType(["haxe"], "Template", "Template");
	// var template = api.resolveModuleType(["haxe", "macro"], "Expr", "ExprDef");
	switch (template) {
		case Some(mt = {kind: Class(c)}):
			Sys.println(Tools.joinPath(mt.m.path));
			Sys.println("    fields:");
			for (cf in c.fields) {
				Sys.println("        " + cf.name);
			}
			Sys.println("    statics:");
			for (cf in c.statics) {
				Sys.println("        " + cf.name);
			}
		case _:
	}
}
