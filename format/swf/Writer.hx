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

	function writeRGB( c : RGB ) {
		o.writeByte(c.r);
		o.writeByte(c.g);
		o.writeByte(c.b);
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

	function writeGradRecord(ver: Int, grad_record: GradRecord) {
		switch(grad_record) {
			case GRRGB(pos, col):
				if(ver > 2)
					throw "Shape versions higher than 2 require alpha channel in gradient control points!";
				o.writeByte(pos);
				writeRGB(col);

			case GRRGBA(pos, col):
				if(ver < 3)
					throw "Shape versions lower than 3 don't support alpha channel in gradient control points!";
				o.writeByte(pos);
				writeRGBA(col);
		}
	}

	function writeGradient(ver: Int, grad: Gradient) {
		var spread_mode = switch(grad.spread) {
			case SMPad: 		0;
			case SMReflect: 	1;
			case SMRepeat:		2;
			case SMReserved:	3;
		};
		var interpolation_mode = switch(grad.interpolate) {
			case IMNormalRGB:	0;
			case IMLinearRGB:	1;
			case IMReserved1:	2;
			case IMReserved2:	3;
		};
		if(ver < 4 && (spread_mode != 0 || interpolation_mode != 0))
			throw "Spread must be Pad and interpolation mode must be Normal RGB in gradient specification when shape version is lower than 4!";
		
		var num_records = grad.data.length;
		
		if(ver < 4) {
			if(num_records > 8)
				throw "Gradient supports at most 8 control points ("+num_records+" has bee given) when shape verison is lower than 4!";
		} else if(num_records > 15)
			throw "Gradient supports at most 15 control points ("+num_records+" has been given) at shape version 4!";

		bits.writeBits(2, spread_mode);
		bits.writeBits(2, interpolation_mode);
		bits.flush();

		for(grad_record in grad.data) {
			writeGradRecord(ver, grad_record);
		}
	}

	function writeFocalGradient(ver: Int, grad: FocalGradient) {
		if(ver < 4)
			throw "Focal gradient only supported in shape versions higher than 3!";

		writeGradient(ver, grad.data);
		writeFixed8(grad.focalPoint);
	}

	function writeFillStyle(ver: Int, fill_style: FillStyle) {
		switch(fill_style) {
			case FSSolid(rgb):
				if(ver > 2)
					throw "Fill styles with Shape versions higher than 2 reqire alhpa channel!";

				o.writeByte(FillStyleTypeId.Solid);
				writeRGB(rgb);

			case FSSolidAlpha(rgba):
				if(ver < 3)
					throw "Fill styles with Shape versions lower than 3 doesn't support alhpa channel!";
				
				o.writeByte(FillStyleTypeId.Solid);
				writeRGBA(rgba);
			
			case FSLinearGradient(mat, grad):
				o.writeByte(FillStyleTypeId.LinearGradient);
				writeMatrix(mat);
				writeGradient(ver, grad);
			
			case FSRadialGradient(mat, grad):
				o.writeByte(FillStyleTypeId.RadialGradient);
				writeMatrix(mat);
				writeGradient(ver, grad);

			case FSFocalGradient(mat, grad):
				if(ver > 3)
					throw "Focal gradient fill style only supported with Shape versions higher than 3!";

				o.writeByte(FillStyleTypeId.FocalRadialGradient);
				writeMatrix(mat);
				writeFocalGradient(ver, grad);

			case FSBitmap(cid, mat, repeat, smooth):
				o.writeByte( 
					if(repeat) {
						if(smooth)	FillStyleTypeId.RepeatingBitmap
						else			FillStyleTypeId.NonSmoothedRepeatingBitmap;
					} else {
						if(smooth)	FillStyleTypeId.ClippedBitmap
						else			FillStyleTypeId.NonSmoothedClippedBitmap;
					}
				);
				o.writeUInt16(cid);
				writeMatrix(mat);
		}
	}

	function writeFillStyles(ver: Int, fill_styles: Array<FillStyle>) {
		var num_styles = fill_styles.length;

		if(num_styles > 254) {
			if(ver >= 2) {
				o.writeByte(0xff);
				o.writeUInt16(num_styles);
			} else
				throw "Too much fill styles ("+num_styles+") for Shape version 1";
		} else
			o.writeByte(num_styles);

		for(style in fill_styles) {
			writeFillStyle(ver, style);
		}
	}

	function writeLineStyle(ver: Int, line_style: LineStyle) {
		o.writeUInt16(line_style.width);
		switch(line_style.data) {
			case LSRGB(rgb):
				if(ver > 2)
					throw "Line styles with Shape versions higher than 2 reqire alhpa channel!";
					writeRGB(rgb);

			case LSRGBA(rgba):
					if(ver < 3)
						throw "Line styles with Shape versions lower than 3 doesn't support alhpa channel!";
					writeRGBA(rgba);

			case LS2(data):
				if(ver < 4)
					throw "LineStyle version 2 only supported in shape versions higher than 3!";

				bits.writeBits(2, switch(data.startCap) {
					case LCRound:	0;
					case LCNone:	1;
					case LCSquare:	2;
				});
				
				bits.writeBits(2, switch(data.join) {
					case LJRound:					0;
					case LJBevel:					1;
					case LJMiter(limitFactor):	2;
				});

				bits.writeBit(switch(data.fill) {
					case LS2FColor(color):	false;
					case LS2FStyle(style):	true;
				});

				bits.writeBit(data.noHScale);
				bits.writeBit(data.noVScale);
				bits.writeBit(data.pixelHinting);
				bits.writeBits(5, 0);
				bits.writeBit(data.noClose);
				
				bits.writeBits(2, switch(data.endCap) {
					case LCRound:	0;
					case LCNone:	1;
					case LCSquare:	2;
				});

				switch(data.join) {
					case LJMiter(limitFactor):
						writeFixed8(limitFactor);
					default:
				}

				switch(data.fill) {
					case LS2FColor(color):	writeRGBA(color);
					case LS2FStyle(style):	writeFillStyle(ver, style);
				}
		} 
	}
	
	function writeLineStyles(ver: Int, line_styles: Array<LineStyle>) {
		var num_styles = line_styles.length;

		if(num_styles > 254) {
			if(ver >= 2) {
				o.writeByte(0xff);
				o.writeUInt16(num_styles);
			} else
				throw "Too much line styles ("+num_styles+") for Shape version 1";
		} else
			o.writeByte(num_styles);

		for(style in line_styles) {
			writeLineStyle(ver, style);
		}
	}

	function writeShapeRecord(ver: Int, bitcount: {fill: Int, line: Int}, shape_record: ShapeRecord) {
		switch(shape_record) {
			case SHREnd:
				bits.writeBit(false);
				bits.writeBits(5, 0);

			case SHRChange(data):
				bits.writeBit(false);
				if(data.newStyles != null) {
					if(ver == 2 || ver == 3)
						bits.writeBit(true);
					else
						throw "Defining new fill and line style arrays are only supported in shape version 2 and 3!";
				} else
					bits.writeBit(false);
				bits.writeBit(ver == 2 || ver == 3);
				bits.writeBit(data.lineStyle != null);
				bits.writeBit(data.fillStyle1 != null);
				bits.writeBit(data.fillStyle0 != null);
				bits.writeBit(data.moveTo != null);

				if(data.moveTo != null) {
					var mb = Tools.minBits([data.moveTo.dx, data.moveTo.dy]) + 1;

					bits.writeBits(5, mb);
					bits.writeBits(mb, Tools.signExtend(data.moveTo.dx, mb));
					bits.writeBits(mb, Tools.signExtend(data.moveTo.dy, mb));
				}

				if(data.fillStyle0 != null) {
					bits.writeBits(bitcount.fill, data.fillStyle0.idx);
				}
				
				if(data.fillStyle1 != null) {
					bits.writeBits(bitcount.fill, data.fillStyle1.idx);
				}
				
				if(data.lineStyle != null) {
					bits.writeBits(bitcount.line, data.lineStyle.idx);
				}

				if(data.newStyles != null) {
					writeFillStyles(ver, data.newStyles.fillStyles);
					writeLineStyles(ver, data.newStyles.lineStyles);
					bitcount.fill = Tools.minBits([data.newStyles.fillStyles.length]);
					bitcount.line = Tools.minBits([data.newStyles.lineStyles.length]);
					bits.writeBits(4, bitcount.fill);
					bits.writeBits(4, bitcount.line);
				}

			case SHREdge(dx, dy):
				bits.writeBit(true);
				bits.writeBit(true);
				
				var mb = Tools.minBits([dx, dy]);
				mb = if(mb < 2) 0 else mb - 2;
				bits.writeBits(4, mb);
				mb += 2;

				var is_general = (dx != 0) && (dy != 0);
				bits.writeBit(is_general);

				if(!is_general) {
					var is_vertical = (dx == 0);
					bits.writeBit(is_vertical);
					if(is_vertical)
						bits.writeBits(mb, Tools.signExtend(dy, mb));
					else
						bits.writeBits(mb, Tools.signExtend(dx, mb));
				} else {
					bits.writeBits(mb, Tools.signExtend(dx, mb));
					bits.writeBits(mb, Tools.signExtend(dy, mb));
				}
					
			case SHRCurvedEdge(cdx, cdy, adx, ady):
				bits.writeBit(true);
				bits.writeBit(false);
				
				var mb = Tools.minBits([cdx, cdy, adx, ady]);
				mb = if(mb < 2) 0 else mb - 2;
				bits.writeBits(4, mb);
				mb += 2;

				bits.writeBits(mb, Tools.signExtend(cdx, mb));
				bits.writeBits(mb, Tools.signExtend(cdy, mb));
				bits.writeBits(mb, Tools.signExtend(adx, mb));
				bits.writeBits(mb, Tools.signExtend(ady, mb));
		}
	}

	function writeShapeWithStyle(ver: Int, data: ShapeWithStyleData) {
		var bitcount: {
			var fill: Int;
			var line: Int;
		};

		if(data.fillStyles != null && data.lineStyles != null) {
			writeFillStyles(ver, data.fillStyles);
			writeLineStyles(ver, data.lineStyles);

			bitcount = {
				fill: Tools.minBits([data.fillStyles.length]),
				line: Tools.minBits([data.lineStyles.length]),
			};
		} else {
			bitcount = {
				fill: 1,
				line: 1,
			};
		}
		bits.writeBits(4, bitcount.fill);
		bits.writeBits(4, bitcount.line);
		bits.flush();

		for(shape_record in data.shapes) {
			writeShapeRecord(ver, bitcount, shape_record);
		}
		bits.flush();
	}
	
	public function writeShape(id: Int, data: ShapeData) {
		var old_o = o;
		var old_bits = bits;
		var o = new haxe.io.BytesOutput();
		var bits = new format.tools.BitsOutput(o);

		o.writeUInt16(id);

		switch(data) {
			case SHDShape1(bounds, shapes):
				writeRect(bounds);
				writeShapeWithStyle(1, shapes);

			case SHDShape2(bounds, shapes):
				writeRect(bounds);
				writeShapeWithStyle(2, shapes);

			case SHDShape3(bounds, shapes):
				writeRect(bounds);
				writeShapeWithStyle(3, shapes);

			case SHDShape4(data):
				writeRect(data.shapeBounds);
				writeRect(data.edgeBounds);
				bits.writeBits(5, 0);
				bits.writeBit(data.useWinding);
				bits.writeBit(data.useNonScalingStroke);
				bits.writeBit(data.useScalingStroke);
				bits.flush();
				writeShapeWithStyle(4, data.shapes);
		}

		bits.flush();
		var shape_data = o.getBytes();
		o = old_o;
		bits = old_bits;

		switch(data) {
			case SHDShape1(bounds, shapes):
				writeTID(TagId.DefineShape, shape_data.length);

			case SHDShape2(bounds, shapes):
				writeTID(TagId.DefineShape2, shape_data.length);

			case SHDShape3(bounds, shapes):
				writeTID(TagId.DefineShape3, shape_data.length);

			case SHDShape4(data):
				writeTID(TagId.DefineShape4, shape_data.length);
		}

		o.write(shape_data);
	}

	function writeMorphGradient(ver: Int, g: MorphGradient) {
		o.writeByte(g.startRatio);
		writeRGBA(g.startColor);
		o.writeByte(g.endRatio);
		writeRGBA(g.endColor);
	}

	function writeMorphGradients(ver: Int, gradients: Array<MorphGradient>) {
		var num = gradients.length;
		if(num < 1 || num > 8)
			throw "Number of specified morph gradients ("+num+") must be in range 1..8";

		for(grad in gradients) {
			writeMorphGradient(ver, grad);
		}
	}

	function writeMorphFillStyle(ver: Int, fill_style: MorphFillStyle) {
		switch(fill_style) {
			case MFSSolid(startColor, endColor):
				o.writeByte(FillStyleTypeId.Solid);
				writeRGBA(startColor);
				writeRGBA(endColor);

			case MFSLinearGradient(startMatrix, endMatrix, gradients):
				o.writeByte(FillStyleTypeId.LinearGradient);
				writeMatrix(startMatrix);
				writeMatrix(endMatrix);
				writeMorphGradients(ver, gradients);
			
			case MFSRadialGradient(startMatrix, endMatrix, gradients):
				o.writeByte(FillStyleTypeId.LinearGradient);
				writeMatrix(startMatrix);
				writeMatrix(endMatrix);
				writeMorphGradients(ver, gradients);

			case MFSBitmap(cid, startMatrix, endMatrix, repeat, smooth):
				o.writeByte( 
					if(repeat) {
						if(smooth)	FillStyleTypeId.RepeatingBitmap
						else			FillStyleTypeId.NonSmoothedRepeatingBitmap;
					} else {
						if(smooth)	FillStyleTypeId.ClippedBitmap
						else			FillStyleTypeId.NonSmoothedClippedBitmap;
					}
				);
				o.writeUInt16(cid);
				writeMatrix(startMatrix);
				writeMatrix(endMatrix);
		}
	}

	function writeMorphFillStyles(ver: Int, fill_styles: Array<MorphFillStyle>) {
		var num_styles = fill_styles.length;

		if(num_styles > 254) {
			o.writeByte(0xff);
			o.writeUInt16(num_styles);
		} else
			o.writeByte(num_styles);

		for(style in fill_styles) {
			writeMorphFillStyle(ver, style);
		}
	}

	function writeMorph1LineStyle(s: Morph1LineStyle) {
		o.writeUInt16(s.startWidth);
		o.writeUInt16(s.endWidth);
		writeRGBA(s.startColor);
		writeRGBA(s.endColor);
	}

	function writeMorph1LineStyles(line_styles: Array<Morph1LineStyle>) {
		var num_styles = line_styles.length;

		if(num_styles > 254) {
			o.writeByte(0xff);
			o.writeUInt16(num_styles);
		} else
			o.writeByte(num_styles);

		for(style in line_styles) {
			writeMorph1LineStyle(style);
		}
	}

	function writeMorph2LineStyle(style: Morph2LineStyle) {
		var m2data: Morph2LineStyleData;

		switch(style) {
			case M2LSNoFill(startColor, endColor, data):
				m2data = data;

			case M2LSFill(fill, data):
				m2data = data;
		}

		o.writeUInt16(m2data.startWidth);
		o.writeUInt16(m2data.endWidth);
		bits.writeBits(2, switch(m2data.startCapStyle) {
			case LCRound:	0;
			case LCNone:	1;
			case LCSquare:	2;
		});
		
		bits.writeBits(2, switch(m2data.joinStyle) {
			case LJRound:					0;
			case LJBevel:					1;
			case LJMiter(limitFactor):	2;
		});

		switch(style) {
			case M2LSNoFill(startColor, endColor, data):
				bits.writeBit(false);

			case M2LSFill(fill, data):
				bits.writeBit(true);
		}

		bits.writeBit(m2data.noHScale);
		bits.writeBit(m2data.noVScale);
		bits.writeBit(m2data.pixelHinting);
		bits.writeBits(5, 0);
		bits.writeBit(m2data.noClose);
		
		bits.writeBits(2, switch(m2data.endCapStyle) {
			case LCRound:	0;
			case LCNone:	1;
			case LCSquare:	2;
		});

		switch(m2data.joinStyle) {
			case LJMiter(limitFactor):
				writeFixed8(limitFactor);
			default:
		}

		switch(style) {
			case M2LSNoFill(startColor, endColor, data):
				writeRGBA(startColor);
				writeRGBA(endColor);

			case M2LSFill(fill, data):
				writeMorphFillStyle(2, fill);
		}
	}
	
	function writeMorph2LineStyles(line_styles: Array<Morph2LineStyle>) {
		var num_styles = line_styles.length;

		if(num_styles > 254) {
			o.writeByte(0xff);
			o.writeUInt16(num_styles);
		} else
			o.writeByte(num_styles);

		for(style in line_styles) {
			writeMorph2LineStyle(style);
		}
	}

	public function writeMorphShape(id: Int, data: MorphShapeData) {
		var old_o = o;
		var old_bits = bits;
		var o = new haxe.io.BytesOutput();
		var bits = new format.tools.BitsOutput(o);

		o.writeUInt16(id);

		switch(data) {
			case MSDShape1(sh1data):
				writeRect(sh1data.startBounds);
				writeRect(sh1data.endBounds);

				var old_o = o;
				var old_bits = bits;
				var o = new haxe.io.BytesOutput();
				var bits = new format.tools.BitsOutput(o);

				writeMorphFillStyles(1, sh1data.fillStyles);
				writeMorph1LineStyles(sh1data.lineStyles);
				writeShapeWithStyle(3, sh1data.startEdges);
				bits.flush();
				
				var part_data = o.getBytes();
				o = old_o;
				bits = old_bits;

				o.writeUInt30(part_data.length);
				o.write(part_data);
				writeShapeWithStyle(3, sh1data.endEdges);

			case MSDShape2(sh2data):
				writeRect(sh2data.startBounds);
				writeRect(sh2data.endBounds);
				writeRect(sh2data.startEdgeBounds);
				writeRect(sh2data.endEdgeBounds);
				bits.writeBits(6, 0);
				bits.writeBit(sh2data.useNonScalingStrokes);
				bits.writeBit(sh2data.useScalingStrokes);
				bits.flush();

				var old_o = o;
				var old_bits = bits;
				var o = new haxe.io.BytesOutput();
				var bits = new format.tools.BitsOutput(o);

				writeMorphFillStyles(1, sh2data.fillStyles);
				writeMorph2LineStyles(sh2data.lineStyles);
				writeShapeWithStyle(4, sh2data.startEdges);
				bits.flush();
				
				var part_data = o.getBytes();
				o = old_o;
				bits = old_bits;

				o.writeUInt30(part_data.length);
				o.write(part_data);
				writeShapeWithStyle(4, sh2data.endEdges);
		}

		bits.flush();
		var morph_shape_data = o.getBytes();
		o = old_o;
		bits = old_bits;

		switch(data) {
			case MSDShape1(sh1data):
				writeTID(TagId.DefineMorphShape, morph_shape_data.length);
			
			case MSDShape2(sh2data):
				writeTID(TagId.DefineMorphShape2, morph_shape_data.length);

		}

		o.write(morph_shape_data);
	}

	public function writeTag( t : SWFTag ) {
		switch( t ) {
		case TUnknown(id,data):
			writeTID(id,data.length);
			o.write(data);

		case TShowFrame:
			writeTID(TagId.ShowFrame,0);

		case TShape(id, sdata):
			writeShape(id, sdata);

		case TMorphShape(id, data):
			writeMorphShape(id, data);

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
