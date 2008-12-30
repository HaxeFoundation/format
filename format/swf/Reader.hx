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

class Reader {

	var i : haxe.io.Input;
	var bits : format.tools.BitsInput;
	var version : Int;

	public function new(i) {
		this.i = i;
	}

	inline function readFixed8() {
		return i.readUInt16();
	}

	inline function readFixed() {
		return i.readInt32();
	}

	function readUTF8Bytes() {
		var b = new haxe.io.BytesBuffer();
		while( true ) {
			var c = i.readByte();
			if( c == 0 ) break;
			b.addByte(c);
		}
		return b.getBytes();
	}

	function readRect() {
		bits.reset();
		var nbits = bits.readBits(5);
		return {
			left : bits.readBits(nbits),
			right : bits.readBits(nbits),
			top : bits.readBits(nbits),
			bottom : bits.readBits(nbits),
		};
	}

	function readMatrixPart() : MatrixPart {
		var nbits = bits.readBits(5);
		return {
			nbits : nbits,
			x : bits.readBits(nbits),
			y : bits.readBits(nbits),
		};
	}

	function readMatrix() : Matrix {
		bits.reset();
		return {
			scale : if( bits.read() ) readMatrixPart() else null,
			rotate : if( bits.read() ) readMatrixPart() else null,
			translate : readMatrixPart(),
		};
	}

	function readRGBA() : RGBA {
		return {
			r : i.readByte(),
			g : i.readByte(),
			b : i.readByte(),
			a : i.readByte(),
		};
	}

	function readCXAColor(nbits) : RGBA {
		return {
			r : bits.readBits(nbits),
			g : bits.readBits(nbits),
			b : bits.readBits(nbits),
			a : bits.readBits(nbits),
		};
	}

	function readCXA() : CXA {
		bits.reset();
		var add = bits.read();
		var mult = bits.read();
		var nbits = bits.readBits(4);
		return {
			nbits : nbits,
			mult : if( mult ) readCXAColor(nbits) else null,
			add : if( add ) readCXAColor(nbits) else null,
		};
	}

	function readClipEvents() : Array<ClipEvent> {
		if( i.readUInt16() != 0 ) throw error();
		i.readUInt30(); // all events flags
		var a = new Array();
		while( true ) {
			var code = i.readUInt30();
			if( code == 0 ) break;
			var data = i.read(i.readUInt30());
			a.push({ eventsFlags : code, data : data });
		}
		return a;
	}

	function readFilterFlags(top) {
		var flags = i.readByte();
		return {
			inner : flags & 128 != 0,
			knockout : flags & 64 != 0,
			// composite : flags & 32 != 0, // always 1 ?
			ontop : top ? (flags & 16 != 0) : false,
			passes : flags & (top ? 15 : 31),
		};
	}

	function readFilterGradient() : GradientFilterData {
		var ncolors = i.readByte();
		var colors = new Array();
		for( i in 0...ncolors )
			colors.push({ color : readRGBA(), position : 0 });
		for( c in colors )
			c.position = i.readByte();
		var data : FilterData = {
			color : null,
			color2 : null,
			blurX : readFixed(),
			blurY : readFixed(),
			angle : readFixed(),
			distance : readFixed(),
			strength : readFixed8(),
			flags : readFilterFlags(true),
		};
		return {
			colors : colors,
			data : data,
		};
	}

	function readFilter() {
		var n = i.readByte();
		return switch( n ) {
			case 0: FDropShadow({
				color : readRGBA(),
				color2 : null,
				blurX : readFixed(),
				blurY : readFixed(),
				angle : readFixed(),
				distance : readFixed(),
				strength : readFixed8(),
				flags : readFilterFlags(false),
			});
			case 1: FBlur({
				blurX : readFixed(),
				blurY : readFixed(),
				passes : i.readByte() >> 3
			});
			case 2: FGlow({
				color : readRGBA(),
				color2 : null,
				blurX : readFixed(),
				blurY : readFixed(),
				angle : haxe.Int32.ofInt(0),
				distance : haxe.Int32.ofInt(0),
				strength : readFixed8(),
				flags : readFilterFlags(false),
			});
			case 3: FBevel({
				color : readRGBA(),
				color2 : readRGBA(),
				blurX : readFixed(),
				blurY : readFixed(),
				angle : readFixed(),
				distance : readFixed(),
				strength : readFixed8(),
				flags : readFilterFlags(true),
			});
			case 5:
				// ConvolutionFilter
				throw error();
			case 4: FGradientGlow(readFilterGradient());
			case 6:
				var a = new Array();
				for( n in 0...20 )
					a.push(i.readFloat());
				FColorMatrix(a);
			case 7: FGradientBevel(readFilterGradient());
			default:
				throw error();
				null;
		}
	}

	function readFilters() {
		var filters = new Array();
		for( i in 0...i.readByte() )
			filters.push(readFilter());
		return filters;
	}

	function error() {
		return "Invalid SWF";
	}

	public function readHeader() : SWFHeader {
		var tag = i.readString(3);
		var compressed;
		if( tag == "CWS" )
			compressed = true;
		else if( tag == "FWS" )
			compressed = false;
		else
			throw error();
		version = i.readByte();
		var size = i.readUInt30();
		if( compressed ) {
			var bytes = format.tools.Inflate.run(i.readAll());
			if( bytes.length + 8 != size ) throw error();
			i = new haxe.io.BytesInput(bytes);
		}
		bits = new format.tools.BitsInput(i);
		var r = readRect();
		if( r.left != 0 || r.top != 0 || r.right % 20 != 0 || r.bottom % 20 != 0 )
			throw error();
		var fps = readFixed8();
		var nframes = i.readUInt16();
		return {
			version : version,
			compressed : compressed,
			width : Std.int(r.right/20),
			height : Std.int(r.bottom/20),
			fps : fps,
			nframes : nframes,
		};
	}

	public function readTagList() {
		var a = new Array();
		while( true ) {
			var t = readTag();
			if( t == null )
				break;
			a.push(t);
		}
		return a;
	}

	function readShape(len,ver) {
		var id = i.readUInt16();
		return TShape(id,ver,i.read(len - 2));
	}

	function readBlendMode() {
		return switch( i.readByte() ) {
		case 0,1: BNormal;
		case 2: BLayer;
		case 3: BMultiply;
		case 4: BScreen;
		case 5: BLighten;
		case 6: BDarken;
		case 7: BAdd;
		case 8: BSubtract;
		case 9: BDifference;
		case 10: BInvert;
		case 11: BAlpha;
		case 12: BErase;
		case 13: BOverlay;
		case 14: BHardLight;
		default: throw error();
		}
	}

	function readPlaceObject(v3) : PlaceObject {
		var f = i.readByte();
		var f2 = if( v3 ) i.readByte() else 0;
		if( f2 >> 3 != 0 ) throw error(); // unsupported bit flags
		var po = new PlaceObject();
		po.depth = i.readUInt16();
		if( f & 1 != 0 ) po.move = true;
		if( f & 2 != 0 ) po.cid = i.readUInt16();
		if( f & 4 != 0 ) po.matrix = readMatrix();
		if( f & 8 != 0 ) po.color = readCXA();
		if( f & 16 != 0 ) po.ratio = i.readUInt16();
		if( f & 32 != 0 ) po.instanceName = readUTF8Bytes().toString();
		if( f & 64 != 0 ) po.clipDepth = i.readUInt16();
		if( f2 & 1 != 0 ) po.filters = readFilters();
		if( f2 & 2 != 0 ) po.blendMode = readBlendMode();
		if( f2 & 4 != 0 ) po.bitmapCache = true;
		if( f & 128 != 0 ) po.events = readClipEvents();
		return po;
	}

	function readLossless(len,v2) {
		return {
			cid : i.readUInt16(),
			bits : switch( i.readByte() ) {
				case 3: 8;
				case 4: 15;
				case 5: if( v2 ) 32 else 24;
				default: throw error();
			},
			width : i.readUInt16(),
			height : i.readUInt16(),
			data : i.read(len - 7),
		};
	}

	public function readTag() : SWFTag {
		var h = i.readUInt16();
		var id = h >> 6;
		var len = h & 63;
		var ext = false;
		if( len == 63 ) {
			len = i.readUInt30();
			if( len < 63 ) ext = true;
		}
		return switch( id ) {
		case 0x00:
			null;
		case 0x01:
			TShowFrame;
		case 0x02:
			readShape(len,1);
		case 0x14:
			TBitsLossless(readLossless(len,false));
		case 0x16:
			readShape(len,2);
		case 0x1A:
			TPlaceObject2(readPlaceObject(false));
		case 0x1C:
			TRemoveObject2(i.readUInt16());
		case 0x20:
			readShape(len,3);
		case 0x24:
			TBitsLossless2(readLossless(len,true));
		case 0x27:
			var cid = i.readUInt16();
			var fcount = i.readUInt16();
			var tags = readTagList();
			TClip(cid,fcount,tags);
		case 0x2B:
			var label = readUTF8Bytes();
			var anchor = if( len == label.length + 2 ) i.readByte() == 1 else false;
			TFrameLabel(label.toString(),anchor);
		case 0x3B:
			var cid = i.readUInt16();
			TDoInitActions(cid,i.read(len-2));
		case 0x45:
			TSandBox(i.readUInt30());
		case 0x46:
			TPlaceObject3(readPlaceObject(true));
		case 0x48:
			TActionScript3(i.read(len),null);
		case 0x4C:
			var sl = new Array();
			for( n in 0...i.readUInt16() )
				sl.push({
					cid : i.readUInt16(),
					className : i.readUntil(0),
				});
			TSymbolClass(sl);
		case 0x52:
			var infos = {
				id : i.readUInt30(),
				label : i.readUntil(0),
			};
			len -= 4 + infos.label.length + 1;
			TActionScript3(i.read(len),infos);
		case 0x53:
			readShape(len,4);
		case 0x54:
			readShape(len,5);
		default:
			var data = i.read(len);
			TUnknown(id,data);
		}
	}

	public function read() : SWF {
		return {
			header : readHeader(),
			tags : readTagList(),
		};
	}

}