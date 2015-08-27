/*
 * format - haXe File Formats
 *
 *  BMP File Format
 *  Copyright (C) 2007-2009 Trevor McCauley, Baluta Cristian (hx port) & Robert Sköld (format conversion)
 *
 * Copyright (c) 2009, The haXe Project Contributors
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
package format.bmp;


class Tools {

	//												  a  r  g  b
	static var ARGB_MAP(default, never):Array<Int> = [0, 1, 2, 3];
	static var BGRA_MAP(default, never):Array<Int> = [3, 2, 1, 0];
	
	/**
		Extract BMP pixel data (24bpp in BGR format) and expands it to BGRA, removing any padding in the process.
	**/
	inline static public function extractBGRA( bmp : format.bmp.Data ) : haxe.io.Bytes {
		return _extract32(bmp, BGRA_MAP, 0xFF);
	}

	/**
		Extract BMP pixel data (24bpp in BGR format) and converts it to ARGB.
	**/
	inline static public function extractARGB( bmp : format.bmp.Data ) : haxe.io.Bytes {
		return _extract32(bmp, ARGB_MAP, 0xFF);
	}
  
	/**
		Creates BMP data from bytes in BGRA format for each pixel.
	**/
	inline static public function buildFromBGRA( width : Int, height : Int, srcBytes : haxe.io.Bytes, topToBottom : Bool = false ) : Data {
		return _buildFrom32(width, height, srcBytes, BGRA_MAP, topToBottom);
	}
  
	/**
		Creates BMP data from bytes in ARGB format for each pixel.
	**/
	inline static public function buildFromARGB( width : Int, height : Int, srcBytes : haxe.io.Bytes, topToBottom : Bool = false ) : Data {
		return _buildFrom32(width, height, srcBytes, ARGB_MAP, topToBottom);
	}

	inline static public function computePaddedStride(width:Int, bpp:Int):Int {
		return ((((width * bpp) + 31) & ~31) >> 3);
	}
	
	
	// `channelMap` contains indices to map into ARGB (f.e. the mapping for ARGB is [0,1,2,3], while for BGRA is [3,2,1,0])
	static function _extract32( bmp : format.bmp.Data, channelMap : Array<Int>, alpha : Int = 0xFF) : haxe.io.Bytes {
		var srcBytes = bmp.pixels;
		var dstLen = bmp.header.width * bmp.header.height * 4;
		var dstBytes = haxe.io.Bytes.alloc( dstLen );
		var srcStride = bmp.header.width * 3;
		var srcPaddedStride = bmp.header.paddedStride;
		
		var yDir = -1;
		var dstPos = 0;
		var srcPos = bmp.header.dataLength - srcPaddedStride;
    
		if ( bmp.header.topToBottom ) {
			yDir = 1;
			srcPos = 0;
		}
    
		while( dstPos < dstLen ) {
			var i = srcPos;
			while( i < srcPos + srcStride ) {
				var b = srcBytes.get(i + 0);
				var g = srcBytes.get(i + 1);
				var r = srcBytes.get(i + 2);
				
				dstBytes.set(dstPos + channelMap[0], alpha); // alpha
				dstBytes.set(dstPos + channelMap[1], r);
				dstBytes.set(dstPos + channelMap[2], g);
				dstBytes.set(dstPos + channelMap[3], b);
				
				i += 3;
				dstPos += 4;
			}
			srcPos += yDir * srcPaddedStride;
		}
		return dstBytes;
	}
	
	// `channelMap` contains indices to map into ARGB (f.e. the mapping for ARGB is [0,1,2,3], while for BGRA is [3,2,1,0])
	static function _buildFrom32( width : Int, height : Int, srcBytes : haxe.io.Bytes, channelMap : Array<Int>, topToBottom : Bool = false ) : Data {
		var bpp = 24;
		var paddedStride = computePaddedStride(width, bpp);
		var bytesBGR = haxe.io.Bytes.alloc(paddedStride * height);
		var topToBottom = topToBottom;
		var dataLength = bytesBGR.length;
		
		var dstStride = width * 3;
		var srcLen = width * height * 4;
		var yDir = -1;
		var dstPos = dataLength - paddedStride;
		var srcPos = 0;
		
		if ( topToBottom ) {
			yDir = 1;
			dstPos = 0;
		}
		
		while( srcPos < srcLen ) {
			var i = dstPos;
			while( i < dstPos + dstStride ) {
				var r = srcBytes.get(srcPos + channelMap[1]);
				var g = srcBytes.get(srcPos + channelMap[2]);
				var b = srcBytes.get(srcPos + channelMap[3]);
				
				bytesBGR.set(i++, b);
				bytesBGR.set(i++, g);
				bytesBGR.set(i++, r);
				
				srcPos += 4;
			}
			dstPos += yDir * paddedStride;
		}
		
		return {
			header: {
				width: width,
				height: height,
				paddedStride: paddedStride,
				topToBottom: topToBottom,
				bpp: bpp,
				dataLength: dataLength
			},
			pixels: bytesBGR
		}
	}
}