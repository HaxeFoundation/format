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

	public function writeTag( t : SWFTag ) {
		switch( t ) {
		case TUnknown(id,data):
			writeTID(id,data.length);
			o.write(data);
		case TShowFrame:
			writeTID(0x01,0);
		case TShape(id,ver,data):
			writeTID([0,0x02,0x16,0x20,0x53,0x54][ver],data.length + 2);
			o.writeUInt16(id);
			o.write(data);
		case TPlaceObject2(po):
			var t = openTMP();
			writePlaceObject(po,false);
			var bytes = closeTMP(t);
			writeTID(0x1A,bytes.length);
			o.write(bytes);
		case TPlaceObject3(po):
			var t = openTMP();
			writePlaceObject(po,true);
			var bytes = closeTMP(t);
			writeTID(0x46,bytes.length);
			o.write(bytes);
		case TRemoveObject2(depth):
			writeTID(0x1C,2);
			o.writeUInt16(depth);
		case TFrameLabel(label,anchor):
			writeTID(0x2B,label.length + 1 + (anchor?1:0));
			o.writeString(label);
			o.writeByte(0);
			if( anchor ) o.writeByte(1);
		case TClip(id,frames,tags):
			var t = openTMP();
			for( t in tags )
				writeTag(t);
			var bytes = closeTMP(t);
			writeTID(0x27,bytes.length + 6);
			o.writeUInt16(id);
			o.writeUInt16(frames);
			o.write(bytes);
			o.writeUInt16(0); // end-tag
		case TDoInitActions(id,data):
			writeTID(0x3B,data.length + 2);
			o.writeUInt16(id);
			o.write(data);
		case TActionScript3(data,ctx):
			if( ctx == null )
				writeTID(0x48,data.length);
			else {
				var len = data.length + 4 + ctx.label.length + 1;
				writeTID(0x52,len);
				o.writeUInt30(ctx.id);
				o.writeString(ctx.label);
				o.writeByte(0);
			}
			o.write(data);
		case TSymbolClass(sl):
			var len = 2;
			for( s in sl )
				len += 2 + s.className.length + 1;
			writeTID(0x4C,len);
			o.writeUInt16(sl.length);
			for( s in sl ) {
				o.writeUInt16(s.cid);
				o.writeString(s.className);
				o.writeByte(0);
			}
		case TSandBox(n):
			writeTID(0x45,4);
			o.writeUInt30(n);
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