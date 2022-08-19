package format.ico;

import format.ico.Data;

class Tools {

	/**
	 extract DIB to [R, G, B, A, ...] format
	*/
	static public function extract( bmp : DIB ) : Uint8Array {
		var source = bmp.data;
		var height = bmp.height;
		var colors = bmp.colors;
		var stride = bmp.info.bytesPerline();
		var output = new Uint8Array(bmp.width * height * 4);
		var base = bmp.ixor;
		var index = 0;
		var column : Int;
		var starts : Int;
		switch (bmp.info.bitCount >> 2) { // shrink switch table
		case 0: // 1bits
			var mask = bmp.iand;
			var realWidth = bmp.width >> 3;
			while (--height >= 0) {
				starts = height * stride;
				column = 0;
				while (column < realWidth) {
					var pos = starts + column++;
					var icx = source.get(base + pos);
					var mak = source.get(mask + pos);
					var bits = 8;
					while(--bits >= 0) {
						index = write(output, index, colors[(icx >> bits) & 1], (mak >> bits) & 1);
					}
				}
			}
		case 1: // 4bits
			var masks = buildMasks(bmp);
			while (--height >= 0) {
				starts = height * stride;
				column = 0;
				while (column < stride) {
					var pos = starts + column++;
					var icx = source.get(base + pos);
					index = write(output, index, colors[(icx >> 4) & 15], masks[(pos << 1) + 0]);
					index = write(output, index, colors[(icx >> 0) & 15], masks[(pos << 1) + 1]);
				}
			}
		case 2: // 8bits
			var masks = buildMasks(bmp);
			while (--height >= 0) {
				starts = height * stride;
				column = 0;
				while (column < stride) {
					var pos = starts + column++;
					var icx = source.get(base + pos);
					index = write(output, index, colors[icx], masks[pos]);
				}
			}
		case 6: // 24bits with 1 alpha bit
			var masks = buildMasks(bmp);
			var ptrmak = 0;
			while (--height >= 0) {
				starts = height * stride + base;
				ptrmak = height * bmp.width;
				column = 0;
				while (column < stride) {
					output[index++] = source.get(starts + column + 2);
					output[index++] = source.get(starts + column + 1);
					output[index++] = source.get(starts + column + 0);
					output[index++] = masks[ptrmak] - 1; //  m == 1 ? 0 : -1;
					column += 3;
					ptrmak ++;
				}
			}
		case 8: // 32bits
			while (--height >= 0) {
				starts = base + height * stride;
				column = 0;
				while (column < stride) {
					var argb = source.getInt32(starts + column);
					output[index++] = (argb >> 16) & 0xFF;
					output[index++] = (argb >>  8) & 0xFF;
					output[index++] = (argb >>  0) & 0xFF;
					output[index++] = (argb >> 24) & 0xFF;
					column += 4;
				}
			}
		default:
		}
		return output;
	}

	static function write( output : Uint8Array, i : Int, rgb : Int, ts : Int ) : Int {
		if (ts == 1) {
			output[i + 3] = 0;
			return i + 4;
		}
		output[i++] = (rgb >> 16) & 0xFF;
		output[i++] = (rgb >>  8) & 0xFF;
		output[i++] = rgb & 0xFF;
		output[i++] = 0xFF;
		return i;
	}

	static function buildMasks( bmp : DIB ) : Uint8Array { //
		var data = bmp.data;
		var base = bmp.iand;
		var width = bmp.height;
		var height = bmp.height;
		var realWidth = width >> 3;
		var stride = BMPInfo.WIDTHBYTES(width);
		var output = new Uint8Array(height * width);
		var i = 0;
		var h = 0;
		while(h < height) {
			var column = 0;
			var starts = base + h * stride;
			while(column < realWidth) {
				var mark = data.get(starts + column++);
				var bits = 8;
				while (--bits >= 0) {
					output[i++] = (mark >> bits) & 1;
				}
			}
			h++;
		}
		return output;
	}
}

#if js
typedef Uint8ArrayInner = js.lib.Uint8Array;
#elseif hl
typedef Uint8ArrayInner = hl.Bytes;
#else
typedef Uint8ArrayInner = haxe.io.Bytes;
#end

@:pure
@:forward(length)
extern abstract Uint8Array(Uint8ArrayInner) to Uint8ArrayInner {
#if (js || hl)
	inline function new( size : Int ) this = new Uint8ArrayInner(size);

	@:arrayAccess inline private function get( pos : Int ) : Int return this[pos];

	@:arrayAccess inline private function set( pos : Int, value : Int ) : Int return this[pos] = value;

#else
	inline function new( size : Int ) this = haxe.io.Bytes.alloc(size);

	@:arrayAccess inline private function get( pos : Int ) : Int {
		return this.get(pos);
	}

	@:arrayAccess inline private function set( pos : Int, value : Int ) : Int {
		this.set(pos, value);
		return value;
	}
#end
}
