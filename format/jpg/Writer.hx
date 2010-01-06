/*
 * format - haXe File Formats
 *
 *  JPG File Format
 *  Copyright (C) 2007-2009 Trevor McCauley, Baluta Cristian (hx port) & Robert Sköld (format conversion)
 *
 * Copyright (c) 2009, The haXe Project Contributors
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
package format.jpg;

import format.jpg.Data;

#if flash10
typedef TypedArray<T> = flash.Vector<T>;
#else
typedef TypedArray<T> = Array<T>;
#end


/**
 * Port from AS3
 * @author Kyle
 * @see http://elics.cn/kyle/projects/as3/JPGEncoder/
 *
 * Added async encoding option
 * Added merging BitmapData objects option
 * @author Euegene Zatepyakin
 * @see http://blog.inspirit.ru/?p=289
 */
class Writer {

	var output : haxe.io.Output;

	public function new( o ) {
		output = o;
		output.bigEndian = true;

		fdtblY = new TypedArray<Float>(#if flash10 64 , true #end);
		fdtblUV = new TypedArray<Float>(#if flash10 64 , true #end);
		outfDCTQuant = new TypedArray<Int>(#if flash10 64 , true #end);

		// Initialize blocks
		YDU = new TypedArray<Float>(#if flash10 64 , true #end);
		UDU = new TypedArray<Float>(#if flash10 64 , true #end);
		VDU = new TypedArray<Float>(#if flash10 64 , true #end);
		DU = new TypedArray<Int>(#if flash10 64 , true #end);

		// Initialize non-image-specific tables
		initHuffmanTables();
		initCategoryNumber();
		//initRGBYUVTable();
	}

	public function write( jpg : Data ) {
		var quality = jpg.header.quality;
		if( quality < 1 ) quality = 1;
		if( quality > 100 ) quality = 100;
		var scaleFactor = 0;
		if( quality < 50 )
			scaleFactor = Std.int( 5000 / quality );
		else
			scaleFactor = Std.int( 200 - ( quality << 1 ) );

		// Initialize tables
		initQuantTables( scaleFactor );

		// Write header
		writeHeader( jpg.header );

		// Encode 8x8 macroblocks
		var DCY = 0;
		var DCU = 0;
		var DCV = 0;
		bytepos = 7;
		bytenew = 0;
		var y = 0;
		var w = jpg.header.width * 4;
		var p = jpg.pixels;
		while( y < jpg.header.height ) {
			var x = 0;
			while( x < jpg.header.width ) {
				RGBtoYUV( p , ( w * y + x * 4 ) , w );
				DCY = processDU( YDU,  fdtblY, DCY,  HT_YDC,  HT_YAC );
				DCU = processDU( UDU, fdtblUV, DCU, HT_UVDC, HT_UVAC );
				DCV = processDU( VDU, fdtblUV, DCV, HT_UVDC, HT_UVAC );
				x += 8;
			}
			y += 8;
		}

		// Bit alignment of the EOI marker
		if( bytepos >= 0 )
			writeBits( new BitString( (1<<(bytepos+1))-1, bytepos+1 ) );

		writeWord( 0xFFD9 ); //EOI
	}

	public function writeAsync( jpg : Data , onProgress : Float -> Void , onComplete : Void -> Void ) {

	}


	var DU : TypedArray<Int>;
	var YDU : TypedArray<Float>;
	var UDU : TypedArray<Float>;
	var VDU : TypedArray<Float>;
	var HT_YDC : TypedArray<BitString>;
	var HT_UVDC : TypedArray<BitString>;
	var HT_YAC : TypedArray<BitString>;
	var HT_UVAC : TypedArray<BitString>;
	var bitcode : TypedArray<BitString>;
	var category : TypedArray<Int>;
	var YTable : TypedArray<Int>;
	var UVTable : TypedArray<Int>;
	var fdtblY : TypedArray<Float>;
	var fdtblUV : TypedArray<Float>;
	var outfDCTQuant : TypedArray<Int>;

	static inline function initArray<T>( arr : Array<T> ) : TypedArray<T> {
		#if flash10
		var v = flash.Lib.vectorOfArray( arr );
		v.length = arr.length;
		v.fixed = true;
		return v;
		#else
		return arr;
		#end
	}

	static var std_dc_luminance_nrcodes : TypedArray<Int> = initArray( [0,0,1,5,1,1,1,1,1,1,0,0,0,0,0,0,0] );
	static var std_dc_luminance_values : TypedArray<Int> = initArray( [0,1,2,3,4,5,6,7,8,9,10,11] );
	static var std_ac_luminance_nrcodes : TypedArray<Int> = initArray( [0,0,2,1,3,3,2,4,3,5,5,4,4,0,0,1,0x7d] );
	static var std_ac_luminance_values : TypedArray<Int> = initArray( [
		0x01,0x02,0x03,0x00,0x04,0x11,0x05,0x12,0x21,0x31,0x41,0x06,0x13,0x51,0x61,0x07,
		0x22,0x71,0x14,0x32,0x81,0x91,0xa1,0x08,0x23,0x42,0xb1,0xc1,0x15,0x52,0xd1,0xf0,
		0x24,0x33,0x62,0x72,0x82,0x09,0x0a,0x16,0x17,0x18,0x19,0x1a,0x25,0x26,0x27,0x28,
		0x29,0x2a,0x34,0x35,0x36,0x37,0x38,0x39,0x3a,0x43,0x44,0x45,0x46,0x47,0x48,0x49,
		0x4a,0x53,0x54,0x55,0x56,0x57,0x58,0x59,0x5a,0x63,0x64,0x65,0x66,0x67,0x68,0x69,
		0x6a,0x73,0x74,0x75,0x76,0x77,0x78,0x79,0x7a,0x83,0x84,0x85,0x86,0x87,0x88,0x89,
		0x8a,0x92,0x93,0x94,0x95,0x96,0x97,0x98,0x99,0x9a,0xa2,0xa3,0xa4,0xa5,0xa6,0xa7,
		0xa8,0xa9,0xaa,0xb2,0xb3,0xb4,0xb5,0xb6,0xb7,0xb8,0xb9,0xba,0xc2,0xc3,0xc4,0xc5,
		0xc6,0xc7,0xc8,0xc9,0xca,0xd2,0xd3,0xd4,0xd5,0xd6,0xd7,0xd8,0xd9,0xda,0xe1,0xe2,
		0xe3,0xe4,0xe5,0xe6,0xe7,0xe8,0xe9,0xea,0xf1,0xf2,0xf3,0xf4,0xf5,0xf6,0xf7,0xf8,
		0xf9,0xfa ] );

	static var std_dc_chrominance_nrcodes : TypedArray<Int> = initArray( [0,0,3,1,1,1,1,1,1,1,1,1,0,0,0,0,0] );
	static var std_dc_chrominance_values : TypedArray<Int> = initArray( [0,1,2,3,4,5,6,7,8,9,10,11] );
	static var std_ac_chrominance_nrcodes : TypedArray<Int> = initArray( [0,0,2,1,2,4,4,3,4,7,5,4,4,0,1,2,0x77] );
	static var std_ac_chrominance_values : TypedArray<Int> = initArray( [
		0x00,0x01,0x02,0x03,0x11,0x04,0x05,0x21,0x31,0x06,0x12,0x41,0x51,0x07,0x61,0x71,
		0x13,0x22,0x32,0x81,0x08,0x14,0x42,0x91,0xa1,0xb1,0xc1,0x09,0x23,0x33,0x52,0xf0,
		0x15,0x62,0x72,0xd1,0x0a,0x16,0x24,0x34,0xe1,0x25,0xf1,0x17,0x18,0x19,0x1a,0x26,
		0x27,0x28,0x29,0x2a,0x35,0x36,0x37,0x38,0x39,0x3a,0x43,0x44,0x45,0x46,0x47,0x48,
		0x49,0x4a,0x53,0x54,0x55,0x56,0x57,0x58,0x59,0x5a,0x63,0x64,0x65,0x66,0x67,0x68,
		0x69,0x6a,0x73,0x74,0x75,0x76,0x77,0x78,0x79,0x7a,0x82,0x83,0x84,0x85,0x86,0x87,
		0x88,0x89,0x8a,0x92,0x93,0x94,0x95,0x96,0x97,0x98,0x99,0x9a,0xa2,0xa3,0xa4,0xa5,
		0xa6,0xa7,0xa8,0xa9,0xaa,0xb2,0xb3,0xb4,0xb5,0xb6,0xb7,0xb8,0xb9,0xba,0xc2,0xc3,
		0xc4,0xc5,0xc6,0xc7,0xc8,0xc9,0xca,0xd2,0xd3,0xd4,0xd5,0xd6,0xd7,0xd8,0xd9,0xda,
		0xe2,0xe3,0xe4,0xe5,0xe6,0xe7,0xe8,0xe9,0xea,0xf2,0xf3,0xf4,0xf5,0xf6,0xf7,0xf8,
		0xf9,0xfa ] );

	static var ZigZag : TypedArray<Int> = initArray( [
		 0, 1, 5, 6,14,15,27,28,
		 2, 4, 7,13,16,26,29,42,
		 3, 8,12,17,25,30,41,43,
		 9,11,18,24,31,40,44,53,
		10,19,23,32,39,45,52,54,
		20,22,33,38,46,51,55,60,
		21,34,37,47,50,56,59,61,
		35,36,48,49,57,58,62,63
	] );

	static var YQT : TypedArray<Int> = initArray( [
		16, 11, 10, 16, 24, 40, 51, 61,
		12, 12, 14, 19, 26, 58, 60, 55,
		14, 13, 16, 24, 40, 57, 69, 56,
		14, 17, 22, 29, 51, 87, 80, 62,
		18, 22, 37, 56, 68,109,103, 77,
		24, 35, 55, 64, 81,104,113, 92,
		49, 64, 78, 87,103,121,120,101,
		72, 92, 95, 98,112,100,103, 99
	] );

	static var UVQT : TypedArray<Int> = initArray( [
		17, 18, 24, 47, 99, 99, 99, 99,
		18, 21, 26, 66, 99, 99, 99, 99,
		24, 26, 56, 99, 99, 99, 99, 99,
		47, 66, 99, 99, 99, 99, 99, 99,
		99, 99, 99, 99, 99, 99, 99, 99,
		99, 99, 99, 99, 99, 99, 99, 99,
		99, 99, 99, 99, 99, 99, 99, 99,
		99, 99, 99, 99, 99, 99, 99, 99
	] );

	static var AASF : TypedArray<Float> = initArray( [
		1.0, 1.387039845, 1.306562965, 1.175875602,
		1.0, 0.785694958, 0.541196100, 0.275899379
	] );


	function writeHeader( header : Header ) {
		writeWord(0xFFD8); // SOI
		writeAPP0();
		writeDQT();
		writeSOF0( header.width , header.height );
		writeDHT();
		writeSOS();
	}

	function initHuffmanTables() {
		HT_YDC 	= computeHuffmanTables( std_dc_luminance_nrcodes 	, std_dc_luminance_values );
		HT_UVDC = computeHuffmanTables( std_dc_chrominance_nrcodes 	, std_dc_chrominance_values );
		HT_YAC 	= computeHuffmanTables( std_ac_luminance_nrcodes 	, std_ac_luminance_values );
		HT_UVAC = computeHuffmanTables( std_ac_chrominance_nrcodes 	, std_ac_chrominance_values );
	}

	inline function computeHuffmanTables(nrcodes : TypedArray<Int>, stdTable : TypedArray<Int>) {
		var val = 0;
		var pos = 0;
		var HT = new TypedArray<BitString>(#if flash10 251 , true #end);
		for( k in 1...17 ) {
			for( j in 1...nrcodes[k]+1 ) {
				HT[stdTable[pos]] = new BitString( val , k );
				++val;
				++pos;
			}
			val<<=1;
		}
		return HT;
	}

	function initCategoryNumber() {
		bitcode = new TypedArray<BitString>( #if flash10 65535 , true #end );
		category = new TypedArray<Int>( #if flash10 65535 , true #end );
		var nrlower = 1;
		var nrupper = 2;
		var n = 1;
		for( cat in 1...16 ) {
			//Positive numbers
			for( nr in nrlower...nrupper ) {
				n = 32767 + nr;
				category[n] = cat;
				bitcode[n] = new BitString( nr , cat );
			}
			//Negative numbers
			var nrneg = -(nrupper-1);
			while( nrneg <= -nrlower ) {
				n = 32767 + nrneg;
				category[n] = cat;
				bitcode[n] = new BitString( nrupper - 1 + nrneg , cat );
				++nrneg;
			}
			nrlower <<= 1;
			nrupper <<= 1;
		}
	}

	function initQuantTables( sf : Int ) {
		// TODO These could be cached by "sf" so all jpgs with the same quality takes less time...

		YTable = new TypedArray<Int>( #if flash10 64 , true #end );
		for( i in 0...64 ) {
			YTable[ ZigZag[i] ] = scaledQuant( YQT[i] , sf );
		}

		UVTable = new TypedArray<Int>( #if flash10 64 , true #end );
		for( i in 0...64 ) {
			UVTable[ ZigZag[i] ] = scaledQuant( UVQT[i] , sf );
		}

		for( i in 0...64 ) {
			var z = ZigZag[i];
			var aasf = AASF[i >> 3] * AASF[i & 7] * 8.0;
			fdtblY[i]  = (1.0 / ( YTable[z] * aasf));
			fdtblUV[i] = (1.0 / (UVTable[z] * aasf));
		}
	}

	inline function scaledQuant( val : Int , sf : Int ) {
		var t = ( val * sf + 50 ) * .01;
		if( t <   1 ) t = 1;
		if( t > 255 ) t = 255;
		return Std.int( t );
	}

	inline function processDU (CDU:TypedArray<Float>, fdtbl:TypedArray<Float>, DC:Int, HTDC:TypedArray<BitString>, HTAC:TypedArray<BitString>) :Int {
		var EOB = HTAC[0x00];
		var M16zeroes = HTAC[0xF0];
		var DU_DCT = fDCTQuant(CDU, fdtbl);

		//ZigZag reorder
		for( i in 0...64 )
			DU[ZigZag[i]] = DU_DCT[i];

		var Diff = DU[0] - DC; DC = DU[0];

		//Encode DC
		if( Diff == 0 ) {
			writeBits( HTDC[0] ); // Diff might be 0
		} else {
			var d = 32767 + Diff;
			writeBits( HTDC[ category[d] >> 0 ] );
			writeBits( bitcode[d] );
		}

		//Encode ACs
		var endPos = 63;
		while( endPos > 0 && DU[ endPos ] == 0 ) --endPos;

		//endPos = first element in reverse order !=0
		if( endPos == 0 ) {
			writeBits(EOB);
		} else {
			var i = 1;
			while( i <= endPos ) {
				var startPos = i;
				while( DU[i] == 0 && i <= endPos )
					++i;
				var nrzeroes = i - startPos;
				if( nrzeroes >= 16 ) {
					for( i in 1...( nrzeroes >> 4 ) )
						writeBits( M16zeroes );
					nrzeroes = nrzeroes & 0xF;
				}
				var n = 32767 + DU[i];
				writeBits( HTAC[ ( ( nrzeroes << 4 ) + category[n] ) >> 0 ]);
				writeBits( bitcode[n] );
				++i;
			}
			if( endPos != 63 )
				writeBits( EOB );
		}
		return DC;
	}

	/* Slower on one encode, but probably faster on multiple...
	static var RGB_YUV_TABLE : TypedArray<Float> = new TypedArray<Float>(#if flash10 2048 , true #end);
	function initRGBYUVTable() {
		for( i in 0...256 ) {
			RGB_YUV_TABLE[i]      		=  19595 * i;
			RGB_YUV_TABLE[(i+ 256)>>0] 	=  38470 * i;
			RGB_YUV_TABLE[(i+ 512)>>0] 	=   7471 * i + 0x8000;
			RGB_YUV_TABLE[(i+ 768)>>0] 	= -11059 * i;
			RGB_YUV_TABLE[(i+1024)>>0] 	= -21709 * i;
			RGB_YUV_TABLE[(i+1280)>>0] 	=  32768 * i + 0x807FFF;
			RGB_YUV_TABLE[(i+1536)>>0] 	= -27439 * i;
			RGB_YUV_TABLE[(i+1792)>>0] 	= - 5329 * i;
		}
	}
	*/

	inline function RGBtoYUV( pixels : haxe.io.Bytes , start : Int , width : Int ) {
		var r : Int, g : Int, b : Int;
		var p = start;
		var col = -1;
		var row = 0;
		for( pos in 0...64 ) {
			// Using bitwise to find the position of the pixels
			row = pos >> 3; // ">> 3" equals "/ 8"
			col = ( pos & 7 ) * 4; // "& 7" equals "% 8"
			p = start + ( row * width ) + col;
			//var a = pixels.get( p );
			r = pixels.get( ++p );
			g = pixels.get( ++p );
			b = pixels.get( ++p );
			/* Using a counter to find the position of the pixels (no difference in speed)
			++p; // Alpha

			if( ++col == 7 ) {
				++row;
				col = -1;
				p = start + row * width; // Skip to next row
			}
			*/
#if flash
			// RGB2YUV with ColorMatrixFilter (this assumes using the fromBitmapData helper, which is bad!)
			// Also gives a bigger filesize.
			// TODO Can we verify that it's already been YUV:ed?
			/*
			YDU[pos] = r-128;
			UDU[pos] = g-128;
			VDU[pos] = b-128;
			*/

			YDU[pos] = ( (  0.29900 * r +  0.58700 * g +  0.11400 * b ) - 128 );
			UDU[pos] = ( ( -0.16874 * r + -0.33126 * g +  0.50000 * b ) );
			VDU[pos] = ( (  0.50000 * r + -0.41869 * g + -0.08131 * b ) );

			/*
			if( ++test < 30 ) {
				var px = a << 24 | r << 16 | g << 8 | b;
				trace( "start: " + start + " p: " + p + "   a:" + a + " r:" + r + " g:" + g + " b:" + b + " = " + px );
				//trace( "y:" + YDU[pos] + " u:" + UDU[pos] + " v:" + VDU[pos] );
			}
			*/
#else
			// RGB2YUV without ColorMatrixFilter
			YDU[pos] = ( (  0.29900 * r +  0.58700 * g +  0.11400 * b ) - 128 );
			UDU[pos] = ( ( -0.16874 * r + -0.33126 * g +  0.50000 * b ) );
			VDU[pos] = ( (  0.50000 * r + -0.41869 * g + -0.08131 * b ) );

			// Precalculated RGB2YUV without ColorMatrixFilter
			/*
			untyped { // Avoid "Float should be Int"-errors
			YDU[pos] = ((RGB_YUV_TABLE[r]             + RGB_YUV_TABLE[(g +  256)>>0] + RGB_YUV_TABLE[(b +  512)>>0]) >> 16)-128;
			UDU[pos] = ((RGB_YUV_TABLE[(r +  768)>>0] + RGB_YUV_TABLE[(g + 1024)>>0] + RGB_YUV_TABLE[(b + 1280)>>0]) >> 16)-128;
			VDU[pos] = ((RGB_YUV_TABLE[(r + 1280)>>0] + RGB_YUV_TABLE[(g + 1536)>>0] + RGB_YUV_TABLE[(b + 1792)>>0]) >> 16)-128;
			}
			*/
#end
		}
	}

	inline function fDCTQuant( data : TypedArray<Float> , fdtbl : TypedArray<Float> ) {
		var tmp0:Float, tmp1:Float, tmp2:Float, tmp3:Float, tmp4:Float, tmp5:Float, tmp6:Float, tmp7:Float;
		var tmp10:Float, tmp11:Float, tmp12:Float, tmp13:Float;
		var z1:Float, z2:Float, z3:Float, z4:Float, z5:Float, z11:Float, z13:Float;

		/* Pass 1: process rows. */
		var dataOff = 0;
		for( i in 0...8 ) {
			tmp0 = data[dataOff+0] + data[dataOff+7];
			tmp7 = data[dataOff+0] - data[dataOff+7];
			tmp1 = data[dataOff+1] + data[dataOff+6];
			tmp6 = data[dataOff+1] - data[dataOff+6];
			tmp2 = data[dataOff+2] + data[dataOff+5];
			tmp5 = data[dataOff+2] - data[dataOff+5];
			tmp3 = data[dataOff+3] + data[dataOff+4];
			tmp4 = data[dataOff+3] - data[dataOff+4];

			/* Even part */
			tmp10 = tmp0 + tmp3;	/* phase 2 */
			tmp13 = tmp0 - tmp3;
			tmp11 = tmp1 + tmp2;
			tmp12 = tmp1 - tmp2;

			data[dataOff+0] = tmp10 + tmp11; /* phase 3 */
			data[dataOff+4] = tmp10 - tmp11;

			z1 = (tmp12 + tmp13) * 0.707106781; /* c4 */
			data[dataOff+2] = tmp13 + z1; /* phase 5 */
			data[dataOff+6] = tmp13 - z1;

			/* Odd part */
			tmp10 = tmp4 + tmp5; /* phase 2 */
			tmp11 = tmp5 + tmp6;
			tmp12 = tmp6 + tmp7;

			/* The rotator is modified from fig 4-8 to avoid extra negations. */
			z5 = (tmp10 - tmp12) * 0.382683433; /* c6 */
			z2 = 0.541196100 * tmp10 + z5; /* c2-c6 */
			z4 = 1.306562965 * tmp12 + z5; /* c2+c6 */
			z3 = tmp11 * 0.707106781; /* c4 */

			z11 = tmp7 + z3;	/* phase 5 */
			z13 = tmp7 - z3;

			data[dataOff+5] = z13 + z2;	/* phase 6 */
			data[dataOff+3] = z13 - z2;
			data[dataOff+1] = z11 + z4;
			data[dataOff+7] = z11 - z4;

			dataOff += 8; /* advance pointer to next row */
		}

		/* Pass 2: process columns. */
		dataOff = 0;
		for (i in 0...8) {
			tmp0 = data[dataOff+ 0] + data[dataOff+56];
			tmp7 = data[dataOff+ 0] - data[dataOff+56];
			tmp1 = data[dataOff+ 8] + data[dataOff+48];
			tmp6 = data[dataOff+ 8] - data[dataOff+48];
			tmp2 = data[dataOff+16] + data[dataOff+40];
			tmp5 = data[dataOff+16] - data[dataOff+40];
			tmp3 = data[dataOff+24] + data[dataOff+32];
			tmp4 = data[dataOff+24] - data[dataOff+32];

			/* Even part */
			tmp10 = tmp0 + tmp3;	/* phase 2 */
			tmp13 = tmp0 - tmp3;
			tmp11 = tmp1 + tmp2;
			tmp12 = tmp1 - tmp2;

			data[dataOff+ 0] = tmp10 + tmp11; /* phase 3 */
			data[dataOff+32] = tmp10 - tmp11;

			z1 = (tmp12 + tmp13) * 0.707106781; /* c4 */
			data[dataOff+16] = tmp13 + z1; /* phase 5 */
			data[dataOff+48] = tmp13 - z1;

			/* Odd part */
			tmp10 = tmp4 + tmp5; /* phase 2 */
			tmp11 = tmp5 + tmp6;
			tmp12 = tmp6 + tmp7;

			/* The rotator is modified from fig 4-8 to avoid extra negations. */
			z5 = (tmp10 - tmp12) * 0.382683433; /* c6 */
			z2 = 0.541196100 * tmp10 + z5; /* c2-c6 */
			z4 = 1.306562965 * tmp12 + z5; /* c2+c6 */
			z3 = tmp11 * 0.707106781; /* c4 */

			z11 = tmp7 + z3;	/* phase 5 */
			z13 = tmp7 - z3;

			data[dataOff+40] = z13 + z2; /* phase 6 */
			data[dataOff+24] = z13 - z2;
			data[dataOff+ 8] = z11 + z4;
			data[dataOff+56] = z11 - z4;

			++dataOff; /* advance pointer to next column */
		}

		// Quantize/descale the coefficients
		for( i in 0...64 ) {
			// Apply the quantization and scaling factor & Round to nearest integer
			outfDCTQuant[i] = round( data[i] * fdtbl[i] );
		}
		return outfDCTQuant;
	}

	inline function round( v : Float ) : Int {
		return if( v > 0. )
			Std.int( v + .5 );
		else
			Std.int( v - .5 );
	}

	function writeAPP0() {
		writeWord(0xFFE0); // marker
		writeWord(16); // length
		writeByte(0x4A); // J
		writeByte(0x46); // F
		writeByte(0x49); // I
		writeByte(0x46); // F
		writeByte(0); // = "JFIF",'\0'
		writeByte(1); // versionhi
		writeByte(1); // versionlo
		writeByte(0); // xyunits
		writeWord(1); // xdensity
		writeWord(1); // ydensity
		writeByte(0); // thumbnwidth
		writeByte(0); // thumbnheight
	}

	function writeSOF0(width:Int, height:Int) {
		writeWord(0xFFC0); // marker
		writeWord(17);   // length, truecolor YUV JPG
		writeByte(8);    // precision
		writeWord(height);
		writeWord(width);
		writeByte(3);    // nrofcomponents
		writeByte(1);    // IdY
		writeByte(0x11); // HVY
		writeByte(0);    // QTY
		writeByte(2);    // IdU
		writeByte(0x11); // HVU
		writeByte(1);    // QTU
		writeByte(3);    // IdV
		writeByte(0x11); // HVV
		writeByte(1);    // QTV
	}

	function writeDQT() {
		writeWord(0xFFDB); // marker
		writeWord(132);	   // length
		writeByte(0);
		for( i in 0...64 )
			writeByte( YTable[i] );
		writeByte(1);
		for( i in 0...64 )
			writeByte( UVTable[i] );
	}

	function writeDHT() {
		writeWord(0xFFC4); // marker
		writeWord(0x01A2); // length

		writeByte(0); // HTYDCinfo
		for( i in 0...16 ) writeByte(std_dc_luminance_nrcodes[i+1]);
		for( i in 0...12 ) writeByte(std_dc_luminance_values[i]);

		writeByte(0x10); // HTYACinfo
		for( i in 0...16 ) writeByte(std_ac_luminance_nrcodes[i+1]);
		for( i in 0...162 ) writeByte(std_ac_luminance_values[i]);

		writeByte(1); // HTUDCinfo
		for( i in 0...16 ) writeByte(std_dc_chrominance_nrcodes[i+1]);
		for( i in 0...12 ) writeByte(std_dc_chrominance_values[i]);

		writeByte(0x11); // HTUACinfo
		for( i in 0...16 ) writeByte(std_ac_chrominance_nrcodes[i+1]);
		for( i in 0...162 ) writeByte(std_ac_chrominance_values[i]);
	}

	function writeSOS() {
		writeWord(0xFFDA); // marker
		writeWord(12); // length
		writeByte(3); // nrofcomponents
		writeByte(1); // IdY
		writeByte(0); // HTY
		writeByte(2); // IdU
		writeByte(0x11); // HTU
		writeByte(3); // IdV
		writeByte(0x11); // HTV
		writeByte(0); // Ss
		writeByte(0x3f); // Se
		writeByte(0); // Bf
	}

	var bytepos : Int;
	var bytenew : Int;
	function writeBits( bs : BitString ) {
		var value = bs.val;
		var posval = bs.len-1;
		while( posval >= 0 ) {
			if( value & ( 1 << posval ) != 0 ) {
				bytenew |= ( 1 << bytepos );
			}
			--posval;
			--bytepos;
			if( bytepos < 0 ) {
				if( bytenew == 0xFF ) {
					writeByte( 0xFF );
					writeByte( 0 );
				} else {
					writeByte( bytenew );
				}
				bytepos = 7;
				bytenew = 0;
			}
		}
	}

	function writeByte( value : Int ) {
		output.writeByte( value );
	}

	function writeWord( value : Int ) {
		writeByte( ( value >> 8 ) & 0xFF );
		writeByte( ( value		) & 0xFF );
	}

}

private class BitString {
	public var val : Int;
	public var len : Int;

	public function new( val : Int , len : Int ) {
		this.val = val;
		this.len = len;
	}
}