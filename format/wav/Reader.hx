/*
 * format - Haxe File Formats
 *
 *  WAVE File Format
 *  Copyright (C) 2009 Robin Palotai
 *
 * Copyright (c) 2009, The Haxe Project Contributors
 * All rights reserved.
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 *	- Redistributions of source code must retain the above copyright
 *	  notice, this list of conditions and the following disclaimer.
 *	- Redistributions in binary form must reproduce the above copyright
 *	  notice, this list of conditions and the following disclaimer in the
 *	  documentation and/or other materials provided with the distribution.
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
package format.wav;
import format.wav.Data;

class Reader {

	var i : haxe.io.Input;
	var version : Int;

	public function new(i) {
		this.i = i;
		i.bigEndian = false;
	}

	inline function readInt() {
		#if haxe3
		return i.readInt32();
		#else
		return i.readUInt30();
		#end
	}

	public function read() : WAVE {

		if (i.readString(4) != "RIFF")
			throw "RIFF header expected";

		var len = readInt();

		if (i.readString(4) != "WAVE")
			throw "WAVE signature not found";

		var fmt = i.readString(4);
		while(fmt != "fmt ") {
			switch( fmt ) {
				case "JUNK": //protool
					var junkLen = i.readInt32();
					i.read(junkLen);
					fmt = i.readString(4);
				case "bext":
					var bextLen = i.readInt32();
					i.read(bextLen);
					fmt = i.readString(4);
				default:
					break;
			}
		}
		if ( fmt != "fmt " )
			throw "unsupported wave chunk "+fmt;

		var fmtlen = readInt();
		var format = switch (i.readUInt16()) {
			case 1,3: WF_PCM;
			default: throw "only PCM (uncompressed) WAV files are supported";
		}
		var channels = i.readUInt16();
		var samplingRate = readInt();
		var byteRate = readInt();
		var blockAlign = i.readUInt16();
		var bitsPerSample = i.readUInt16();

		if (fmtlen > 16)
			i.read(fmtlen - 16);

		var nextChunk = i.readString (4);
		while (nextChunk != "data") {
			// read past other subchunks
			i.read(readInt());
			nextChunk = i.readString (4);
		}

		// data
		if (nextChunk != "data")
			throw "expected data subchunk";

		var datalen = readInt();

		var data : haxe.io.Bytes;
		try {
			data = i.read(datalen);
		} catch (e : haxe.io.Eof) {
			throw "Invalid chunk data length";
		}

		var cuePoints = new Array<CuePoint>();
		try {

			while (true) {
				var nextChunk = i.readString (4);
				switch (nextChunk) {
					case "cue ":
						readInt();
						var nbCuePoints = readInt();

						for (_ in 0...nbCuePoints) {
							var cueId = readInt();
							readInt();
							i.readString(4);
							readInt();
							readInt();
							var cueSampleOffset = readInt();
							cuePoints.push({ id : cueId, sampleOffset: cueSampleOffset });
						}
					default:
						var n = readInt();
						if( n < 0 ) break;
						i.read(n);
				}
			}

		} catch (e : haxe.io.Eof) { }

		return {
			header: {
				format: format,
				channels: channels,
				samplingRate: samplingRate,
				byteRate: byteRate,
				blockAlign: blockAlign,
				bitsPerSample: bitsPerSample
			},
			data: data,
			cuePoints: cuePoints
		}
	}

}
