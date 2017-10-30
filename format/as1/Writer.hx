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
import format.as1.Constants;
import format.as1.Data;

class Writer {

	var o : haxe.io.Output;
	var old : haxe.io.Output;
	var tmp : haxe.io.BytesOutput;
	
	public function new( o ) {
		this.o = o;
	}

	public function write( actions : AS1 ) {
		for( action in actions )
		{
			writeAction( action );
		}
		o.writeByte( 0 );
	}
	
	function openTmp() {
		old = o;
		tmp = new haxe.io.BytesOutput();
		o = tmp;
	}

	inline function closeTmp() : haxe.io.Bytes {
		var bytes = tmp.getBytes();
		o = old;
		return bytes;
	}
	
	function closeAndWriteTmp() {
		var bytes = closeTmp();
		o.writeUInt16( bytes.length );
		o.write( bytes );
	}

	inline function writeString( s : String ) {
		o.writeString( s );
		o.writeByte( 0 );
	}
	
	function writeDouble( f : Float ) {
		var tmp = new haxe.io.BytesOutput();
		tmp.writeDouble( f );
		var bytes = tmp.getBytes();
		o.writeByte( bytes.get( 4 ) );
		o.writeByte( bytes.get( 5 ) );
		o.writeByte( bytes.get( 6 ) );
		o.writeByte( bytes.get( 7 ) );
		o.writeByte( bytes.get( 0 ) );
		o.writeByte( bytes.get( 1 ) );
		o.writeByte( bytes.get( 2 ) );
		o.writeByte( bytes.get( 3 ) );
	}

	function writePushItems( items : Array<PushItem> ) {
		for( item in items ) {
			switch( item ) {
				case PString( s ):
					o.writeByte( 0 );
					writeString( s );
					
				case PFloat( f ):
					o.writeByte( 1 );
					o.writeFloat( f );
					
				case PNull:
					o.writeByte( 2 );
					
				case PUndefined:
					o.writeByte( 3 );
					
				case PReg( r ):
					o.writeByte( 4 );
					o.writeByte( r );
					
				case PBool( b ):
					o.writeByte( 5 );
					o.writeByte( b ? 1 : 0 );
				
				case PDouble( f ):
					o.writeByte( 6 );
					writeDouble( f ); // TODO
					
				case PInt( i ):
					o.writeByte( 7 );
					o.writeInt32( i );
					
				case PStack( p ):
					o.writeByte( 8 );
					o.writeByte( p );
					
				case PStack2( p ):
					o.writeByte( 9 );
					o.writeUInt16( p );
			}
		}
	}

	inline function writeActionCode( actionCode : ActionCode ) {
		o.writeByte( actionCode );
	}
	
	function writeAction( action : Action ) {
		switch( action ) {
			// basic actions
			case AEnd:               writeActionCode( ActionEnd );
			case ANextFrame:         writeActionCode( ActionNextFrame );
			case APrevFrame:         writeActionCode( ActionPrevFrame );
			case APlay:              writeActionCode( ActionPlay );
			case AStop:              writeActionCode( ActionStop );
			case AToggleHighQuality: writeActionCode( ActionToggleQuality );
			case AStopSounds:        writeActionCode( ActionStopSounds );
			case AAddNum:            writeActionCode( ActionAdd );
			case ASubtract:          writeActionCode( ActionSubtract );
			case AMultiply:          writeActionCode( ActionMultiply );
			case ADivide:            writeActionCode( ActionDivide );
			case AEqualNum:          writeActionCode( ActionEquals );
			case ACompareNum:        writeActionCode( ActionLess );
			case ALogicalAnd:        writeActionCode( ActionAnd );
			case ALogicalOr:         writeActionCode( ActionOr );
			case ANot:               writeActionCode( ActionNot );
			case AStringEqual:       writeActionCode( ActionStringEquals );
			case AStringLength:      writeActionCode( ActionStringLength );
			case ASubString:         writeActionCode( ActionStringExtract );
			case APop:               writeActionCode( ActionPop );
			case AToInt:             writeActionCode( ActionToInteger );
			case AEval:              writeActionCode( ActionGetVariable );
			case ASet:               writeActionCode( ActionSetVariable );
			case ATellTarget:        writeActionCode( ActionSetTarget2 );
			case AStringAdd:         writeActionCode( ActionStringAdd );
			case AGetProperty:       writeActionCode( ActionGetProperty );
			case ASetProperty:       writeActionCode( ActionSetProperty );
			case ADuplicateMC:       writeActionCode( ActionCloneSprite );
			case ARemoveMC:          writeActionCode( ActionRemoveSprite );
			case ATrace:             writeActionCode( ActionTrace );
			case AStartDrag:         writeActionCode( ActionStartDrag );
			case AStopDrag:          writeActionCode( ActionEndDrag );
			case AStringCompare:     writeActionCode( ActionStringLess );
			case AThrow:             writeActionCode( ActionThrow );
			case ACast:              writeActionCode( ActionCastOp );
			case AImplements:        writeActionCode( ActionImplementsOp );
			case AFSCommand2:        writeActionCode( ActionFSCommand2 );
			case ARandom:            writeActionCode( ActionRandomNumber );
			case AMBStringLength:    writeActionCode( ActionMBStringLength );
			case AOrd:               writeActionCode( ActionCharToAscii );
			case AChr:               writeActionCode( ActionAsciiToChar );
			case AGetTimer:          writeActionCode( ActionGetTime );
			case AMBStringSub:       writeActionCode( ActionMBStringExtract );
			case AMBOrd:             writeActionCode( ActionMBCharToAscii );
			case AMBChr:             writeActionCode( ActionMBAsciiToChar );
			case ADeleteObj:         writeActionCode( ActionDelete );
			case ADelete:            writeActionCode( ActionDelete2 );
			case ALocalAssign:       writeActionCode( ActionDefineLocal );
			case ACall:              writeActionCode( ActionCallFunction );
			case AReturn:            writeActionCode( ActionReturn );
			case AMod:               writeActionCode( ActionModulo );
			case ANew:               writeActionCode( ActionNewObject );
			case ALocalVar:          writeActionCode( ActionDefineLocal2 );
			case AInitArray:         writeActionCode( ActionInitArray );
			case AObject:            writeActionCode( ActionInitObject );
			case ATypeOf:            writeActionCode( ActionTypeOf );
			case ATargetPath:        writeActionCode( ActionTargetPath );
			case AEnum:              writeActionCode( ActionEnumerate );
			case AAdd:               writeActionCode( ActionAdd2 );
			case ACompare:           writeActionCode( ActionLess2 );
			case AEqual:             writeActionCode( ActionEquals2 );
			case AToNumber:          writeActionCode( ActionToNumber );
			case AToString:          writeActionCode( ActionToString );
			case ADup:               writeActionCode( ActionPushDuplicate );
			case ASwap:              writeActionCode( ActionStackSwap );
			case AObjGet:            writeActionCode( ActionGetMember );
			case AObjSet:            writeActionCode( ActionSetMember );
			case AIncrement:         writeActionCode( ActionIncrement );
			case ADecrement:         writeActionCode( ActionDecrement );
			case AObjCall:           writeActionCode( ActionCallMethod );
			case ANewMethod:         writeActionCode( ActionNewMethod );
			case AInstanceOf:        writeActionCode( ActionInstanceOf );
			case AEnum2:             writeActionCode( ActionEnumerate2 );
			case AAnd:               writeActionCode( ActionBitAnd );
			case AOr:                writeActionCode( ActionBitOr );
			case AXor:               writeActionCode( ActionBitXor );
			case AShl:               writeActionCode( ActionBitLShift );
			case AShr:               writeActionCode( ActionBitRShift );
			case AAsr:               writeActionCode( ActionBitURShift );
			case APhysEqual:         writeActionCode( ActionStrictEquals );
			case AGreater:           writeActionCode( ActionGreater );
			case AStringGreater:     writeActionCode( ActionStringGreater );
			case AExtends:           writeActionCode( ActionExtends );
			
			// extended actions
			case AGotoFrame( f ):
				writeActionCode( ActionGotoFrame );
				o.writeUInt16( 2 );
				o.writeUInt16( f );
				
			case AGetURL( url, target ):
				writeActionCode( ActionGetURL );
				openTmp();
				writeString( url );
				writeString( target );
				closeAndWriteTmp();
				
			case ASetReg( reg ):
				writeActionCode( ActionStoreRegister );
				o.writeUInt16( 1 );
				o.writeByte( reg );
				
			case AStringPool( strings ):
				writeActionCode( ActionConstantPool );
				openTmp();
				o.writeUInt16( strings.length );
				for( string in strings )
					writeString( string );
				closeAndWriteTmp();
					
			case AWaitForFrame( frame, skip ):
				writeActionCode( ActionWaitForFrame );
				o.writeUInt16( 3 );
				o.writeUInt16( frame );
				o.writeByte( skip );
				
			case ASetTarget( target ):
				writeActionCode( ActionSetTarget );
				openTmp();
				writeString( target );
				closeAndWriteTmp();
				
			case AGotoLabel( frame ):
				writeActionCode( ActionGoToLabel );
				openTmp();
				writeString( frame );
				closeAndWriteTmp();
				
			case AWaitForFrame2( frame ):
				writeActionCode( ActionWaitForFrame2 );
				o.writeUInt16( 1 );
				o.writeByte( frame );
				
			case AFunction2( infos ):
				writeActionCode( ActionDefineFunction2 );
				openTmp();
				writeString( infos.name );
				o.writeUInt16( infos.args.length );
				o.writeByte( infos.nRegisters );
				o.writeUInt16( infos.flags );
				for( arg in infos.args ) {
					o.writeByte( arg.reg );
					writeString( arg.name );
				}
				o.writeUInt16( infos.codeLength );
				closeAndWriteTmp();
				
			case ATry( infos ):
				writeActionCode( ActionTry );
				var flags = 0;
				openTmp();
				o.writeUInt16( infos.tryLength );				
				if( infos.catchLength != null ) {
					flags |= 1;
					o.writeUInt16( infos.catchLength );
				} else {
					o.writeUInt16( 0 );
				}

				if( infos.finallyLength != null ) {
					flags |= 2;
					o.writeUInt16( infos.finallyLength );
				} else {
					o.writeUInt16( 0 );
				}
				
				switch( infos.style ) {
					case TryVariable( s ):
						writeString( s );

					case TryRegister( r ):
						flags |= 4;
						o.writeByte( r );
				}
				var bytes = closeTmp();
				o.writeUInt16( bytes.length + 1);
				o.writeByte( flags );
				o.write( bytes );
				
			case AWith( value ):
				writeActionCode( ActionWith );
				o.writeUInt16( 2 );
				o.writeUInt16( value );
				
			case APush( items ):
				writeActionCode( ActionPush );
				openTmp();
				writePushItems( items );
				closeAndWriteTmp();
				
			case AJump( delta ):
				writeActionCode( ActionJump );
				o.writeUInt16( 2 );
				o.writeInt16( delta ); 
				
			case AGetURL2( v ):
				writeActionCode( ActionGetURL2 );
				o.writeUInt16( 1 );
				o.writeByte( v );
				
			case AFunction( infos ):
				writeActionCode( ActionDefineFunction );
				openTmp();
				writeString( infos.name );
				o.writeUInt16( infos.args.length );
				for( arg in infos.args ) {
					writeString( arg );
				}
				o.writeUInt16( infos.codeLength );
				closeAndWriteTmp();
				
			case ACondJump( delta ):
				writeActionCode( ActionIf );
				o.writeUInt16( 2 );
				o.writeInt16( delta );

			case ACallFrame:
				writeActionCode( ActionCall );
				o.writeUInt16( 0 );

			case AGotoFrame2( play, delta ):
				writeActionCode( ActionGotoFrame2 );
				var flags = play ? 1 : 0;
				if( delta != null ) {
					o.writeUInt16( 3 );
					o.writeByte( flags | 2 );
					o.writeUInt16( delta );
				}
				else {
					o.writeUInt16( 1 );
					o.writeByte( flags );
				}
				
			case AUnknown( id, data ):
				o.writeByte( id );
				if( id >= 0x80 ) {
					o.writeUInt16( data.length );
					o.write( data );
				}
		}
	}

}