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
package format.tools;

class MemoryInput extends haxe.io.Input {

	var ba : flash.utils.ByteArray;
	var pos : Int;

	public function new( b : haxe.io.Bytes, ?pos ) {
		this.ba = b.getData();
		this.pos = pos;
		if( ba.length < 1024 )
			ba.length = 1024;
		select();
	}

	public function select() {
		flash.Memory.select(ba);
	}

	override function #if (haxe_211 || haxe3) set_bigEndian #else setEndian #end(b) {
		if( b ) throw "BigEndian is not supported on MemoryInput";
		return b;
	}

	public override inline function readByte() {
		return flash.Memory.getByte(pos++);
	}

	public override inline function readFloat() {
		var r = flash.Memory.getFloat(pos);
		pos += 4;
		return r;
	}

	public override inline function readDouble() {
		var r = flash.Memory.getDouble(pos);
		pos += 8;
		return r;
	}

	public override inline function readInt8() {
		var n = readByte();
		return n >= 128 ? n - 256 : n;
	}

	public override inline function readInt16() {
		var ch1 = readByte();
		var ch2 = readByte();
		var n = ch1 | (ch2 << 8);
		return n & 0x8000 != 0 ? n - 0x10000 : n;
	}

	public override inline function readUInt16() {
		var ch1 = readByte();
		var ch2 = readByte();
		return ch1 | (ch2 << 8);
	}

	public override inline function readInt24() {
		var ch1 = readByte();
		var ch2 = readByte();
		var ch3 = readByte();
		var n = ch1 | (ch2 << 8) | (ch3 << 16);
		return n & 0x800000 != 0 ? n - 0x1000000 : n;
	}

	public override inline function readUInt24() {
		var ch1 = readByte();
		var ch2 = readByte();
		var ch3 = readByte();
		return ch1 | (ch2 << 8) | (ch3 << 16);
	}

	#if haxe3

	public override inline function readInt32() {
		var ch1 = readByte();
		var ch2 = readByte();
		var ch3 = readByte();
		var ch4 = readByte();
		return (ch4 << 24) | (ch3 << 16) | (ch2 << 8) | ch1;
	}

	#else

	public override inline function readInt31() {
		var ch1 = readByte();
		var ch2 = readByte();
		var ch3 = readByte();
		var ch4 = readByte();
		if( ((ch4 & 128) == 0) != ((ch4 & 64) == 0) ) throw haxe.io.Error.Overflow;
		return ch1 | (ch2 << 8) | (ch3 << 16) | (ch4 << 24);
	}

	public override inline function readUInt30() {
		var ch1 = readByte();
		var ch2 = readByte();
		var ch3 = readByte();
		var ch4 = readByte();
		if( ch4 >= 64 ) throw haxe.io.Error.Overflow;
		return ch1 | (ch2 << 8) | (ch3 << 16) | (ch4 << 24);
	}

	public override inline function readInt32() {
		var ch1 = readByte();
		var ch2 = readByte();
		var ch3 = readByte();
		var ch4 = readByte();
		return haxe.Int32.make((ch4 << 8) | ch3, (ch2 << 8) | ch1);
	}

	#end

	// + format.tools.BitsInput API

	var nbits : Int;
	var bits : Int;

	public inline function readBits(n) {
		while( nbits < n ) {
			var k = readByte();
			if( nbits >= 24 ) throw "Bits error";
			bits = (bits << 8) | k;
			nbits += 8;
		}
		var c = nbits - n;
		var k = (bits >>> c) & ((1 << n) - 1);
		nbits = c;
		return k;
	}

	public inline function readBit() {
		if( nbits == 0 ) {
			bits = readByte();
			nbits = 8;
		}
		nbits--;
		return ((bits >>> nbits) & 1) == 1;
	}

	public inline function reset() {
		nbits = 0;
	}

}
