/*
 * format - haXe File Formats
 * ABC and SWF support by Nicolas Cannasse
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
package format.abc;
import format.abc.Data;

class Writer {

	var o : haxe.io.Output;
	var opw : OpWriter;

	public function new(o) {
		this.o = o;
		opw = new OpWriter(o);
	}

	function beginTag( id : Int, len : Int ) {
		if( len >= 63 ) {
			o.writeUInt16((id << 6) | 63);
			#if haxe3
			o.writeInt32(len);
			#else
			o.writeUInt30(len);
			#end
		} else
			o.writeUInt16((id << 6) | len);
	}

	inline function writeInt( n : Int ) {
		opw.writeInt(n);
	}

	inline function writeUInt( n : Int ) {
		opw.writeInt(n);
	}

	function writeList<T>( a : Array<T>, write : T -> Void ) {
		if( a.length == 0 ) {
			writeInt(0);
			return;
		}
		writeInt(a.length + 1);
		for( i in 0...a.length )
			write(a[i]);
	}

	function writeList2<T>( a : Array<T>, write : T -> Void ) {
		writeInt(a.length);
		for( i in 0...a.length )
			write(a[i]);
	}

	function writeString( s : String ) {
		writeInt(s.length);
		o.writeString(s);
	}

	function writeIndex( i : Index<Dynamic> ) {
		switch( i ) {
		case Idx(n): writeInt(n);
		}
	}

	function writeIndexOpt( i : Index<Dynamic> ) {
		if( i == null ) {
			o.writeByte(0);
			return;
		}
		writeIndex(i);
	}

	function writeNamespace( n ) {
		switch( n ) {
		case NPrivate(id):
			o.writeByte(0x05);
			writeIndex(id);
		case NNamespace(ns):
			o.writeByte(0x08);
			writeIndex(ns);
		case NPublic(id):
			o.writeByte(0x16);
			writeIndex(id);
		case NInternal(id):
			o.writeByte(0x17);
			writeIndex(id);
		case NProtected(id):
			o.writeByte(0x18);
			writeIndex(id);
		case NExplicit(id):
			o.writeByte(0x19);
			writeIndex(id);
		case NStaticProtected(id):
			o.writeByte(0x1A);
			writeIndex(id);
		}
	}

	function writeNsSet( n : NamespaceSet ) {
		o.writeByte( n.length );
		for( i in n )
			writeIndex(i);
	}

	inline function writeNameByte(k,n) {
		o.writeByte(( k < 0 ) ? n : k);
	}

	function writeName( k = -1, n ) {
		switch( n ) {
		case NName(id,ns):
			writeNameByte(k,0x07);
			writeIndex(ns);
			writeIndex(id);
		case NMulti(id,ns):
			writeNameByte(k,0x09);
			writeIndex(id);
			writeIndex(ns);
		case NRuntime(n):
			writeNameByte(k,0x0F);
			writeIndex(n);
		case NRuntimeLate:
			writeNameByte(k,0x11);
		case NMultiLate(ns):
			writeNameByte(k,0x1B);
			writeIndex(ns);
		case NAttrib(n):
			writeName(switch(n) {
				case NName(_,_): 0x0D;
				case NMulti(_,_): 0x0E;
				case NRuntime(_): 0x10;
				case NRuntimeLate : 0x12;
				case NMultiLate(_): 0x1C;
				case NAttrib(_), NParams(_,_): throw "assert";
			},n);
		case NParams(n,params):
			writeNameByte(k,0x1D);
			writeIndex(n);
			o.writeByte(params.length);
			for( i in params )
				writeIndex(i);
		}
	}

	function writeValue(extra,v) {
		if( v == null ) {
			if( extra ) o.writeByte(0x00);
			o.writeByte(0x00);
			return;
		}
		switch( v ) {
		case VNull:
			o.writeByte(0x0C);
			o.writeByte(0x0C);
		case VBool(b):
			var c = b ? 0x0B : 0x0A;
			o.writeByte(c);
			o.writeByte(c);
		case VString(i):
			writeIndex(i);
			o.writeByte(0x01);
		case VInt(i):
			writeIndex(i);
			o.writeByte(0x03);
		case VUInt(i):
			writeIndex(i);
			o.writeByte(0x04);
		case VFloat(i):
			writeIndex(i);
			o.writeByte(0x06);
		case VNamespace(n,i):
			writeIndex(i);
			o.writeByte(n);
		}
	}

	function writeField( f : Field ) {
		writeIndex(f.name);
		var flags = 0;
		if( f.metadatas != null ) flags |= 0x40;
		switch( f.kind ) {
		case FVar(t,v,const):
			o.writeByte((const ? 0x06 : 0x00) | flags);
			writeInt(f.slot);
			writeIndexOpt(t);
			writeValue(false,v);
		case FMethod(t,k,isFinal,isOverride):
			if( isFinal ) flags |= 0x10;
			if( isOverride ) flags |= 0x20;
			switch(k) {
			case KNormal: flags |= 0x01;
			case KGetter: flags |= 0x02;
			case KSetter: flags |= 0x03;
			}
			o.writeByte(flags);
			writeInt(f.slot);
			writeIndex(t);
		case FClass(c):
			o.writeByte(0x04 | flags);
			writeInt(f.slot);
			writeIndex(c);
		case FFunction(i):
			o.writeByte(0x05 | flags);
			writeInt(f.slot);
			writeIndex(i);
		}
		if( f.metadatas != null )
			writeList2(f.metadatas,writeIndex);
	}

	function writeMethodType( m : MethodType ) {
		o.writeByte(m.args.length);
		writeIndexOpt(m.ret);
		for( a in m.args )
			writeIndexOpt(a);
		var x = m.extra;
		if( x == null ) {
			writeIndexOpt(null); // debug name
			o.writeByte(0); // flags
			return;
		}
		writeIndexOpt(x.debugName);
		var flags = 0;
		if( x.argumentsDefined ) flags |= 0x01;
		if( x.newBlock ) flags |= 0x02;
		if( x.variableArgs ) flags |= 0x04;
		if( x.defaultParameters != null ) flags |= 0x08;
		if( x.unused ) flags |= 0x10;
		if( x.native ) flags |= 0x20;
		if( x.usesDXNS ) flags |= 0x40;
		if( x.paramNames != null ) flags |= 0x80;
		o.writeByte(flags);
		if( x.defaultParameters != null ) {
			o.writeByte(x.defaultParameters.length);
			for( v in x.defaultParameters )
				writeValue(true,v);
		}
		if( x.paramNames != null ) {
			if( x.paramNames.length != m.args.length ) throw "assert";
			for( i in x.paramNames )
				writeIndexOpt(i);
		}
	}

	function writeMetadata( m : Metadata ) {
		writeIndex(m.name);
		writeInt(m.data.length);
		for( d in m.data )
			writeIndex(d.n);
		for( d in m.data )
			writeIndex(d.v);
	}

	function writeClass( c : ClassDef ) {
		writeIndex(c.name);
		writeIndexOpt(c.superclass);
		var flags = 0;
		if( c.isSealed ) flags |= 0x01;
		if( c.isFinal ) flags |= 0x02;
		if( c.isInterface ) flags |= 0x04;
		if( c.namespace != null ) flags |= 0x08;
		o.writeByte(flags);
		if( c.namespace != null )
			writeIndex(c.namespace);
		writeList2(c.interfaces,writeIndex);
		writeIndex(c.constructor);
		writeList2(c.fields,writeField);
	}

	function writeInit( i : Init ) {
		writeIndex(i.method);
		writeList2(i.fields,writeField);
	}

	function writeTryCatch( t : TryCatch ) {
		writeInt(t.start);
		writeInt(t.end);
		writeInt(t.handle);
		writeIndexOpt(t.type);
		writeIndexOpt(t.variable);
	}

	function writeFunction( f : Function ) {
		writeIndex(f.type);
		writeInt(f.maxStack);
		writeInt(f.nRegs);
		writeInt(f.initScope);
		writeInt(f.maxScope);
		writeInt(f.code.length);
		o.write(f.code);
		writeList2(f.trys,writeTryCatch);
		writeList2(f.locals,writeField);
	}

	public function write( d : ABCData ) {
		#if haxe3
		o.writeInt32(0x002E0010); // as3 magic header
		#else
		o.writeInt31(0x002E0010); // as3 magic header
		#end
		writeList(d.ints,opw.writeInt32);
		writeList(d.uints,opw.writeInt32);
		writeList(d.floats,o.writeDouble);
		writeList(d.strings,writeString);
		writeList(d.namespaces,writeNamespace);
		writeList(d.nssets,writeNsSet);
		writeList(d.names,function(n) writeName(-1,n));
		writeList2(d.methodTypes,writeMethodType);
		writeList2(d.metadatas,writeMetadata);
		writeList2(d.classes,writeClass);
		for( c in d.classes ) {
			writeIndex(c.statics);
			writeList2(c.staticFields,writeField);
		}
		writeList2(d.inits,writeInit);
		writeList2(d.functions,writeFunction);
	}

}