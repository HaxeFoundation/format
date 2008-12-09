/*
 * format - haXe File Formats
 *
 *  SWF File Format
 *  Copyright (C) 2004-2008 Nicolas Cannasse
 *
 * Copyright (c) 2008, The haXe Project Contributors
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
package format.swf;

class Tools {

	public static function signExtend( v : Int, nbits : Int ) {
		var max = 1 << nbits;
		// sign bit is set
		if( v & (max >> 1) != 0 )
			return v - max;
		return v;
	}

	public inline static function floatFixedBits( i : Int, nbits ) {
		i = signExtend(i,nbits);
		return (i >> 16) + (i & 0xFFFF) / 65536.0;
	}

	public inline static function floatFixed( i : haxe.Int32 ) {
		return haxe.Int32.toInt(haxe.Int32.shr(i,16)) + haxe.Int32.toInt(haxe.Int32.and(i,haxe.Int32.ofInt(0xFFFF))) / 65536.0;
	}

	public inline static function floatFixed8( i : Int ) {
		return (i >> 8) + (i & 0xFF) / 256.0;
	}

	public inline static function toFixed8( f : Float ) {
		var i = Std.int(f);
		if( ((i>0)?i:-i) >= 128 )
			throw haxe.io.Error.Overflow;
		if( i < 0 ) i = 256-i;
		return (i << 8) | Std.int((f-i)*256.0);
	}

}