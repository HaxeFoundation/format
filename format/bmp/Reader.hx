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
import haxe.Int32;

class Reader {

	var input : haxe.io.Input;

	public function new( i ) {
		input = i;
	}

	public function read() : format.bmp.Data {
		// Read Header
		var signature = input.readString( 2 );
		var fileSize = input.readInt31();
		input.readInt31(); 								// Reserved
		var offset = input.readInt31();

		// Read InfoHeader
		var infoHeaderSize = input.readInt31();			// InfoHeader size
		var width = Int32.toInt( input.readInt32() );	// Image width
		var height = Int32.toInt( input.readInt32() );	// Image height
		var numPlanes = input.readInt16();				// Number of planes
		var bits = input.readInt16();					// Bits per pixel (24bit RGB)
		var compression = input.readInt31();			// Compression type (no compression)
		var dataLength = input.readInt31();				// Image data size
		input.readInt32();								// Horizontal resolution
		input.readInt32();								// Vertical resolution
		input.readInt31();								// Colors used (0 when uncompressed)
		input.readInt31();								// Important colors (0 when uncompressed)

		// If there's no compression, the dataLength may be 0
		if( compression == 0 && dataLength == 0 ) dataLength = fileSize - offset;

		// Not sure why it's upside down, but the bmp from pixelmator is...
		if( height < 0 ) height = -height;

		// Read Raster Data
		var p = haxe.io.Bytes.alloc( dataLength );
		var pos = 0;
		while( pos < dataLength ) {
			var px = input.readInt32();
			var a = Int32.toInt( Int32.and( Int32.shr( px , 24 ) , Int32.ofInt( 0xFF ) ) );
			var r = Int32.toInt( Int32.and( Int32.shr( px , 16 ) , Int32.ofInt( 0xFF ) ) );
			var g = Int32.toInt( Int32.and( Int32.shr( px ,  8 ) , Int32.ofInt( 0xFF ) ) );
			var b = Int32.toInt( Int32.and( px , Int32.ofInt( 0xFF ) ) );
			p.set( pos + 0 , a );
			p.set( pos + 1 , r );
			p.set( pos + 2 , g );
			p.set( pos + 3 , b );
			pos += 4;
		}

		return {
			header: {
				width: width,
				height: height
			},
			pixels: p
		}
	}
}