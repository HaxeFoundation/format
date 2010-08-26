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
package format.as1;
import format.as1.Data;

class Reader {

	var i : haxe.io.Input;
	var tmp : haxe.io.Bytes;

	public function new(i) {
		this.i = i;
		tmp = haxe.io.Bytes.alloc(8);
	}

	public function read() : AS1 {
		var actions = new Array();
		while( true ) {
			var a = readAction();
			if( a == AEnd )
				break;
			actions.push(a);
		}
		return actions;
	}

	inline function readString() {
		return readUTF8String();
	}

	function readUTF8String() {
		var b = new haxe.io.BytesBuffer();
		while( true ) {
			var c = i.readByte();
			if( c == 0 ) break;
			b.addByte(c);
		}
		return b.getBytes().toString();
	}

	function readDouble() {
		tmp.set(4, i.readByte());
		tmp.set(5, i.readByte());
		tmp.set(6, i.readByte());
		tmp.set(7, i.readByte());
		tmp.set(0, i.readByte());
		tmp.set(1, i.readByte());
		tmp.set(2, i.readByte());
		tmp.set(3, i.readByte());
		return new haxe.io.BytesInput(tmp).readDouble();
	}

	function parsePushItems( data : haxe.io.Bytes ) {
		var items = new Array();
		var old = i;
		i = new haxe.io.BytesInput(data);
		var code = 0;
		while( true ) {
			try
				code = i.readByte()
			catch( e : haxe.io.Eof ) {
				break;
			}
			items.push(switch(code) {
			case 0: PString(readString());
			case 1: PFloat(i.readFloat());
			case 2: PNull;
			case 3: PUndefined;
			case 4: PReg(i.readByte());
			case 5: PBool(i.readByte() != 0);
			case 6: PDouble(readDouble());
			case 7: PInt(i.readInt32());
			case 8: PStack(i.readByte());
			case 9: PStack2(i.readUInt16());
			default: throw "Unknown#" + code;
			});
		}
		i = old;
		return items;
	}

	function readAction() {
		var id = i.readByte();
		var len = (id >= 0x80) ? i.readUInt16() : 0;
		if( len == 0xFFFF )
			len = 0;
		return switch( id ) {
			// basic actions
			case 0x00: AEnd;
			case 0x04: ANextFrame;
			case 0x05: APrevFrame;
			case 0x06: APlay;
			case 0x07: AStop;
			case 0x08: AToggleHighQuality;
			case 0x09: AStopSounds;
			case 0x0A: AAddNum;
			case 0x0B: ASubtract;
			case 0x0C: AMultiply;
			case 0x0D: ADivide;
			case 0x0E: ACompareNum;
			case 0x0F: AEqualNum;
			case 0x10: ALogicalAnd;
			case 0x11: ALogicalOr;
			case 0x12: ANot;
			case 0x13: AStringEqual;
			case 0x14: AStringLength;
			case 0x15: ASubString;
			case 0x17: APop;
			case 0x18: AToInt;
			case 0x1C: AEval;
			case 0x1D: ASet;
			case 0x20: ATellTarget;
			case 0x21: AStringAdd;
			case 0x22: AGetProperty;
			case 0x23: ASetProperty;
			case 0x24: ADuplicateMC;
			case 0x25: ARemoveMC;
			case 0x26: ATrace;
			case 0x27: AStartDrag;
			case 0x28: AStopDrag;
			case 0x2A: AThrow;
			case 0x2B: ACast;
			case 0x2C: AImplements;
			case 0x2D: AFSCommand2;
			case 0x30: ARandom;
			case 0x31: AMBStringLength;
			case 0x32: AOrd;
			case 0x33: AChr;
			case 0x34: AGetTimer;
			case 0x35: AMBStringSub;
			case 0x36: AMBOrd;
			case 0x37: AMBChr;
			case 0x3A: ADeleteObj;
			case 0x3B: ADelete;
			case 0x3C: ALocalAssign;
			case 0x3D: ACall;
			case 0x3E: AReturn;
			case 0x3F: AMod;
			case 0x40: ANew;
			case 0x41: ALocalVar;
			case 0x42: AInitArray;
			case 0x43: AObject;
			case 0x44: ATypeOf;
			case 0x45: ATargetPath;
			case 0x46: AEnum;
			case 0x47: AAdd;
			case 0x48: ACompare;
			case 0x49: AEqual;
			case 0x4A: AToNumber;
			case 0x4B: AToString;
			case 0x4C: ADup;
			case 0x4D: ASwap;
			case 0x4E: AObjGet;
			case 0x4F: AObjSet;
			case 0x50: AIncrement;
			case 0x51: ADecrement;
			case 0x52: AObjCall;
			case 0x53: ANewMethod;
			case 0x54: AInstanceOf;
			case 0x55: AEnum2;
			case 0x60: AAnd;
			case 0x61: AOr;
			case 0x62: AXor;
			case 0x63: AShl;
			case 0x64: AShr;
			case 0x65: AAsr;
			case 0x66: APhysEqual;
			case 0x67: AGreater;
			case 0x68: AStringGreater;
			case 0x69: AExtends;
			// extended actions
			case 0x81:
				AGotoFrame(i.readUInt16());
			case 0x83:
				var url = readString();
				var target = readString();
				AGetURL(url, target);
			case 0x87:
				ASetReg(i.readByte());
			case 0x88:
				var strings = new Array();
				for( i in 0...i.readUInt16() )
					strings.push(readString());
				AStringPool(strings);
			case 0x8A:
				var frame = i.readUInt16();
				var skip = i.readByte();
				AWaitForFrame(frame, skip);
			case 0x8B:
				ASetTarget(readString());
			case 0x8C:
				AGotoLabel(readString());
			case 0x8D:
				AWaitForFrame2(i.readByte());
			case 0x8E:
				var name = readString();
				var nargs = i.readUInt16();
				var nregs = i.readByte();
				var flags = i.readUInt16();
				var args = new Array();
				for( n in 0...nargs ) {
					var r = i.readByte();
					var s = readString();
					args.push( { name : s, reg : r } );
				}
				var clen = i.readUInt16();
				AFunction2({
					name : name,
					args : args,
					flags : flags,
					codeLength : clen,
					nRegisters : nregs,
				});
			case 0x8F:
				var flags = i.readByte();
				var tsize = i.readUInt16();
				var csize = i.readUInt16();
				var fsize = i.readUInt16();
				var tstyle = if( flags & 4 == 0 ) TryVariable(readString()) else TryRegister (i.readByte());
				ATry({
					style : tstyle,
					tryLength : tsize,
					catchLength : if( flags & 1 == 0 ) null else csize,
					finallyLength : if( flags & 2 == 0 ) null else fsize,
				});
			case 0x94:
				var size = i.readUInt16();
				AWith(size);
			case 0x96:
				APush(parsePushItems(i.read(len)));
			case 0x99:
				AJump(i.readInt16());
			case 0x9A:
				AGetURL2(i.readByte());
			case 0x9B:
				var name = readString();
				var args = new Array();
				for( i in 0...i.readUInt16() )
					args.push(readString());
				var clen = i.readUInt16();
				AFunction({
					name : name,
					args : args,
					codeLength : clen,
				});
			case 0x9D:
				ACondJump(i.readInt16());
			case 0x9E:
				ACallFrame;
			case 0x9F:
				var flags = i.readByte();
				var play = flags & 1 != 0;
				var delta = if( flags & 2 == 0 ) null else i.readUInt16();
				AGotoFrame2(play, delta);
			default:
				AUnknown(id, i.read(len));
		}
	}

}