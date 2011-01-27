/*
 * format - haXe File Formats
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
package format.agal;

class Tools {

	public static function getMaxTextures() {
		return 8;
	}

	public static function getProps( r : Data.RegType, fragment : Bool ) {
		return switch( r ) {
		case RAttr: if( fragment ) { read : false, write : false, count : 0 } else { read : true, write : false, count : 8 };
		case RConst: { read : true, write : false, count : fragment ? 28 : 128 };
		case RTemp: { read : true, write : true, count : 8 };
		case ROut: { read : false, write : true, count : 1 };
		case RVar: { read : true, write : true, count : 8 };
		//case RSampler: if( fragment ) { read : true, write : false, count : 8 } else { read : false, write : false, count : 0 };
		}
	}

	public static function ofString( str : String ) : haxe.io.Bytes {
		var b : haxe.io.Bytes = haxe.Unserializer.run(str);
		#if flash9
		// force endianness
		b.getData().endian = flash.utils.Endian.LITTLE_ENDIAN;
		#end
		return b;
	}

}