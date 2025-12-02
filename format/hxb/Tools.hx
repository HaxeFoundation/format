package format.hxb;

import format.hxb.Data;

class Tools {
	static public function joinPackAndName(pack:Array<String>, name:String) {
		return (pack.length == 0 ? name : pack.join(".") + "." + name);
	}

	static public function joinPath(path:Path) {
		return joinPackAndName(path.pack, path.name);
	}

	static public function joinFullPath(path:FullPath) {
		return joinPackAndName(path.pack, path.name) + "." + path.typeName;
	}
}
