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

class Writer {

	static var DATA_OFFSET : Int = 0x36;

	var output : haxe.io.Output;

	/**
	 * Specs: http://s223767089.online.de/en/file-format-bmp
	 */
	public function new(o) {
		output = o;
	}

	public function write( b : Data ) {
		// Write Header
		var h = new haxe.io.BytesOutput();
		h.prepare( 14 );
		h.writeString( "BM" );							// Signature
		h.writeInt31( b.pixels.length + DATA_OFFSET );	// FileSize
		h.writeInt31( 0 );								// Reserved
		h.writeInt31( DATA_OFFSET );					// Offset
		output.write( h.getBytes() );

		// Write InfoHeader
		var i = new haxe.io.BytesOutput();
		i.prepare( 40 );
		i.writeInt31( 40 );								// InfoHeader size
		i.writeInt31( b.header.width );					// Image width
		i.writeInt31( b.header.height );				// Image height
		i.writeInt16( 1 );								// Number of planes
		i.writeInt16( 24 );								// Bits per pixel (24bit RGB)
		i.writeInt31( 0 );								// Compression type (no compression)
		i.writeInt31( 0 );								// Image data size (0 when uncompressed)
		i.writeInt32( Int32.ofInt( 0x2e30 ) );			// Horizontal resolution
		i.writeInt32( Int32.ofInt( 0x2e30 ) );			// Vertical resolution
		i.writeInt31( 0 );								// Colors used (0 when uncompressed)
		i.writeInt31( 0 );								// Important colors (0 when uncompressed)
		output.write( i.getBytes() );

		// Write Raster Data (backwards)
		var pixels = new haxe.io.BytesInput( b.pixels );
		var p = haxe.io.Bytes.alloc( b.pixels.length );
		var pos = 0;
		while( pos < b.pixels.length ) {
			var px = pixels.readInt32();
			var b = Int32.toInt( Int32.and( Int32.shr( px , 24 ) , Int32.ofInt( 0xFF ) ) );
			var g = Int32.toInt( Int32.and( Int32.shr( px , 16 ) , Int32.ofInt( 0xFF ) ) );
			var r = Int32.toInt( Int32.and( Int32.shr( px ,  8 ) , Int32.ofInt( 0xFF ) ) );
			var a = Int32.toInt( Int32.and( px , Int32.ofInt( 0xFF ) ) );
			if( pos < 12 ) trace( "a:" + a + " r:" + r + " g:" + g + " b:" + b + " = " + px );
			p.set( pos + 3 , a );
			p.set( pos + 2 , r );
			p.set( pos + 1 , g );
			p.set( pos + 0 , b );
			pos += 4;
		}
		output.write( p );
	}
}