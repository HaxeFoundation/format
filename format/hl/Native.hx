package format.hl;

enum abstract PixelFormat(Int) {
	var RGB = 0;
	var BGR = 1;
	var RGBX = 2;
	var BGRX = 3;
	var XBGR = 4;
	var XRGB = 5;
	var GRAY = 6;
	var RGBA = 7;
	var BGRA = 8;
	var ABGR = 9;
	var ARGB = 10;
	var CMYK = 11;
}

class Native {

#if hl
	/**
		Decode JPG data into the target buffer.
	**/
	@:hlNative("fmt", "jpg_decode")
	public static function decodeJPG(src:hl.Bytes, srcLen:Int, dst:hl.Bytes, width:Int, height:Int, stride:Int, format:PixelFormat, flags:Int):Bool {
		return false;
	}

	/**
		Decode PNG data into the target buffer.
	**/
	@:hlNative("fmt", "png_decode")
	public static function decodePNG(src:hl.Bytes, srcLen:Int, dst:hl.Bytes, width:Int, height:Int, stride:Int, format:PixelFormat, flags:Int):Bool {
		return false;
	}

	/**
		Decode any image data into ARGB pixels
	**/
	#if (hl_ver >= version("1.10.0"))
	@:hlNative("fmt", "dxt_decode")
	public static function decodeDXT(src:hl.Bytes, dst:hl.Bytes, width:Int, height:Int, dxtFormat:Int):Bool {
		return false;
	}
	#end

	/**
		Upscale/downscale an image.
		Currently supported flag bits: 1 = bilinear filtering
	**/
	@:hlNative("fmt", "img_scale")
	public static function scaleImage(out:hl.Bytes, outPos:Int, outStride:Int, outWidth:Int, outHeight:Int, _in:hl.Bytes, inPos:Int, inStride:Int,
		inWidth:Int, inHeight:Int, flags:Int) {}

#end
}
