/*
 * format - haXe File Formats
 * NekoVM emulator by Nicolas Cannasse
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
package format.neko;
import format.neko.Value;

class Builtins {
	
	public static inline var CINVALID = -1000;
	
	var vm : VM;
	public var table : Map<String,Value>;
	
	public function new(vm) {
		this.vm = vm;
		table = new Map();
		b("objsetproto", VFun2(objsetproto));
		b("typeof", VFun1(typeof));
		b("string", VFun1(string));
		b("print", VFunVar(print));
	}
	
	// -------- HELPERS ---------------------
	
	function b(name, f) {
		table.set(name, VFunction(f));
	}
	
	public function _nargs( f : ValueFunction ) {
		return switch( f ) {
		case VFun0(_): 0;
		case VFun1(_): 1;
		case VFun2(_): 2;
		case VFun3(_): 3;
		case VFun4(_): 4;
		case VFun5(_): 5;
		case VFunVar(_): -1;
		}
	}
	
	public function _compare( a : Value, b : Value ) : Int {
		switch( a ) {
		case VInt(a):
			switch(b) {
			case VInt(b):
				return (a == b)?0:((a < b)? -1:1);
			case VFloat(b):
				return (a == b)?0:((a < b)? -1:1);
			case VString(b):
				var a = Std.string(a);
				return (a == b)?0:((a < b)? -1:1);
			default:
			}
		case VFloat(a):
			switch(b) {
			case VInt(b):
				return (a == b)?0:((a < b)? -1:1);
			case VFloat(b):
				return (a == b)?0:((a < b)? -1:1);
			case VString(b):
				var a = Std.string(a);
				return (a == b)?0:((a < b)? -1:1);
			default:
			}
		case VString(a):
			switch(b) {
			case VInt(b):
				var b = Std.string(b);
				return (a == b)?0:((a < b)? -1:1);
			case VFloat(b):
				var b = Std.string(b);
				return (a == b)?0:((a < b)? -1:1);
			case VString(b):
				return (a == b)?0:((a < b)? -1:1);
			case VBool(b):
				var b = Std.string(b);
				return (a == b)?0:((a < b)? -1:1);
			default:
			}
		case VBool(a):
			switch( b ) {
			case VString(b):
				var a = Std.string(a);
				return (a == b)?0:((a < b)? -1:1);
			case VBool(b):
				return (a == b) ? 0 : (a ? 1 : -1);
			default:
			}
		case VObject(a):
			switch( b ) {
			case VObject(b):
				if( a == b )
					return 0;
				throw "TODO";
			default:
			}
		case VProxy(a):
			switch( b ) {
			case VProxy(b):
				return ( a == b ) ? 0 : CINVALID;
			default:
			}
		default:
		}
		return (a == b) ? 0 : CINVALID;
	}
	
	public function _string( v : Value ) {
		return switch( v ) {
		case VNull: "null";
		case VInt(i): Std.string(i);
		case VFloat(f): Std.string(f);
		case VBool(b): b?"true":"false";
		case VArray(a):
			var b = new StringBuf();
			b.addChar("[".code);
			var first = true;
			for( v in a ) {
				if( first ) first = false else b.addChar(",".code);
				b.add(_string(v));
			}
			b.addChar("]".code);
			b.toString();
		case VString(s): s;
		case VFunction(f): "#function:" + _nargs(f);
		case VAbstract(_): "#abstract";
		case VObject(_):
			throw "TODO";
		case VProxy(o):
			Std.string(o);
		case VProxyFunction(f):
			Std.string(f);
		}
	}
	
	// ----------------- BUILTINS -------------------
		
	public function typeof( o : Value ) : Value {
		return VInt(switch( o ) {
		case VProxy(_): 5; // $tobject
		case VProxyFunction(_): 7; // $tfunction
		default: Type.enumIndex(o);
		});
	}
	
	function print( vl : Array<Value> ) {
		var buf = new StringBuf();
		for( v in vl )
			buf.add(_string(v));
		vm.doPrint(buf.toString());
		return VNull;
	}
	
	function string( v : Value ) {
		return VString(_string(v));
	}
	
	function objsetproto( o : Value, p : Value ) : Value {
		switch( o ) {
		case VObject(o):
			switch(p) {
			case VNull: o.proto = null;
			case VObject(p): o.proto = p;
			default: return null;
			}
		default:
			return null;
		}
		return VNull;
	}
	
}