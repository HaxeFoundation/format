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
package format.amf3;
import format.amf3.Amf3Array;
import format.amf3.Value;
import haxe.ds.Vector;

class Tools {

	public static function encode( o : Dynamic ) : Value {
		return switch( Type.typeof(o) ) {
		case TNull: ANull;
		case TBool: ABool(o);
		case TInt: AInt(o);
		case TFloat: ANumber(o);
		case TObject:
			var h = new Map();
			for ( f in Reflect.fields(o) ) {
				h.set(f, encode(Reflect.field(o, f)));
			}
			AObject(h);
		case TClass(c):
			switch( c ) {
			case cast String:
				AString(o);
			case cast Xml:
				AXml(o);
			case cast haxe.ds.StringMap, haxe.ds.IntMap, haxe.ds.ObjectMap:
				var o : Map<Dynamic,Dynamic> = o;
				var h = new Map();
				for( f in o.keys() )
					h.set(encode(f), encode(o.get(f)));
				AMap(h);
			case cast Array:
				var o : Array<Dynamic> = o;
				var a = new Array();
				for(v in o)
					a.push(encode(v));
				AArray(a);
			case cast Amf3Array:
				var o : Amf3Array = o;
				var a = new Array();
				var m = new Map<String,Value>();
				for(v in o.a)
					a.push(encode(v));
				for(k in o.extra)
					m[k] = encode(o.extra[k]);
				AArray(a, m);
			case cast Vector:
				var o : Vector<Dynamic> = o;
				var a = new Vector<Value>(o.length);
				for(i in 0...o.length)
					a[i] = encode(o[i]);
				AVector(a);
			case cast haxe.io.Bytes:
				ABytes(o);
			case cast Date:
				ADate(o);
			case _:
				var h = new Map();
				var i = 0;
				for ( f in Type.getInstanceFields(Type.getClass(o)) ) {
					h.set(f, encode(Reflect.getProperty(o, f)));
					i++;
				}
				AObject(h, i);
			}
		default:
			throw "Can't encode "+Std.string(o);
		}
	}

	public static function decode( a : Value ) : Dynamic {
		return switch ( a ) {
			case AUndefined: undefined(a);
			case ANull: anull(a);
			case ABool(_): bool(a);
			case AInt(_): int(a);
			case ANumber(_): number(a);
			case AString(_): string(a);
			case ADate(_): date(a);
			case AArray(_,_): array(a);
			case AVector(_): vector(a);
			case AObject(_,_): object(a);
			case AXml(_): xml(a);
			case ABytes(_): bytes(a);
			case AMap(_): map(a);
		}
	}

	public static function undefined( a : Value ) {
		return null;
	}

	public static function anull( a : Value ) {
		return null;
	}

	public static function bool( a : Value ) {
		if( a == null ) return null;
		return switch( a ) {
		case ABool(b): b;
		default: null;
		}
	}

	public static function int( a : Value ) {
		if( a == null ) return null;
		return switch( a ) {
		case AInt(n): n;
		default: null;
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

	public static function date( a : Value ) {
		if( a == null ) return null;
		return switch( a ) {
		case ADate(d): d;
		default: null;
		}
	}

	public static function array( a : Value ) : Amf3Array {
		if( a == null ) return null;
		return switch( a ) {
		case AArray(a, m):
			var b = [];
			for (f in a)
				b.push(decode(f));
			var c = new Map<String, Dynamic>();
			for (mk in m.keys())
				c[mk] = decode(m[mk]);
			new Amf3Array(b,c);
		default: null;
		}
	}

	public static function vector( a : Value ) {
		if( a == null ) return null;
		return switch( a ) {
			case AVector(a):
				var v = new Vector<Dynamic>(a.length);
				for (i in 0...a.length)
					v[i] = decode(a[i]);
				v;
			default: null;
		}
	}

	public static function object( a : Value ) {
		if( a == null ) return null;
		return switch( a ) {
		case AObject(o, _):
			var m = new Map();
			for (f in o.keys())
				m.set(f, decode(o.get(f)));
			m;
		default: null;
		}
	}

	public static function xml( a : Value ) {
		if( a == null ) return null;
		return switch( a ) {
		case AXml(x): x;
		default: null;
		}
	}

	public static function bytes( a : Value ) {
		if( a == null ) return null;
		return switch( a ) {
		case ABytes(b): b;
		default: null;
		}
	}

	public static function map( a : Value ) {
		if( a == null ) return null;
		return switch( a ) {
		case AMap(m):
			var p = new Map<Value, Value>();
			for (f in m.keys())
				p.set(decode(f), decode(m.get(f)));
			p;
		default: null;
		}
	}
}
