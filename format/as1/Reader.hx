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
package format.as1;
import format.as1.Constants;
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
		return switch( id : ActionCode ) {
			// basic actions
			case ActionEnd:             AEnd;
			case ActionNextFrame:       ANextFrame;
			case ActionPrevFrame:       APrevFrame;
			case ActionPlay:            APlay;
			case ActionStop:            AStop;
			case ActionToggleQuality:   AToggleHighQuality;
			case ActionStopSounds:      AStopSounds;
			case ActionAdd:             AAddNum;
			case ActionSubtract:        ASubtract;
			case ActionMultiply:        AMultiply;
			case ActionDivide:          ADivide;
			case ActionEquals:          AEqualNum;
			case ActionLess:            ACompareNum;
			case ActionAnd:             ALogicalAnd;
			case ActionOr:              ALogicalOr;
			case ActionNot:             ANot;
			case ActionStringEquals:    AStringEqual;
			case ActionStringLength:    AStringLength;
			case ActionStringExtract:   ASubString;
			case ActionPop:             APop;
			case ActionToInteger:       AToInt;
			case ActionGetVariable:     AEval;
			case ActionSetVariable:     ASet;
			case ActionSetTarget2:      ATellTarget;
			case ActionStringAdd:       AStringAdd;
			case ActionGetProperty:     AGetProperty;
			case ActionSetProperty:     ASetProperty;
			case ActionCloneSprite:     ADuplicateMC;
			case ActionRemoveSprite:    ARemoveMC;
			case ActionTrace:           ATrace;
			case ActionStartDrag:       AStartDrag;
			case ActionEndDrag:         AStopDrag;
			case ActionStringLess:      AStringCompare;
			case ActionThrow:           AThrow;
			case ActionCastOp:          ACast;
			case ActionImplementsOp:    AImplements;
			case ActionFSCommand2:      AFSCommand2;
			case ActionRandomNumber:    ARandom;
			case ActionMBStringLength:  AMBStringLength;
			case ActionCharToAscii:     AOrd;
			case ActionAsciiToChar:     AChr;
			case ActionGetTime:         AGetTimer;
			case ActionMBStringExtract: AMBStringSub;
			case ActionMBCharToAscii:   AMBOrd;
			case ActionMBAsciiToChar:   AMBChr;
			case ActionDelete:          ADeleteObj;
			case ActionDelete2:         ADelete;
			case ActionDefineLocal:     ALocalAssign;
			case ActionCallFunction:    ACall;
			case ActionReturn:          AReturn;
			case ActionModulo:          AMod;
			case ActionNewObject:       ANew;
			case ActionDefineLocal2:    ALocalVar;
			case ActionInitArray:       AInitArray;
			case ActionInitObject:      AObject;
			case ActionTypeOf:          ATypeOf;
			case ActionTargetPath:      ATargetPath;
			case ActionEnumerate:       AEnum;
			case ActionAdd2:            AAdd;
			case ActionLess2:           ACompare;
			case ActionEquals2:         AEqual;
			case ActionToNumber:        AToNumber;
			case ActionToString:        AToString;
			case ActionPushDuplicate:   ADup;
			case ActionStackSwap:       ASwap;
			case ActionGetMember:       AObjGet;
			case ActionSetMember:       AObjSet;
			case ActionIncrement:       AIncrement;
			case ActionDecrement:       ADecrement;
			case ActionCallMethod:      AObjCall;
			case ActionNewMethod:       ANewMethod;
			case ActionInstanceOf:      AInstanceOf;
			case ActionEnumerate2:      AEnum2;
			case ActionBitAnd:          AAnd;
			case ActionBitOr:           AOr;
			case ActionBitXor:          AXor;
			case ActionBitLShift:       AShl;
			case ActionBitRShift:       AShr;
			case ActionBitURShift:      AAsr;
			case ActionStrictEquals:    APhysEqual;
			case ActionGreater:         AGreater;
			case ActionStringGreater:   AStringGreater;
			case ActionExtends:         AExtends;
			// extended actions
			case ActionGotoFrame:
				AGotoFrame(i.readUInt16());
			case ActionGetURL:
				var url = readString();
				var target = readString();
				AGetURL(url, target);
			case ActionStoreRegister:
				ASetReg(i.readByte());
			case ActionConstantPool:
				var strings = new Array();
				for( i in 0...i.readUInt16() )
					strings.push(readString());
				AStringPool(strings);
			case ActionWaitForFrame:
				var frame = i.readUInt16();
				var skip = i.readByte();
				AWaitForFrame(frame, skip);
			case ActionSetTarget:
				ASetTarget(readString());
			case ActionGoToLabel:
				AGotoLabel(readString());
			case ActionWaitForFrame2:
				AWaitForFrame2(i.readByte());
			case ActionDefineFunction2:
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
			case ActionTry:
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
			case ActionWith:
				var size = i.readUInt16();
				AWith(size);
			case ActionPush:
				APush(parsePushItems(i.read(len)));
			case ActionJump:
				AJump(i.readInt16());
			case ActionGetURL2:
				AGetURL2(i.readByte());
			case ActionDefineFunction:
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
			case ActionIf:
				ACondJump(i.readInt16());
			case ActionCall:
				ACallFrame;
			case ActionGotoFrame2:
				var flags = i.readByte();
				var play = flags & 1 != 0;
				var delta = if( flags & 2 == 0 ) null else i.readUInt16();
				AGotoFrame2(play, delta);
			case _:			
				return AUnknown(id, i.read(len));
		}
	}

}