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
import format.agal.Data;

class Writer {

	var o : haxe.io.Output;

	public function new(o) {
		this.o = o;
		o.bigEndian = false;
	}

	public function write( data : Data ) {
		o.writeByte(0xA0);
		o.writeInt31(1); // version
		o.writeByte(0xA1);
		o.writeByte(data.fragmentShader ? 1 : 0);
		var idKil = Type.enumIndex(OKil(null));
		var idTex = Type.enumIndex(OTex(null, null, null));
		for( c in data.code ) {
			var idx = Type.enumIndex(c);
			var params = Type.enumParameters(c);
			var dst : Reg = params[0];
			o.writeUInt30(( idx >= idKil ) ? (idx - idKil + 0x27) : idx);
			if( idx == idKil ) {
				o.writeUInt30(0);
				writeSrc(dst);
				writeSrc(null);
				continue;
			}
			o.writeUInt30( dst.index | (maskBits(dst.swiz) << 16) | (regType(dst.t) << 24));
			writeSrc(params[1]);
			if( idx == idTex )
				writeTex(params[2]);
			else
				writeSrc(params[2]);
		}
	}

	inline function regType( r : RegType ) {
		return Type.enumIndex(r);
	}

	function maskBits( m : Swizzle ) {
		if( m == null ) return 15;
		var bits = 0;
		for( c in m )
			bits |= 1 << Type.enumIndex(c);
		return bits;
	}

	function swizzleBits( s : Swizzle ) {
		if( s == null ) return 0 | (1 << 2) | (2 << 4) | (3 << 6);
		var bits = 0;
		var p = 0;
		var last = 0;
		for( c in s ) {
			last = Type.enumIndex(c);
			bits |= last << p;
			p += 2;
		}
		// repeat last component
		while( p < 8 ) {
			bits |= last << p;
			p += 2;
		}
		return bits;
	}

	function texFlagsBits( a : Array<TexFlag> ) {
		var dim = 0, wrap = 0, mipmap = 0, filter = 1, bias = 0;
		if( a != null )
			for( f in a )
				switch( f ) {
				case T2D: dim = 0;
				case TCube: dim = 1;
				case T3D: dim = 2;
				case TMipMapDisable: mipmap = 0;
				case TMipMapNearest: mipmap = 1;
				case TMipMapLinear: mipmap = 2;
				case TWrap: wrap = 1;
				case TClamp: wrap = 0;
				case TFilterNearest: filter = 0;
				case TFilterLinear: filter = 1;
				case TLodBias(v):
					var v = Std.int(v*8);
					if( v < -128 ) v = -128 else if( v > 127 ) v = 127;
					if( v < 0 ) v = 0x100 - v;
					bias = v;
				}
		return { flags : (dim << 4) | (wrap << 12) | (mipmap << 16) | (filter << 20), bias : bias };
	}

	function writeSrc( s : Reg ) {
		if( s == null ) {
			o.writeUInt30(0);
			o.writeUInt30(0);
			return;
		}
		// indirect mode not supported : reg[r0.x + off] ?
		o.writeUInt16( s.index );
		o.writeByte(0); // indirect offset
		o.writeByte( swizzleBits(s.swiz) );
		o.writeByte( regType(s.t) );
		o.writeUInt24(0); // indirect bits
	}

	function writeTex( t : Tex ) {
		var bits = texFlagsBits(t.flags);
		o.writeUInt16(t.index);
		o.writeUInt16(bits.bias);
		o.writeByte(5); // register type
		o.writeInt24(bits.flags);
	}

}
