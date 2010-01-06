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
package format.tools;

class Image {

	#if flash

	public static function getBytesARGB( bmp : flash.display.BitmapData ) : haxe.io.Bytes {
		#if flash9
		return haxe.io.Bytes.ofData( bmp.getPixels(bmp.rect) );
		#else
		var a = new Array();
		for( y in 0...bmp.height )
			for( x in 0...bmp.width ) {
				var b = bmp.getPixel32(x,y);
				a.push(b>>>24);
				a.push((b>>16)&0xFF);
				a.push((b>>8)&0xFF);
				a.push(b&0xFF);
			}
		return haxe.io.Bytes.ofData(a);
		#end
	}

	public static function makeBitmapARGB( width : Int, height : Int, bytes : haxe.io.Bytes ) : flash.display.BitmapData {
		var bmp = new flash.display.BitmapData(width,height,true);
		var ba = bytes.getData();
		#if flash9
		ba.position = 0;
		bmp.setPixels(bmp.rect,ba);
		#else
		var p = 0;
		for( y in 0...height )
			for( x in 0...width ) {
				bmp.setPixel32( x , y , (ba[p]<<24) | (ba[p+1]<<16) | (ba[p+2]<<8) | ba[p+3] );
				p += 4;
			}
		#end
		return bmp;
	}

	#end

}