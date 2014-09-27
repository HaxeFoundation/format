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
package format.amf;
import format.amf.Value;

class Tools {

	public static function encode( o : Dynamic ) {
		return switch( Type.typeof(o) ) {
		case TNull: ANull;
		case TInt: ANumber(o);
		case TFloat: ANumber(o);
		case TBool: ABool(o);
		case TObject:
			var h = new Map();
			for( f in Reflect.fields(o) )
				h.set(f,encode(Reflect.field(o,f)));
			AObject(h);
		case TClass(c):
			switch( c ) {
			case cast String:
				AString(o);
			case cast haxe.ds.StringMap:
				var o : Map<String,Dynamic> = o;
				var h = new Map();
				for( f in o.keys() )
					h.set(f,encode(o.get(f)));
				AObject(h);
			case cast Array:
				var o : Array<Dynamic> = o;
				var a = new Array();
				for(v in o)
					a.push(encode(v));
				AArray(a);
			default:
				throw "Can't encode instance of "+Type.getClassName(c);
			}
		default:
			throw "Can't encode "+Std.string(o);
		}
	}

	public static function number( a : Value ) {
		if( a == null ) return null;
		return switch( a ) {
		case ANumber(n): n;
		default: null;
		}
	}

	public static function string( a : Value ) {
		if( a == null ) return null;
		return switch( a ) {
		case AString(s): s;
		default: null;
		}
	}

	public static function object( a : Value ) {
		if( a == null ) return null;
		return switch( a ) {
		case AObject(o,_): o;
		default: null;
		}
	}

	public static function abool( a : Value ) {
		if( a == null ) return null;
		return switch( a ) {
		case ABool(b): b;
		default: null;
		}
	}

	public static function array( a : Value ) {
		if( a == null ) return null;
		return switch( a ) {
		case AArray(a): a;
		default: null;
		}
	}
}
