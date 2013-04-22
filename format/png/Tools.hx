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

	static inline function filter( rgba : #if flash10 format.tools.MemoryBytes #else haxe.io.Bytes #end, x, y, stride, prev, p ) {
		var b = rgba.get(p - stride);
		var c = x == 0 || y == 0  ? 0 : rgba.get(p - stride - 4);
		var k = prev + b - c;
		var pa = k - prev; if( pa < 0 ) pa = -pa;
		var pb = k - b; if( pb < 0 ) pb = -pb;
		var pc = k - c; if( pc < 0 ) pc = -pc;
		return (pa <= pb && pa <= pc) ? prev : (pb <= pc ? b : c);
	}

	@:noDebug
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
			var width = h.width;
			var stride = (alpha ? 4 : 3) * width + 1;
			if( data.length < h.height * stride ) throw "Not enough data";

			#if flash10
			var bytes = data.getData();
			var start = h.height * stride;
			bytes.length = start + h.width * h.height * 4;
			if( bytes.length < 1024 ) bytes.length = 1024;
			flash.Memory.select(bytes);
			var realData = data, realRgba = rgba;
			var data = format.tools.MemoryBytes.make(0);
			var rgba = format.tools.MemoryBytes.make(start);
			#end

			for( y in 0...h.height ) {
				var f = data.get(r++);
				switch( f ) {
				case 0:
					if( alpha )
						for( x in 0...width ) {
							rgba.set(w++,data.get(r+2));
							rgba.set(w++,data.get(r+1));
							rgba.set(w++,data.get(r));
							rgba.set(w++,data.get(r+3));
							r += 4;
						}
					else
						for( x in 0...width ) {
							rgba.set(w++,0xFF);
							rgba.set(w++,data.get(r+2));
							rgba.set(w++,data.get(r+1));
							rgba.set(w++,data.get(r));
							r += 3;
						}
				case 1:
					var cr = 0, cg = 0, cb = 0, ca = 0;
					if( alpha )
						for( x in 0...width ) {
							cr += data.get(r + 2);	rgba.set(w++,cr);
							cg += data.get(r + 1);	rgba.set(w++,cg);
							cb += data.get(r);		rgba.set(w++,cb);
							ca += data.get(r + 3);	rgba.set(w++,ca);
							r += 4;
						}
					else
						for( x in 0...width ) {
							rgba.set(w++, 0xFF);
							cr += data.get(r + 2);	rgba.set(w++,cr);
							cg += data.get(r + 1);	rgba.set(w++,cg);
							cb += data.get(r);		rgba.set(w++,cb);
							r += 3;
						}
				case 2:
					var stride = y == 0 ? 0 : width * 4;
					if( alpha )
						for( x in 0...width ) {
							rgba.set(w, data.get(r + 2) + rgba.get(w - stride));	w++;
							rgba.set(w, data.get(r + 1) + rgba.get(w - stride));	w++;
							rgba.set(w, data.get(r) + rgba.get(w - stride));		w++;
							rgba.set(w, data.get(r + 3) + rgba.get(w - stride));	w++;
							r += 4;
						}
					else
						for( x in 0...width ) {
							rgba.set(w++,0xFF);
							rgba.set(w, data.get(r + 2) + rgba.get(w - stride));	w++;
							rgba.set(w, data.get(r + 1) + rgba.get(w - stride));	w++;
							rgba.set(w, data.get(r) + rgba.get(w - stride));		w++;
							r += 3;
						}
				case 3:
					var cr = 0, cg = 0, cb = 0, ca = 0;
					var stride = y == 0 ? 0 : width * 4;
					if( alpha )
						for( x in 0...width ) {
							cr = (data.get(r + 2) + ((cr + rgba.get(w - stride)) >> 1)) & 0xFF;	rgba.set(w++, cr);
							cg = (data.get(r + 1) + ((cg + rgba.get(w - stride)) >> 1)) & 0xFF;	rgba.set(w++, cg);
							cb = (data.get(r + 0) + ((cb + rgba.get(w - stride)) >> 1)) & 0xFF;	rgba.set(w++, cb);
							ca = (data.get(r + 3) + ((ca + rgba.get(w - stride)) >> 1)) & 0xFF;	rgba.set(w++, ca);
							r += 4;
						}
					else
						for( x in 0...width ) {
							rgba.set(w++, 0xFF);
							cr = (data.get(r + 2) + ((cr + rgba.get(w - stride)) >> 1)) & 0xFF;	rgba.set(w++, cr);
							cg = (data.get(r + 1) + ((cg + rgba.get(w - stride)) >> 1)) & 0xFF;	rgba.set(w++, cg);
							cb = (data.get(r + 0) + ((cb + rgba.get(w - stride)) >> 1)) & 0xFF;	rgba.set(w++, cb);
							r += 3;
						}
				case 4:
					var stride = width * 4;
					var cr = 0, cg = 0, cb = 0, ca = 0;
					if( alpha )
						for( x in 0...width ) {
							cr = (filter(rgba, x, y, stride, cr, w) + data.get(r + 2)) & 0xFF; rgba.set(w++, cr);
							cg = (filter(rgba, x, y, stride, cg, w) + data.get(r + 1)) & 0xFF; rgba.set(w++, cg);
							cb = (filter(rgba, x, y, stride, cb, w) + data.get(r + 0)) & 0xFF; rgba.set(w++, cb);
							ca = (filter(rgba, x, y, stride, ca, w) + data.get(r + 3)) & 0xFF; rgba.set(w++, ca);
							r += 4;
						}
					else
						for( x in 0...width ) {
							rgba.set(w++, 0xFF);
							cr = (filter(rgba, x, y, stride, cr, w) + data.get(r + 2)) & 0xFF; rgba.set(w++, cr);
							cg = (filter(rgba, x, y, stride, cg, w) + data.get(r + 1)) & 0xFF; rgba.set(w++, cg);
							cb = (filter(rgba, x, y, stride, cb, w) + data.get(r + 0)) & 0xFF; rgba.set(w++, cb);
							r += 3;
						}
				default:
					throw "Invalid filter "+f;
				}
			}

			#if flash10
			var b = realRgba.getData();
			b.position = 0;
			b.writeBytes(realData.getData(), start, h.width * h.height * 4);
			#end

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