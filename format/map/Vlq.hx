package format.map;

using StringTools;

class Vlq {
	static inline var SHIFT = 5;
	static inline var MASK = (1 << SHIFT) - 1;

	/**
	 * Get a number in range 0...64 (excluding)
	 * @param charCode - A code of a valid base64 character. It's not verified, so be sure it's a valid character.
	 * @return Int
	 */
	static inline function base64Decode (charCode:Int):Int {
		if ('a'.code <= charCode) return charCode - 'a'.code + 26; //26 is the position of `a` in base64 alphabet
		if ('A'.code <= charCode) return charCode - 'A'.code;
		if ('0'.code <= charCode) return charCode - '0'.code + 52; //52 is the position of `0` in base64 alphabet
		if (charCode == '+'.code) return 62;
		return 63; // `/`
	}

	static public inline function decode (vlq:String):Array<Int> {
		var data = [];
		var index = -1;
		var lastIndex = vlq.length - 1;
		while(index < lastIndex) {
			var value = 0;
			var shift = 0;
			var digit, masked;
			do {
				if(index >= lastIndex) {
					throw new format.map.SourceMapException('Failed to parse vlq: $vlq');
				}
				digit = base64Decode(vlq.fastCodeAt(++index));
				masked = digit & MASK;
				value += masked << shift;
				shift += SHIFT;
			} while(digit != masked);

			//the least significant bit in VLQ is used to store a sign
			data.push(value & 1 == 1 ? -(value >> 1) : value >> 1);
		}

		return data;
	}
}