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
package format.flv;
import format.flv.Data;

class Writer {

	var ch : haxe.io.Output;

	public function new(o) {
		this.ch = o;
		o.bigEndian = true;
	}

	public static function readHeader( ch : haxe.io.Input ) {
		ch.bigEndian = true;
		if( ch.readString(3) != 'FLV' )
			throw "Invalid signature";
		if( ch.readByte() != 0x01 )
			throw "Invalid version";
		var flags = ch.readByte();
		if( flags & 0xF2 != 0 )
			throw "Invalid type flags "+flags;
		var offset = ch.readUInt30();
		if( offset != 0x09 )
			throw "Invalid offset "+offset;
		var prev = ch.readUInt30();
		if( prev != 0 )
			throw "Invalid prev "+prev;
		return {
			hasAudio : (flags & 1) != 1,
			hasVideo : (flags & 4) != 1,
			hasMeta : (flags & 8) != 1,
		};
	}

	public function writeHeader( h : Header ) {
		ch.writeString("FLV");
		ch.writeByte(0x01);
		ch.writeByte( (h.hasAudio?1:0) | (h.hasVideo?4:0) | (h.hasMeta?8:0) );
		ch.writeUInt30(0x09);
		ch.writeUInt30(0x00);
	}

	public function writeChunk( chunk : Data ) {
		var k, data, time;
		switch( chunk ) {
		case FLVAudio(d,t): k = 0x08; data = d; time = t;
		case FLVVideo(d,t): k = 0x09; data = d; time = t;
		case FLVMeta(d,t): k = 0x12; data = d; time = t;
		}
		ch.writeByte(k);
		ch.writeUInt24(data.length);
		ch.writeUInt24(time);
		ch.writeUInt30(0);
		ch.write(data);
		ch.writeUInt30(data.length + 11);
	}

}