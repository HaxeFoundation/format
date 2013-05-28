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

	static inline function filter( rgba : #if flash10 format.tools.MemoryBytes #else haxe.io.Bytes #end, x, y, stride, prev, p, numChannels ) {
		var b = rgba.get(p - stride);
		var c = x == 0 || y == 0  ? 0 : rgba.get(p - stride - numChannels);
		var k = prev + b - c;
		var pa = k - prev; if( pa < 0 ) pa = -pa;
		var pb = k - b; if( pb < 0 ) pb = -pb;
		var pc = k - c; if( pc < 0 ) pc = -pc;
		return (pa <= pb && pa <= pc) ? prev : (pb <= pc ? b : c);
	}

	@:noDebug
	public static function extract(d:Data, channels:Array<Int>):haxe.io.Bytes {
		var numChannels = channels.length;
		var h = getHeader(d);
		var out = haxe.io.Bytes.alloc(h.width * h.height * numChannels);
		var data = null;
		var fullData:haxe.io.BytesBuffer = null;
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

		if (h.colbits != 8)
			throw "Unsupported color mode";

		var width = h.width;
		var stride = (switch(h.color) {
			case ColGrey(alpha): alpha ? 2 : 1;
			case ColTrue(alpha): alpha ? 4 : 3;
			default:
				throw "Unsupported color mode "+Std.string(h.color);
				0;
		}) * width + 1;
		if (data.length < h.height * stride) throw "Not enough data";

		#if flash10
		var bytes = data.getData();
		var start = h.height * stride;
		bytes.length = start + h.width * h.height * numChannels;
		if( bytes.length < 1024 ) bytes.length = 1024;
		flash.Memory.select(bytes);
		var realData = data, realOut = out;
		var data = format.tools.MemoryBytes.make(0);
		var out = format.tools.MemoryBytes.make(start);
		#end

		var r = 0, w = 0;
		var cc = [for (i in 0...numChannels) 0];
		var cd = [0,0,0,0];
		switch (h.color) {
		case ColTrue(alpha):
			for( y in 0...h.height ) {
				var f = data.get(r++);
				switch( f ) {
				case 0:
					for (x in 0...width) {
						cd[0] = data.get(r++);
						cd[1] = data.get(r++);
						cd[2] = data.get(r++);
						cd[3] = alpha ? data.get(r++) : 0xff;
						for (c in channels) out.set(w++, cd[c]);
					}
				case 1:
					cd[0] = cd[1] = cd[2] = 0;
					cd[3] = alpha ? 0 : 0xff;
					for (x in 0...width) {
						cd[0] += data.get(r++);
						cd[1] += data.get(r++);
						cd[2] += data.get(r++);
						if (alpha) cd[3] += data.get(r++);
						for (c in channels) out.set(w++, cd[c]);
					}
				case 2:
					var stride = y == 0 ? 0 : width * numChannels;
					for (x in 0...width) {
						cd[0] = data.get(r++);
						cd[1] = data.get(r++);
						cd[2] = data.get(r++);
						cd[3] = alpha ? data.get(r++) : 0xff;
						for (c in channels) {
							out.set(w, cd[c] + out.get(w - stride));
							w++;
						}
					}
				case 3:
					for (i in 0...numChannels) cc[i] = 0;
					var stride = y == 0 ? 0 : width * numChannels;
					if (alpha) {
						for (x in 0...width) {
							cd[0] = data.get(r++);
							cd[1] = data.get(r++);
							cd[2] = data.get(r++);
							cd[3] = data.get(r++);
							var i = 0;
							for (c in channels) {
								cc[i] = (cd[c] + ((cc[i] + out.get(w-stride))>>1)) & 0xff;
								out.set(w++, cc[i++]);
							}
						}
					}else {
						for (x in 0...width) {
							cd[0] = data.get(r++);
							cd[1] = data.get(r++);
							cd[2] = data.get(r++);
							var i = 0;
							for (c in channels) {
								if (c < 3) {
									cc[i] = (cd[c] + ((cc[i] + out.get(w-stride))>>1)) & 0xff;
									out.set(w++, cc[i]);
								}
								else out.set(w++, 0xff);
								i++;
							}
						}
					}
				case 4:
					for (i in 0...numChannels) cc[i] = 0;
					var stride = width * numChannels;
					if (alpha) {
						for (x in 0...width) {
							cd[0] = data.get(r++);
							cd[1] = data.get(r++);
							cd[2] = data.get(r++);
							cd[3] = data.get(r++);
							var i = 0;
							for (c in channels) {
								cc[i] = (filter(out, x, y, stride, cc[i], w, numChannels) + cd[c]) & 0xff;
								out.set(w++, cc[i++]);
							}
						}
					}else {
						for (x in 0...width) {
							cd[0] = data.get(r++);
							cd[1] = data.get(r++);
							cd[2] = data.get(r++);
							var i = 0;
							for (c in channels) {
								if (c < 3) {
									cc[i] = (filter(out, x, y, stride, cc[i], w, numChannels) + cd[c]) & 0xff;
									out.set(w++, cc[i]);
								}
								else out.set(w++, 0xff);
								i++;
							}
						}
					}
				default:
					throw "Invalid filter "+f;
				}
			}
		case ColGrey(alpha):
			for( y in 0...h.height ) {
				var f = data.get(r++);
				switch( f ) {
				case 0:
					for (x in 0...width) {
						var rgb = data.get(r++);
						var a = alpha ? data.get(r++) : 0xff;
						for (c in channels) out.set(w++, c < 3 ? rgb : a);
					}
				case 1:
					var crgb = 0, ca = alpha ? 0 : 0xff;
					for (x in 0...width) {
						crgb += data.get(r++);
						if (alpha) ca += data.get(r++);
						for (c in channels) out.set(w++, c < 3 ? crgb : ca);
					}
				case 2:
					var stride = y == 0 ? 0 : width * numChannels;
					if (alpha) {
						for (x in 0...width) {
							var rgb = data.get(r++);
							var a = data.get(r++);
							for (c in channels) {
								out.set(w, (c < 3 ? rgb : a) + out.get(w - stride));
								w++;
							}
						}
					}else {
						for (x in 0...width) {
							var rgb = data.get(r++);
							for (c in channels) {
								if (c < 3) {
									out.set(w, rgb + out.get(w - stride));
									w++;
								}
								else out.set(w++, 0xff);
							}
						}
					}
				case 3:
					for (i in 0...numChannels) cc[i] = 0;
					var stride = y == 0 ? 0 : width * numChannels;
					if (alpha) {
						for (x in 0...width) {
							var rgb = data.get(r++);
							var a = data.get(r++);
							var i = 0;
							for (c in channels) {
								cc[i] = ((c < 3 ? rgb : a) + ((cc[i] + out.get(w-stride))>>1)) & 0xff;
								out.set(w++, cc[i++]);
							}
						}
					}else {
						for (x in 0...width) {
							var rgb = data.get(r++);
							var i = 0;
							for (c in channels) {
								if (c < 3) {
									cc[i] = (rgb + ((cc[i] + out.get(w-stride))>>1)) & 0xff;
									out.set(w++, cc[i]);
								}
								else out.set(w++, 0xff);
								i++;
							}
						}
					}
				case 4:
					for (i in 0...numChannels) cc[i] = 0;
					var stride = width * numChannels;
					if (alpha) {
						for (x in 0...width) {
							var rgb = data.get(r++);
							var a = data.get(r++);
							var i = 0;
							for (c in channels) {
								cc[i] = (filter(out, x, y, stride, cc[i], w, numChannels) + (c < 3 ? rgb : a)) & 0xff;
								out.set(w++, cc[i++]);
							}
						}
					}else {
						for (x in 0...width) {
							var rgb = data.get(r++);
							var i = 0;
							for (c in channels) {
								if (c < 3) {
									cc[i] = (filter(out, x, y, stride, cc[i], w, numChannels) + rgb) & 0xff;
									out.set(w++, cc[i]);
								}
								else out.set(w++, 0xff);
								i++;
							}
						}
					}
				default:
					throw "Invalid filter "+f;
				}
			}
		default:
		}

		#if flash10
		var b = realOut.getData();
		b.position = 0;
		b.writeBytes(realData.getData(), start, h.width * h.height * numChannels);
		#end

		return out;
	}

	public static function extract32( d : Data ) : haxe.io.Bytes {
		return extract(d, [0,1,2,3]);
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

