/*
 * format - haXe File Formats
 *
 *  BMP File Format
 *  Copyright (C) 2007-2009 Robert Sköld
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

import format.bmp.Data;


class Reader {

	var input : haxe.io.Input;

	public function new( i ) {
		input = i;
	}

	/** 
	 * Only supports uncompressed 24bpp bitmaps (the most common format).
	 * 
	 * The returned bytes in `Data.pixels` will be in BGR order, and with padding (if present).
	 * 
	 * @see https://msdn.microsoft.com/en-us/library/windows/desktop/dd318229(v=vs.85).aspx
	 * @see https://en.wikipedia.org/wiki/BMP_file_format#Bitmap_file_header
	 */
	public function read() : format.bmp.Data {
		// Read Header
		for (b in ["B".code, "M".code]) {
			if (input.readByte() != b) throw "Invalid header";
		}
	
		var fileSize = input.readInt32();
		input.readInt32();							// Reserved
		var offset = input.readInt32();

		// Read InfoHeader
		var infoHeaderSize = input.readInt32();		// InfoHeader size
		var width = input.readInt32();				// Image width (actual, not padded)
		var height = input.readInt32();				// Image height
		var numPlanes = input.readInt16();			// Number of planes
		var bits = input.readInt16();				// Bits per pixel (24bit BGR)
		var compression = input.readInt32();		// Compression type (no compression)
		var dataLength = input.readInt32();			// Image data size (includes padding!)
		input.readInt32();							// Horizontal resolution
		input.readInt32();							// Vertical resolution
		input.readInt32();							// Colors used (0 when uncompressed)
		input.readInt32();							// Important colors (0 when uncompressed)

		// If there's no compression, the dataLength may be 0
		if( compression == 0 && dataLength == 0 ) dataLength = fileSize - offset;
		
		if (bits != 24) throw '${bits}bpp bitmaps not implemented.';
		
		var p = haxe.io.Bytes.alloc( dataLength );
		
		// Read Raster Data
		var paddedStride = Tools.computePaddedStride(width, bits);
		var topToBottom = false;
		if ( height < 0 ) { // if bitmap is stored top to bottom
			topToBottom = true;
			height = -height;
		}
    
		input.readFullBytes(p, 0, dataLength);
			
		return {
			header: {
				width: width,
				height: height,
				paddedStride: paddedStride,
				topToBottom: topToBottom,
				bpp: bits,
				dataLength: dataLength
			},
			pixels: p
		}
	}
}