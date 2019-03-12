/*
 * format - Haxe File Formats
 *
 * Copyright (c) 2008, The Haxe Project Contributors
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
package format.zip;
import format.zip.Data;

class Tools {

	public static function uncompress( f : Entry ) {
		if( !f.compressed )
			return;
		#if neko
		var c = new neko.zip.Uncompress(-15);
		var s = haxe.io.Bytes.alloc(f.fileSize);
		var r = c.execute(f.data,0,s,0);
		c.close();
		if( !r.done || r.read != f.data.length || r.write != f.fileSize )
			throw "Invalid compressed data for "+f.fileName;
		f.compressed = false;
		f.dataSize = f.fileSize;
		f.data = s;
		#else
		throw "No uncompress support";
		#end
	}

	public static function compress( f : Entry, level : Int ) {
		if( f.compressed )
			return;
		#if neko
		// this should be optimized with a temp buffer
		// that would discard the first two bytes
		// (in order to prevent 2x mem usage for large files)
		var data = neko.zip.Compress.run( f.data, level );
		f.compressed = true;
		f.data = data.sub(2,data.length-6);
		f.dataSize = f.data.length;
		#else
		throw "No compress support";
		#end
	}

}
