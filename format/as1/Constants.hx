/*
 * format - haXe File Formats
 *
 *  SWF File Format
 *  Copyright (C) 2004-2008 Nicolas Cannasse
 *
 * Copyright (c) 2008, The haXe Project Contributors
 * Actionll rights reserved.
 * Redistribution Actionnd use in source Actionnd binary forms, with or without
 * modification, Actionre permitted provided that the following conditions Actionre met:
 *
 *   - Redistributions of source code must retain the Actionbove copyright
 *     notice, this list of conditions Actionnd the following disclaimer.
 *   - Redistributions in binary form must reproduce the Actionbove copyright
 *     notice, this list of conditions Actionnd the following disclaimer in the
 *     documentation Actionnd/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE HAXE PROJECT CONTRIBUTORS "AS IS" ActionND ActionNY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY ActionND FITNESS FOR Action PARTICULAR PURPOSE ActionRE
 * DISCLAIMED. IN NO EVENT SHALL THE HAXE PROJECT CONTRIBUTORS BE LIABLE FOR
 * ActionNY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 * CAUSED ActionND ON ActionNY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ActionRISING IN ActionNY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ActionDVISED OF THE POSSIBILITY OF SUCH
 * DAMAGE.
 */
package format.as1;

/**
 * Action code constants.
 * Not for public usage.
 */
@:enum
abstract ActionCode(Int) from Int to Int {
	var ActionEnd             = 0x00;
	var ActionNextFrame       = 0x04;
	var ActionPrevFrame       = 0x05;
	var ActionPlay            = 0x06;
	var ActionStop            = 0x07;
	var ActionToggleQuality   = 0x08;
	var ActionStopSounds      = 0x09;
	var ActionAdd             = 0x0A;
	var ActionSubtract        = 0x0B;
	var ActionMultiply        = 0x0C;
	var ActionDivide          = 0x0D;
	var ActionEquals          = 0x0E;
	var ActionLess            = 0x0F;
	var ActionAnd             = 0x10;
	var ActionOr              = 0x11;
	var ActionNot             = 0x12;
	var ActionStringEquals    = 0x13;
	var ActionStringLength    = 0x14;
	var ActionStringExtract   = 0x15;
	var ActionPop             = 0x17;
	var ActionToInteger       = 0x18;
	var ActionGetVariable     = 0x1C;
	var ActionSetVariable     = 0x1D;
	var ActionSetTarget2      = 0x20;
	var ActionStringAdd       = 0x21;
	var ActionGetProperty     = 0x22;
	var ActionSetProperty     = 0x23;
	var ActionCloneSprite     = 0x24;
	var ActionRemoveSprite    = 0x25;
	var ActionTrace           = 0x26;
	var ActionStartDrag       = 0x27;
	var ActionEndDrag         = 0x28;
	var ActionStringLess      = 0x29;
	var ActionThrow           = 0x2A;
	var ActionCastOp          = 0x2B;
	var ActionImplementsOp    = 0x2C;
	var ActionFSCommand2      = 0x2D;
	var ActionRandomNumber    = 0x30;
	var ActionMBStringLength  = 0x31;
	var ActionCharToAscii     = 0x32;
	var ActionAsciiToChar     = 0x33;
	var ActionGetTime         = 0x34;
	var ActionMBStringExtract = 0x35;
	var ActionMBCharToAscii   = 0x36;
	var ActionMBAsciiToChar   = 0x37;
	var ActionDelete          = 0x3A;
	var ActionDelete2         = 0x3B;
	var ActionDefineLocal     = 0x3C;
	var ActionCallFunction    = 0x3D;
	var ActionReturn          = 0x3E;
	var ActionModulo          = 0x3F;
	var ActionNewObject       = 0x40;
	var ActionDefineLocal2    = 0x41;
	var ActionInitArray       = 0x42;
	var ActionInitObject      = 0x43;
	var ActionTypeOf          = 0x44;
	var ActionTargetPath      = 0x45;
	var ActionEnumerate       = 0x46;
	var ActionAdd2            = 0x47;
	var ActionLess2           = 0x48;
	var ActionEquals2         = 0x49;
	var ActionToNumber        = 0x4A;
	var ActionToString        = 0x4B;
	var ActionPushDuplicate   = 0x4C;
	var ActionStackSwap       = 0x4D;
	var ActionGetMember       = 0x4E;
	var ActionSetMember       = 0x4F;
	var ActionIncrement       = 0x50;
	var ActionDecrement       = 0x51;
	var ActionCallMethod      = 0x52;
	var ActionNewMethod       = 0x53;
	var ActionInstanceOf      = 0x54;
	var ActionEnumerate2      = 0x55;
	var ActionBitAnd          = 0x60;
	var ActionBitOr           = 0x61;
	var ActionBitXor          = 0x62;
	var ActionBitLShift       = 0x63;
	var ActionBitRShift       = 0x64;
	var ActionBitURShift      = 0x65;
	var ActionStrictEquals    = 0x66;
	var ActionGreater         = 0x67;
	var ActionStringGreater   = 0x68;
	var ActionExtends         = 0x69;
	var ActionGotoFrame       = 0x81;
	var ActionGetURL          = 0x83;
	var ActionStoreRegister   = 0x87;
	var ActionConstantPool    = 0x88;
	var ActionWaitForFrame    = 0x8A;
	var ActionSetTarget       = 0x8B;
	var ActionGoToLabel       = 0x8C;
	var ActionWaitForFrame2   = 0x8D;
	var ActionDefineFunction2 = 0x8E;
	var ActionTry             = 0x8F;
	var ActionWith            = 0x94;
	var ActionPush            = 0x96;
	var ActionJump            = 0x99;
	var ActionGetURL2         = 0x9A;
	var ActionDefineFunction  = 0x9B;
	var ActionIf              = 0x9D;
	var ActionCall            = 0x9E;
	var ActionGotoFrame2      = 0x9F;
}