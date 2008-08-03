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
package format.pdf;

class Extract {

	static function expect( kind, o : Data ) : Dynamic {
		return throw kind+" expected but "+Std.string(o)+" found";
	}

	public static function int( o : Data ) {
		if( o == null ) expect("int",o);
		return switch( o ) {
		case DNumber(n):
			var i = Std.int(n);
			if( i != n ) expect("int",o);
			i;
		default:
			expect("int",o);
		}
	}

	public static function string( o : Data ) {
		if( o == null ) expect("string",o);
		return switch( o ) {
		case DString(s), DHexString(s): s;
		default: expect("string",o);
		}
	}

	public static function bool( o : Data, ?def : Bool ) {
		if( o == null ) {
			if( def == null ) expect("bool",o);
			return def;
		}
		return switch( o ) {
		case DBool(b): b;
		default: expect("bool",o);
		}
	}

}