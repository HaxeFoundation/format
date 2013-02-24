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
import format.pdf.Data;

class Crypt {

	static var PAD_BYTES = initPadBytes();
	static function initPadBytes() {
		var data = [0x28,0xBF,0x4E,0x5E,0x4E,0x75,0x8A,0x41,0x64,0x00,0x4E,0x56,0xFF,0xFA,0x01,0x08,0x2E,0x2E,0x00,0xB6,0xD0,0x68,0x3E,0x80,0x2F,0x0C,0xA9,0xFE,0x64,0x53,0x69,0x7A];
		var b = haxe.io.Bytes.alloc(data.length);
		for( i in 0...data.length )
			b.set(i,data[i]);
		return b;
	}

	var version : Int;
	var revision : Int;
	var fileKey : haxe.io.Bytes;
	var userPassword : String;

	public function new( ?pass ) {
		userPassword = (pass == null) ? "" : pass;
	}

	public function decrypt( data : Array<Data> ) : Array<Data> {
		var objects = new Map();
		var encrypt = null, fileId = null;
		for( d in data )
			switch( d ) {
			case DIndirect(id,_,v): objects.set(id,v);
			case DTrailer(v):
				switch( v ) {
				case DDict(h):
					encrypt = h.get("Encrypt");
					fileId = h.get("ID");
				default:
				}
			default:
			}
		if( encrypt == null )
			return data;
		switch( encrypt ) {
		case DRef(id,_):
			encrypt = objects.get(id);
		default:
		}
		switch( encrypt ) {
		case DDict(h):
			if( !Type.enumEq(h.get("Filter"),DName("Standard")) )
				throw "Unknown encrypt "+Std.string(encrypt);
			fileKey = buildFileKey(fileId,h);
		default:
			throw "Invalid encrypt "+Std.string(encrypt);
		}
		var d = new Array();
		for( o in data )
			d.push(decryptObject(fileKey,o));
		return d;
	}

	function decryptObject( key, o ) {
		switch( o ) {
		case DNull,DBool(_),DNumber(_),DName(_),DRef(_,_),DXRefTable(_),DStartXRef(_),DComment(_),DTrailer(_):
			return o;
		case DString(s):
			return DString(decryptString(s,key));
		case DHexString(s):
			return DHexString(decryptString(s,key));
		case DArray(a):
			var a2 = new Array();
			for( o in a )
				a2.push(decryptObject(key,o));
			return DArray(a2);
		case DDict(h):
			var h2 = new Map();
			for( k in h.keys() )
				h2.set(k,decryptObject(key,h.get(k)));
			return DDict(h2);
		case DIndirect(id,rev,v):
			var objKey = buildObjectKey(id,rev);
			return DIndirect(id,rev,decryptObject(objKey,v));
		case DStream(b,h):
			var h2 = new Map();
			for( k in h.keys() )
				h2.set(k,decryptObject(key,h.get(k)));
			return DStream(decryptBytes(b,key),h2);
		}
	}

	function decryptString( s, k ) {
		return decryptBytes( haxe.io.Bytes.ofString(s), k ).toString();
	}

	function decryptBytes( b : haxe.io.Bytes, k ) {
		var a = new format.tools.ArcFour(k);
		var b2 = haxe.io.Bytes.alloc(b.length);
		a.run(b,0,b.length,b2,0);
		return b2;
	}

	function buildFileKey( fileId : Data, h : Map<String,Data> ) {
		version = Extract.int(h.get("V"));
		revision = Extract.int(h.get("R"));
		if( version != 2 || (revision != 3 && revision != 4) )
			throw "Unknown encrypt version "+version+"."+revision;
		// build the key
		var key = new haxe.io.BytesOutput();
		if( userPassword.length >= 32 )
			key.writeString(userPassword.substr(0,32));
		else {
			key.writeString(userPassword);
			key.writeFullBytes(PAD_BYTES,0,32 - userPassword.length);
		}
		var ohash = Extract.string(h.get("O"));
		key.writeString( ohash );
		var perms = Extract.int(h.get("P"));
		#if haxe3
		key.writeInt32(perms);
		#else
		key.writeInt31(perms);
		#end
		switch( fileId ) {
		case DArray(a): key.writeString( Extract.string(a[0]) );
		default: throw "Invalid ID "+Std.string(fileId);
		}
		var encryptMetada = Extract.bool(h.get("EncryptMetaData"),true);
		if( revision >= 4 && !encryptMetada ) {
			key.writeUInt16(0xFFFF);
			key.writeUInt16(0xFFFF);
		}
		var key = format.tools.MD5.make(key.getBytes());
		// rev 3 : 50x hashing
		var klength = Extract.int(h.get("Length"));
		if( klength % 8 != 0 ) throw "Invalid key length "+klength;
		klength >>= 3;
		for( i in 0...50 )
			key = format.tools.MD5.make(key.sub(0,klength));
		key = key.sub(0,klength);
		return key;
	}

	function buildObjectKey( id : Int, rev : Int ) {
		var k = fileKey.length;
		var total = haxe.io.Bytes.alloc(k + 5);
		total.blit(0,fileKey,0,k);
		total.set(k++,id & 0xFF);
		total.set(k++,(id >> 8) & 0xFF);
		total.set(k++,(id >> 16) & 0xFF);
		total.set(k++,rev & 0xFF);
		total.set(k++,(rev >> 8) & 0xFF);
		var tot = fileKey.length + 5;
		if( tot > 16 ) tot = 16;
		return format.tools.MD5.make(total).sub(0,tot);
	}

}