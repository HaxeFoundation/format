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

class Filter {

	public function new() {
	}

	public function unfilter( data : Array<Data> ) {
		var d = new Array();
		for( o in data )
			d.push(unfilterObject(o));
		return d;
	}

	public function unfilterObject( o : Data ) {
		switch(o) {
		case DNull, DBool(_), DNumber(_), DString(_), DHexString(_), DName(_), DRef(_,_), DXRefTable(_), DStartXRef(_), DComment(_):
			return o;
		case DArray(a):
			var a2 = new Array();
			for( o in a )
				a2.push(unfilterObject(o));
			return DArray(a2);
		case DDict(h):
			var h2 = new Map();
			for( k in h.keys() )
				h2.set(k,unfilterObject(h.get(k)));
			return DDict(h2);
		case DIndirect(id,rev,v):
			return DIndirect(id,rev,unfilterObject(v));
		case DTrailer(o):
			return DTrailer(unfilterObject(o));
		case DStream(b,props):
			var filter = props.get("Filter");
			if( filter == null )
				return o;
			var nprops = new Map();
			for( k in props.keys() )
				nprops.set(k,props.get(k));
			b = runFilter(b,filter,nprops);
			return DStream(b,nprops);
		}
	}

	function runFilter( b : haxe.io.Bytes, filter : Data, props : Map<String,Data> ) : haxe.io.Bytes {
		switch( filter ) {
		case DArray(a):
			for( o in a )
				b = runFilter(b,o,props);
		case DName(n):
			if( n == "FlateDecode" ) {
				props.remove("Filter");
				#if neko
				return neko.zip.Uncompress.run(b);
				#else
				#if cpp
				return cpp.zip.Uncompress.run(b);
				#else
				throw "Can't apply deflate filter";
				#end
				#end
			}
		default:
			throw "Invalid filter "+filter;
		}
		return b;
	}

}