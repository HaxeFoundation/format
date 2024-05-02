package format.map;

import format.map.Data;
using format.map.Vlq;

class Reader {
	var input : haxe.io.Input;

	public function new() {}
	public function read (i : haxe.io.Input) : Data {
		this.input = i;
		var content = i.readAll().toString();
		return parse(content);
	}

	/**
	 * Parse raw source map data
	 * @param json - Raw content of source map file
	 */
	public function parse (json:String): Data {
		var rawData: DataRaw = haxe.Json.parse(json);
		if (rawData == null) throw new SourceMapException("Failed to parse source map data.");

		var ret = new Data();
		ret.version = rawData.version;
		ret.file = rawData.file;
		ret.sourceRoot = (rawData.sourceRoot == null ? '' : rawData.sourceRoot);
		ret.sources = rawData.sources;
		ret.sourcesContent = (rawData.sourcesContent == null ? [] : rawData.sourcesContent);
		ret.names = rawData.names;


		var encoded = rawData.mappings.split(';');
		//help some platforms to pre-alloc array
		ret.mappings[encoded.length - 1] = null;

		var previousSource = 0;
		var previousLine = 0;
		var previousColumn = 0;
		var previousName = 0;

		for (l in 0...encoded.length) {
			ret.mappings[l] = [];
			if (encoded[l].length == 0) continue;

			var previousGeneratedColumn = 0;

			var segments = encoded[l].split(',');
			ret.mappings[l][segments.length - 1] = null;

			for (s in 0...segments.length) {
				var mapping = new Mapping(segments[s].decode());
				ret.mappings[l][s] = mapping;
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
		return ret;
	}
}