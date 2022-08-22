package format.ico;

import format.ico.Data;
import format.ico.DIB;

class Tools {

	/**
	* extract DIB to [R, G, B, A, ...] format
	*/
	static public function extract( bmp : DIB ) : Uint8Array {
		// fast reference
		var ixor = bmp.ixor;
		var source = bmp.data;
		var height = bmp.height;
		var colors = bmp.colors;

		var stride = bmp.info.bytesPerline();
		var output = new Uint8Array(bmp.width * height * 4);
		var byteWidth = (bmp.width * bmp.info.bitCount) + 7 >> 3;
		var index = 0;
		var column : Int;
		var starts : Int;

		switch (bmp.info.bitCount >> 2) { // shrink switch table
		case 0: // 1bits
			var iand = bmp.iand;
			var rowlen = bmp.width * 4;
			var limits = rowlen;
			while (--height >= 0) {
				starts = height * stride;
				column = 0;
				while (column < byteWidth) {
					var pos = starts + column++;
					var icx = source.get(ixor + pos);
					var mak = source.get(iand + pos);
					var bits = 8;
					while (--bits >= 0 && index < limits) {
						var rgb = colors[icx >> bits & 1];
						output[index++] = rgb >> 16 & 0xFF;
						output[index++] = rgb >>  8 & 0xFF;
						output[index++] = rgb & 0xFF;
						output[index++] = (mak >> bits & 1) - 1;
					}
				}
				limits += rowlen;
			}
		case 1: // 4bits
			copyAlphaChannel(output, bmp);
			while (--height >= 0) {
				starts = ixor + height * stride;
				column = 0;
				while (column < byteWidth) {
					var icx = source.get(starts + column++);
					writeRGB(output, index, colors[(icx >> 4) & 15]);
					index += 4;

					// if the iamge width is not multiple of 2
					if (column == byteWidth && (byteWidth & 1) == 1)
						break;

					writeRGB(output, index, colors[(icx     ) & 15]);
					index += 4;
				}
			}
		case 2: // 8bits
			copyAlphaChannel(output, bmp);
			while (--height >= 0) {
				starts = ixor + height * stride;
				column = 0;
				while (column < byteWidth) {
					var icx = source.get(starts + column++);
					writeRGB(output, index, colors[icx]);
					index += 4;
				}
			}
		case 6: // 24bits with 1 alpha bit
			copyAlphaChannel(output, bmp);
			while (--height >= 0) {
				starts = ixor + height * stride;
				column = 0;
				while (column < byteWidth) {
					output[index    ] = source.get(starts + column + 2);
					output[index + 1] = source.get(starts + column + 1);
					output[index + 2] = source.get(starts + column    );
					index  += 4;
					column += 3;
				}
			}
		case 8: // 32bits, NOTE: it still has the unused alpha table in "bmp.iand"
			while (--height >= 0) {
				starts = ixor + height * stride;
				column = 0;
				while (column < byteWidth) {
					var argb = source.getInt32(starts + column);
					output[index++] = (argb >> 16) & 0xFF;
					output[index++] = (argb >>  8) & 0xFF;
					output[index++] = (argb      ) & 0xFF;
					output[index++] = (argb >> 24) & 0xFF;
					column += 4;
				}
			}
		default:
		}
		return output;
	}

	static function writeRGB( output : Uint8Array, i : Int, rgb : Int ) : Void {
		if (output[i + 3] == 0)
			return;
		output[i++] = (rgb >> 16) & 0xFF;
		output[i++] = (rgb >>  8) & 0xFF;
		output[i] = rgb & 0xFF;
	}

	static function copyAlphaChannel( output : Uint8Array, bmp : DIB ) : Void {
		var data = bmp.data;
		var iand = bmp.iand;
		var stride = BMPInfo.WIDTHBYTES(bmp.width);
		var rowlen = bmp.width * 4;
		var height = bmp.height;
		var limits = rowlen;
		var i = 3;
		while (--height >= 0) {
			var column = 0;
			var starts = iand + height * stride;
			while (column < stride) {
				var mark = data.get(starts + column++);
				var bits = 8;
				while (--bits >= 0 && i < limits) {
					output[i] = ((mark >> bits) & 1) - 1; // if (1) then 0 else -1
					i += 4;
				}
			}
			limits += rowlen;
		}
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
