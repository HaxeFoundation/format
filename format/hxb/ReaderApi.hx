package format.hxb;

import format.hxb.Data;
import haxe.ds.Option;

interface ReaderApi {
	function addModule(module:Module):Void;
	function resolveModuleType(pack:Array<String>, moduleName:String, typeName:String):Option<ModuleTypeWithKind>;
}
