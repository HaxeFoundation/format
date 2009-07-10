/*
 * format - haXe File Formats
 *
 *  SWF File Format
 *  Copyright (C) 2004-2008 Nicolas Cannasse
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
package format.swf;
import format.swf.Data;
import format.swf.Constants;

class Writer {

	var output : haxe.io.Output;
	var o : haxe.io.BytesOutput;
	var compressed : Bool;
	var bits : format.tools.BitsOutput;

	public function new(o) {
		this.output = o;
	}

	public function write( s : SWF ) {
		writeHeader(s.header);
		for( t in s.tags )
			writeTag(t);
		writeEnd();
	}

	function writeRect(r) {
		var lr = (r.left > r.right) ? r.left : r.right;
		var bt = (r.top > r.bottom) ? r.top : r.bottom;
		var max = (lr > bt) ? lr : bt;
		var nbits = 1; // sign
		while( max > 0 ) {
			max >>= 1;
			nbits++;
		}
		bits.writeBits(5,nbits);
		bits.writeBits(nbits,r.left);
		bits.writeBits(nbits,r.right);
		bits.writeBits(nbits,r.top);
		bits.writeBits(nbits,r.bottom);
		bits.flush();
	}

	inline function writeFixed8(v) {
		o.writeUInt16(v);
	}

	inline function writeFixed(v) {
		o.writeInt32(v);
	}

	function openTMP() {
		var old = o;
		o = new haxe.io.BytesOutput();
		bits.o = o;
		return old;
	}

	function closeTMP(old) {
		var bytes = o.getBytes();
		o = old;
		bits.o = old;
		return bytes;
	}

	public function writeHeader( h : SWFHeader ) {
		compressed = h.compressed;
		output.writeString( compressed ? "CWS" : "FWS" );
		output.writeByte(h.version);
		o = new haxe.io.BytesOutput();
		bits = new format.tools.BitsOutput(o);
		writeRect({ left : 0, top : 0, right : h.width * 20, bottom : h.height * 20 });
		writeFixed8(h.fps);
		o.writeUInt16(h.nframes);
	}

	function writeRGBA( c : RGBA ) {
		o.writeByte(c.r);
		o.writeByte(c.g);
		o.writeByte(c.b);
		o.writeByte(c.a);
	}

	function writeMatrixPart( m : MatrixPart ) {
		bits.writeBits(5,m.nbits);
		bits.writeBits(m.nbits,m.x);
		bits.writeBits(m.nbits,m.y);
	}

	function writeMatrix( m : Matrix ) {
		if( m.scale != null ) {
			bits.writeBit(true);
			writeMatrixPart(m.scale);
		} else
			bits.writeBit(false);
		if( m.rotate != null ) {
			bits.writeBit(true);
			writeMatrixPart(m.rotate);
		} else
			bits.writeBit(false);
		writeMatrixPart(m.translate);
		bits.flush();
	}

	function writeCXAColor(c:RGBA,nbits) {
		bits.writeBits(nbits,c.r);
		bits.writeBits(nbits,c.g);
		bits.writeBits(nbits,c.b);
		bits.writeBits(nbits,c.a);
	}

	function writeCXA( c : CXA ) {
		bits.writeBit(c.add != null);
		bits.writeBit(c.mult != null);
		bits.writeBits(4,c.nbits);
		if( c.mult != null ) writeCXAColor(c.mult,c.nbits);
		if( c.add != null ) writeCXAColor(c.add,c.nbits);
		bits.flush();
	}

	function writeClipEvents( events : Array<ClipEvent> ) {
		o.writeUInt16(0);
		var all = 0;
		for( e in events )
			all |= e.eventsFlags;
		o.writeUInt30(all);
		for( e in events ) {
			o.writeUInt30(e.eventsFlags);
			o.writeUInt30(e.data.length);
			o.write(e.data);
		}
		o.writeUInt16(0);
	}

	function writeFilterFlags(f:FilterFlags,top) {
		var flags = 32;
		if( f.inner ) flags |= 128;
		if( f.knockout ) flags |= 64;
		if( f.ontop ) flags |= 16;
		flags |= f.passes;
		o.writeByte(flags);
	}

	function writeFilterGradient(f:GradientFilterData) {
		o.writeByte(f.colors.length);
		for( c in f.colors )
			writeRGBA(c.color);
		for( c in f.colors )
			o.writeByte(c.position);
		var d = f.data;
		writeFixed(d.blurX);
		writeFixed(d.blurY);
		writeFixed(d.angle);
		writeFixed(d.distance);
		writeFixed8(d.strength);
		writeFilterFlags(d.flags,true);
	}

	function writeFilter( f : Filter ) {
		switch( f ) {
		case FDropShadow(d):
			o.writeByte(0);
			writeRGBA(d.color);
			writeFixed(d.blurX);
			writeFixed(d.blurY);
			writeFixed(d.angle);
			writeFixed(d.distance);
			writeFixed8(d.strength);
			writeFilterFlags(d.flags,false);
		case FBlur(d):
			o.writeByte(1);
			writeFixed(d.blurX);
			writeFixed(d.blurY);
			o.writeByte(d.passes << 3);
		case FGlow(d):
			o.writeByte(2);
			writeRGBA(d.color);
			writeFixed(d.blurX);
			writeFixed(d.blurY);
			writeFixed8(d.strength);
			writeFilterFlags(d.flags,false);
		case FBevel(d):
			o.writeByte(3);
			writeRGBA(d.color);
			writeRGBA(d.color2);
			writeFixed(d.blurX);
			writeFixed(d.blurY);
			writeFixed(d.angle);
			writeFixed(d.distance);
			writeFixed8(d.strength);
			writeFilterFlags(d.flags,true);
		case FGradientGlow(d):
			o.writeByte(5);
			writeFilterGradient(d);
		case FColorMatrix(d):
			o.writeByte(6);
			for( f in d )
				o.writeFloat(f);
		case FGradientBevel(d):
			o.writeByte(7);
			writeFilterGradient(d);
		}
	}

	function writeFilters( filters : Array<Filter> ) {
		o.writeByte(filters.length);
		for( f in filters )
			writeFilter(f);
	}

	function writeBlendMode( b : BlendMode ) {
		o.writeByte(Type.enumIndex(b) + 1);
	}

	function writePlaceObject(po:PlaceObject,v3) {
		var f = 0, f2 = 0;
		if( po.move ) f |= 1;
		if( po.cid != null ) f |= 2;
		if( po.matrix != null ) f |= 4;
		if( po.color != null ) f |= 8;
		if( po.ratio != null ) f |= 16;
		if( po.instanceName != null ) f |= 32;
		if( po.clipDepth != null ) f |= 64;
		if( po.events != null ) f |= 128;
		if( po.filters != null ) f2 |= 1;
		if( po.blendMode != null ) f2 |= 2;
		if( po.bitmapCache ) f2 |= 4;
		o.writeByte(f);
		if( v3 )
			o.writeByte(f2);
		else if( f2 != 0 )
			throw "Invalid place object version";
		o.writeUInt16(po.depth);
		if( po.cid != null ) o.writeUInt16(po.cid);
		if( po.matrix != null ) writeMatrix(po.matrix);
		if( po.color != null ) writeCXA(po.color);
		if( po.ratio != null ) o.writeUInt16(po.ratio);
		if( po.instanceName != null ) {
			o.writeString(po.instanceName);
			o.writeByte(0);
		}
		if( po.clipDepth != null ) o.writeUInt16(po.clipDepth);
		if( po.filters != null ) writeFilters(po.filters);
		if( po.blendMode != null ) writeBlendMode(po.blendMode);
		if( po.events != null ) writeClipEvents(po.events);
	}

	function writeTID( id : Int, len : Int ) {
		var h = (id << 6);
		if( len < 63 )
			o.writeUInt16(h|len);
		else {
			o.writeUInt16(h|63);
			o.writeUInt30(len);
		}
	}

	function writeTIDExt( id : Int, len : Int ) {
		o.writeUInt16((id << 6)|63);
		o.writeUInt30(len);
	}

	function writeSymbols( sl : Array<SymData>, tagid : Int ) {
		var len = 2;
		for( s in sl )
			len += 2 + s.className.length + 1;
		writeTID(tagid,len);
		o.writeUInt16(sl.length);
		for( s in sl ) {
			o.writeUInt16(s.cid);
			o.writeString(s.className);
			o.writeByte(0);
		}
	}

	function writeSound( s : Sound ) {
		var len = 7 + switch( s.data ) {
			case SDMp3(_,data): data.length + 2;
			case SDRaw(data): data.length;
			case SDOther(data): data.length;
		};
		writeTIDExt(TagId.DefineSound, len);
		o.writeUInt16(s.sid);
		bits.writeBits(4, switch( s.format ) {
			case SFNativeEndianUncompressed: 0;
			case SFADPCM: 1;
			case SFMP3: 2;
			case SFLittleEndianUncompressed: 3;
			case SFNellymoser16k: 4;
			case SFNellymoser8k: 5;
			case SFNellymoser: 6;
			case SFSpeex: 11;
		});
		bits.writeBits(2, switch( s.rate ) {
			case SR5k: 0;
			case SR11k: 1;
			case SR22k: 2;
			case SR44k: 3;
		});
		bits.writeBit(s.is16bit);
		bits.writeBit(s.isStereo);
		bits.flush();
		o.writeInt32(s.samples);
		switch( s.data ) {
		case SDMp3(seek,data):
			o.writeInt16(seek);
			o.write(data);
		case SDRaw(data):
			o.write(data);
		case SDOther(data):
			o.write(data);
		};
	}

	public function writeTag( t : SWFTag ) {
		switch( t ) {
		case TUnknown(id,data):
			writeTID(id,data.length);
			o.write(data);

		case TShowFrame:
			writeTID(TagId.ShowFrame,0);

		case TShape(id, sdata):
			switch (sdata) {
			case SHDShape1(bounds, shapes):
				// TODO
			case SHDShape2(bounds, shapes):
				// TODO
			case SHDShape3(bounds, shapes):
				// TODO
			case SHDOther(ver, data):	
				writeTID([
					0,
					TagId.DefineShape,
					TagId.DefineShape2,
					TagId.DefineShape3,
					TagId.DefineShape4,
					TagId.DefineMorphShape2
					][ver],
					data.length + 2
				);
				o.writeUInt16(id);
				o.write(data);
			}

		case TBinaryData(id, data):
			writeTID(TagId.DefineBinaryData, data.length + 6);
			o.writeUInt16(id);
			o.writeUInt30(0);
			o.write(data);

		case TBackgroundColor(color):
			writeTID(TagId.SetBackgroundColor,3);
			o.writeUInt24(color);

		case TPlaceObject2(po):
			var t = openTMP();
			writePlaceObject(po,false);
			var bytes = closeTMP(t);
			writeTID(TagId.PlaceObject2,bytes.length);
			o.write(bytes);

		case TPlaceObject3(po):
			var t = openTMP();
			writePlaceObject(po,true);
			var bytes = closeTMP(t);
			writeTID(TagId.PlaceObject3,bytes.length);
			o.write(bytes);

		case TRemoveObject2(depth):
			writeTID(TagId.RemoveObject2,2);
			o.writeUInt16(depth);

		case TFrameLabel(label,anchor):
			var bytes = haxe.io.Bytes.ofString(label);
			writeTID(TagId.FrameLabel,bytes.length + 1 + (anchor?1:0));
			o.write(bytes);
			o.writeByte(0);
			if( anchor ) o.writeByte(1);

		case TClip(id,frames,tags):
			var t = openTMP();
			for( t in tags )
				writeTag(t);
			var bytes = closeTMP(t);
			writeTID(TagId.DefineSprite,bytes.length + 6);
			o.writeUInt16(id);
			o.writeUInt16(frames);
			o.write(bytes);
			o.writeUInt16(0); // end-tag

		case TDoInitActions(id,data):
			writeTID(TagId.DoInitAction,data.length + 2);
			o.writeUInt16(id);
			o.write(data);

		case TActionScript3(data,ctx):
			if( ctx == null )
				writeTID(TagId.RawABC,data.length);
			else {
				var len = data.length + 4 + ctx.label.length + 1;
				writeTID(TagId.DoABC,len);
				o.writeUInt30(ctx.id);
				o.writeString(ctx.label);
				o.writeByte(0);
			}
			o.write(data);

		case TSymbolClass(sl):
			writeSymbols(sl, TagId.SymbolClass);
		case TExportAssets(sl):
			writeSymbols(sl, TagId.ExportAssets);

		case TSandBox(n):
			writeTID(TagId.FileAttributes,4);
			o.writeUInt30(n);

		case TBitsLossless(l):
			var cbits = switch( l.color ) { case CM8Bits(n): n; default: null; };
			writeTIDExt(TagId.DefineBitsLossless,l.data.length + ((cbits == null)?8:7));
			o.writeUInt16(l.cid);
			switch( l.color ) {
			case CM8Bits(_): o.writeByte(3);
			case CM15Bits: o.writeByte(4);
			case CM24Bits: o.writeByte(5);
			default: throw "assert";
			}
			o.writeUInt16(l.width);
			o.writeUInt16(l.height);
			if( cbits != null ) o.writeByte(cbits);
			o.write(l.data);

		case TBitsLossless2(l):
			var cbits = switch( l.color ) { case CM8Bits(n): n; default: null; };
			writeTIDExt(TagId.DefineBitsLossless2,l.data.length + ((cbits == null)?7:8));
			o.writeUInt16(l.cid);
			switch( l.color ) {
			case CM8Bits(_): o.writeByte(3);
			case CM32Bits: o.writeByte(5);
			default: throw "assert";
			}
			o.writeUInt16(l.width);
			o.writeUInt16(l.height);
			if( cbits != null ) o.writeByte(cbits);
			o.write(l.data);

		case TJPEGTables(data):
			writeTIDExt(TagId.JPEGTables, data.length);
			o.write(data);

		case TBitsJPEG(id, jdata):
			switch (jdata) {
			case JDJPEG1(data):
				writeTIDExt(TagId.DefineBits, data.length + 2);
				o.writeUInt16(id);
				o.write(data);
			case JDJPEG2(data):
				writeTIDExt(TagId.DefineBitsJPEG2, data.length + 2);
				o.writeUInt16(id);
				o.write(data);
			case JDJPEG3(data, mask):	
				writeTIDExt(TagId.DefineBitsJPEG3, data.length + mask.length + 6);
				o.writeUInt16(id);
				o.writeUInt30(data.length);
				o.write(data);
				o.write(mask);
			}

		case TSound(data):
			writeSound(data);

		}
	}

	public function writeEnd() {
		o.writeUInt16(0); // end tag
		var bytes = o.getBytes();
		var size = bytes.length;
		if( compressed ) bytes = format.tools.Deflate.run(bytes);
		output.writeUInt30(size + 8);
		output.write(bytes);
	}

}
