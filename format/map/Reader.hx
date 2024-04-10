package format.map;

import format.map.Data;
using format.map.Vlq;

class Reader {
    var input : haxe.io.Input;
    var data: Data;

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

    public function new() {}

    public function read( i : haxe.io.Input ) : Data {
		this.input = i;
        var content = i.readUntil("}".code) + "}";
        parse(content);

        return data;
    }

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
				pos = mapping.getSourcePos(data, line);
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
				callback(mapping.getSourcePos(data, line + 1));
			}
		}
	}

	/**
	 * Parse raw source map data
	 * @param json - Raw content of source map file
	 */
	function parse (json:String) {
		data = haxe.Json.parse(json);
		if (data == null) throw new SourceMapException("Failed to parse source map data.");

		version = data.version;
		file = data.file;
		sourceRoot = (data.sourceRoot == null ? '' : data.sourceRoot);
		sources = data.sources;
		sourcesContent = (data.sourcesContent == null ? [] : data.sourcesContent);
		names = data.names;

		var encoded = data.mappings.split(';');
		//help some platforms to pre-alloc array
		mappings[encoded.length - 1] = null;

		var previousSource = 0;
		var previousLine = 0;
		var previousColumn = 0;
		var previousName = 0;

		for (l in 0...encoded.length) {
			mappings[l] = [];
			if (encoded[l].length == 0) continue;

			var previousGeneratedColumn = 0;

			var segments = encoded[l].split(',');
			mappings[l][segments.length - 1] = null;

			for (s in 0...segments.length) {
				var mapping = new Mapping(segments[s].decode());
				mappings[l][s] = mapping;
				mapping.offsetGeneratedColumn(previousGeneratedColumn);
				if (mapping.hasSource()) {
					mapping.offsetSource(previousSource);
					mapping.offsetLine(previousLine);
					mapping.offsetColumn(previousColumn);
					if (mapping.hasName()) {
						mapping.offsetName(previousName);
						previousName = mapping.name;
					}
					previousLine = mapping.line;
					previousSource = mapping.source;
					previousColumn = mapping.column;
				}
				previousGeneratedColumn = mapping.generatedColumn;
			}
		}
	}
}