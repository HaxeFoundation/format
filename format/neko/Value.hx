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
import format.neko.Data;

enum Value {
	VNull;
	VInt( i : Int );
	VFloat( f : Float );
	VBool( b : Bool );
	VString( s : String );
	VObject( o : ValueObject );
	VArray( a : Array<Value> );
	VFunction( f : ValueFunction );
	VAbstract( v : ValueAbstract );
	VProxy( o : Dynamic );
	VProxyFunction( f : Dynamic );
}

class ValueObject {
	public var fields : Map<Int,Value>;
	public var proto : Null<ValueObject>;
	public function new(?p) {
		fields = new Map();
		proto = p;
	}
}

interface ValueAbstract {
}

enum ValueFunction {
	VFun0( f : Void -> Value );
	VFun1( f : Value -> Value );
	VFun2( f : Value -> Value -> Value );
	VFun3( f : Value -> Value -> Value -> Value );
	VFun4( f : Value -> Value -> Value -> Value -> Value );
	VFun5( f : Value -> Value -> Value -> Value -> Value -> Value );
	VFunVar( f : Array<Value> -> Value );
}

class Module {
	public var code : Data;
	public var gtable : Array<Value>;
	public var debug : Null<DebugInfos>;
	public var exports : ValueObject;
	public var loader : ValueObject;
	public function new(code,loader) {
		this.code = code;
		this.loader = loader;
		gtable = [];
		exports = new ValueObject();
		if( code.globals.length > 0 ) gtable[code.globals.length - 1] = null;
	}
}