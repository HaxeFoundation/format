/*
 * format - haXe File Formats
 *
 * Copyright (c) 2008-2009, The haXe Project Contributors
 * All rights reserved.
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 *   - Redistributions of source code must retain the above copyright
 *     notice, this list of conditions and the following disclaimer.
 *   - Redistributions in binary form must reproduce the above copyright
 *     notice, this list of conditions and the following disclaimer in the
 *     documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE HAXE PROJECT CONTRIBUTORS "AS IS" AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE HAXE PROJECT CONTRIBUTORS BE LIABLE FOR
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 * CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH
 * DAMAGE.
 */
package format.png;
import format.png.Data;

class Tools {

	public static function getHeader( d : Data ) : Header {
		for( c in d )
			switch( c ) {
			case CHeader(h): return h;
			default:
			}
		throw "Header not found";
	}

	public static function extract32( d : Data ) : haxe.io.Bytes {
		var h = getHeader(d);
		var rgba = haxe.io.Bytes.alloc(h.width * h.height * 4);
		var data = null;
		var fullData : haxe.io.BytesBuffer = null;
		for( c in d )
			switch( c ) {
			case CData(b):
				if( fullData != null )
					fullData.add(b);
				else if( data == null )
					data = b;
				else {
					fullData = new haxe.io.BytesBuffer();
					fullData.add(data);
					fullData.add(b);
					data = null;
				}
			default:
			}
		if( fullData != null )
			data = fullData.getBytes();
		if( data == null )
			throw "Data not found";
		data = format.tools.Inflate.run(data);
		var r = 0, w = 0;
		switch( h.color ) {
		case ColTrue(alpha):
			if( h.colbits != 8 )
				throw "Unsupported color mode";
			var stride = (alpha ? 4 : 3) * h.width + 1;
			if( data.length < h.height * stride ) throw "Not enough data";
			for( y in 0...h.height ) {
				if( data.get(r++) != 0 )
					throw "Filters are not supported";
				if( alpha )
					for( x in 0...h.width ) {
						rgba.set(w++,data.get(r+2));
						rgba.set(w++,data.get(r+1));
						rgba.set(w++,data.get(r));
						rgba.set(w++,data.get(r+3));
						r += 4;
					}
				else
					for( x in 0...h.width ) {
						rgba.set(w++,0xFF);
						rgba.set(w++,data.get(r+2));
						rgba.set(w++,data.get(r+1));
						rgba.set(w++,data.get(r));
						r += 3;
					}
			}
		default:
			throw "Unsupported color mode "+Std.string(h.color);
		}
		return rgba;
	}

	public static function build24( width : Int, height : Int, data : haxe.io.Bytes ) : Data {
		var rgb = haxe.io.Bytes.alloc(width * height * 3 + height);
		// translate RGB to BGR and add filter byte
		var w = 0, r = 0;
		for( y in 0...height ) {
			rgb.set(w++,0); // no filter for this scanline
			for( x in 0...width ) {
				rgb.set(w++,data.get(r+2));
				rgb.set(w++,data.get(r+1));
				rgb.set(w++,data.get(r));
				r += 3;
			}
		}
		var l = new List();
		l.add(CHeader({ width : width, height : height, colbits : 8, color : ColTrue(false), interlaced : false }));
		l.add(CData(format.tools.Deflate.run(rgb)));
		l.add(CEnd);
		return l;
	}
	
	public static function build32BE( width : Int, height : Int, data : haxe.io.Bytes ) : Data {
		var rgba = haxe.io.Bytes.alloc(width * height * 4 + height);
		// translate ARGB to RGBA and add filter byte
		var w = 0, r = 0;
		for( y in 0...height ) {
			rgba.set(w++,0); // no filter for this scanline
			for( x in 0...width ) {
				rgba.set(w++,data.get(r+1)); // r
				rgba.set(w++,data.get(r+2)); // g
				rgba.set(w++,data.get(r+3)); // b
				rgba.set(w++,data.get(r)); // a
				r += 4;
			}
		}
		var l = new List();
		l.add(CHeader({ width : width, height : height, colbits : 8, color : ColTrue(true), interlaced : false }));
		l.add(CData(format.tools.Deflate.run(rgba)));
		l.add(CEnd);
		return l;
	}	

	public static function build32LE( width : Int, height : Int, data : haxe.io.Bytes ) : Data {
		var rgba = haxe.io.Bytes.alloc(width * height * 4 + height);
		// translate ARGB to RGBA and add filter byte
		var w = 0, r = 0;
		for( y in 0...height ) {
			rgba.set(w++,0); // no filter for this scanline
			for( x in 0...width ) {
				rgba.set(w++,data.get(r+2)); // r
				rgba.set(w++,data.get(r+1)); // g
				rgba.set(w++,data.get(r)); // b
				rgba.set(w++,data.get(r+3)); // a
				r += 4;
			}
		}
		var l = new List();
		l.add(CHeader({ width : width, height : height, colbits : 8, color : ColTrue(true), interlaced : false }));
		l.add(CData(format.tools.Deflate.run(rgba)));
		l.add(CEnd);
		return l;
	}

}