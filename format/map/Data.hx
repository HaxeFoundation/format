package format.map;

import haxe.DynamicAccess;

@:allow(format.map.Reader)
class Data {

	/** Specification version. The only supported version is 3. */
	public var version (default,null) : Int = 3;

	/** File with the generated code that this source map is associated with. */
	public var file (default,null) : Null<String>;

	/** This value is prepended to the individual entries in the `sources` field. */
	public var sourceRoot (default,null) : String = '';

	/** A list of original source files. */
	public var sources (default,null) : Array<String>;

	/** A list of contents of files mentioned in `sources` if those files cannot be hosted. */
	public var sourcesContent (default,null) : Array<String>;

	/** A list of symbol names used in `mappings` */
	public var names (default,null) : Array<String>;

	/** Decoded mappings data */
	var mappings : Array<Array<Mapping>> = [];

	function new() {}

	/**
	 * Get position in original source file.
	 * Returns `null` if provided `line` and/or `column` don't exist in compiled file.
	 * @param line - `1`-based line number in generated file.
	 * @param column - zero-based column number in generated file.
	 */
	 public function originalPositionFor (line:Int, column:Int = 0) : Null<SourcePos> {
		if (line < 1 || line > mappings.length) return null;

		var pos : SourcePos = null;
		for (mapping in mappings[line - 1]) {
			if (mapping.generatedColumn <= column) {
				pos = mapping.getSourcePos(this, line);
				break;
			}
		}

		return pos;
	}

	/**
	 * Invoke `callback` for each mapped position.
	 */
	public function eachMapping (callback:SourcePos->Void) {
		for (line in 0...mappings.length) {
			for (mapping in mappings[line]) {
				callback(mapping.getSourcePos(this, line + 1));
			}
		}
	}
}

/**
 * Structure of a raw source map data.
 */
 abstract DataRaw(DynamicAccess<Any>) to DynamicAccess<Any> {

	/** Specification version. The only supported version is 3. */
	public var version(get,never) : Int;

	/** File with the generated code that this source map is associated with. */
	public var file(get,never) : Null<String>;

	/** This value is prepended to the individual entries in the `sources` field. */
	public var sourceRoot(get,never) : Null<String>;

	/** A list of original source files. */
	public var sources(get,never) : Array<String>;

	/** A list of contents of files mentioned in `sources` if those files cannot be hosted. */
	public var sourcesContent(get,never) : Null<Array<String>>;

	/** A list of symbol names used in `mappings` */
	public var names(get,never) : Array<String>;

	/** Encoded mappings data. */
	public var mappings(get,never) : String;


	inline function get_version() : Int
		return this.get('version');

	inline function get_file() : Null<String>
		return this.get('file');

	inline function get_sourceRoot() : Null<String>
		return this.get('sourceRoot');

	inline function get_sources() : Array<String>
		return this.get('sources');

	inline function get_sourcesContent() : Null<Array<String>>
		return this.get('sourcesContent');

	inline function get_names() : Array<String>
		return this.get('names');

	inline function get_mappings() : String
		return this.get('mappings');
}

abstract SourcePos(DynamicAccess<Any>) to DynamicAccess<Any> {

	/** Original source file. */
	public var source(get,set) : Null<String>;

	/** "1"-based line in the original file. */
	public var originalLine(get,set) : Null<Int>;

	/** Zero-based starting column of the line in the original file. */
	public var originalColumn(get,set) : Null<Int>;

	/** Zero-based starting column of the line in the generated file. */
	public var generatedColumn(get,set) : Int;

	/** "1"-based line in the generated file. */
	public var generatedLine(get,set) : Int;

	/** Original symbol name. */
	public var name(get,set) : Null<String>;

	public function new() {
		this = {};
	}

	inline function get_source() : Null<String>
		return this.get('source');

	inline function set_source(v:Null<String>) : Null<String>
		return this.set('source', v);

	inline function get_originalLine() : Null<Int>
		return this.get('originalLine');

	inline function set_originalLine(v:Null<Int>) : Null<Int>
		return this.set('originalLine', v);

	inline function get_originalColumn() : Null<Int>
		return this.get('originalColumn');

	inline function set_originalColumn(v:Null<Int>) : Null<Int>
		return this.set('originalColumn', v);

	inline function get_generatedColumn() : Int
		return this.get('generatedColumn');

	inline function set_generatedColumn(v:Int) : Int
		return this.set('generatedColumn', v);

	inline function get_generatedLine() : Int
		return this.get('generatedLine');

	inline function set_generatedLine(v:Int) : Int
		return this.set('generatedLine', v);

	inline function get_name() : Null<String>
		return this.get('name');

	inline function set_name(v:Null<String>) : Null<String>
		return this.set('name', v);
}

/**
 * Represents each group in source map `mappings` field.
 */
 abstract Mapping(Array<Int>) {
	static inline var GENERATED_COLUMN = 0;
	static inline var SOURCE = 1;
	static inline var LINE = 2;
	static inline var COLUMN = 3;
	static inline var NAME = 4;

	/** Zero-based starting column of the line in the generated code */
	public var generatedColumn (get,never) : Int;
	/** Zero-based index into the `sources` list of source map */
	public var source (get,never) : Int;
	/** Zero-based starting line in the original source represented */
	public var line (get,never) : Int;
	/** Zero-based starting column of the line in the source represented */
	public var column (get,never) : Int;
	/** Zero-based index into the `names` list of source map */
	public var name (get,never) : Int;

	public inline function new (data:Array<Int>) {
		this = data;
	}

	public inline function getSourcePos (map:Data, generatedLine:Int) : SourcePos {
		var pos = new SourcePos();
		pos.generatedLine = generatedLine;
		pos.generatedColumn = generatedColumn;
		if (hasSource()) {
			pos.originalLine = line + 1;
			pos.originalColumn = column;
			pos.source = map.sourceRoot + map.sources[source];
			if (hasName()) {
				pos.name = map.names[name];
			}
		}
		return pos;
	}

	public inline function hasSource () : Bool return this.length > SOURCE;
	public inline function hasLine () : Bool return this.length > LINE;
	public inline function hasColumn () : Bool return this.length > COLUMN;
	public inline function hasName () : Bool return this.length > NAME;

	public inline function offsetGeneratedColumn (offset:Int) this[GENERATED_COLUMN] += offset;
	public inline function offsetSource (offset:Int) this[SOURCE] += offset;
	public inline function offsetLine (offset:Int) this[LINE] += offset;
	public inline function offsetColumn (offset:Int) this[COLUMN] += offset;
	public inline function offsetName (offset:Int) this[NAME] += offset;

	inline function get_generatedColumn () return this[GENERATED_COLUMN];
	inline function get_source () return this[SOURCE];
	inline function get_line () return this[LINE];
	inline function get_column () return this[COLUMN];
	inline function get_name () return this[NAME];
}
