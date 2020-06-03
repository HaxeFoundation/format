package format.jvm;

import format.jvm.Data;
import haxe.ds.Vector;
import haxe.io.Encoding;
import haxe.io.Input;

@:access(format.jvm.Reader)
class InstructionReader {
	final i:Input;
	final reader:Reader;

	public function new(i:Input, reader:Reader) {
		this.i = i;
		this.reader = reader;
	}

	public function read(count:Int) {
		var ops = [];
		var bytesRead = 0;
		function readByte() {
			++bytesRead;
			return i.readByte();
		}
		function readInt16() {
			bytesRead += 2;
			return i.readInt16();
		}
		function readUInt16() {
			bytesRead += 2;
			return i.readUInt16();
		}
		function readInt32() {
			bytesRead += 4;
			return i.readInt32();
		}
		function readConstantPoolRef() {
			bytesRead += 2;
			return i.readUInt16();
		}
		function skipPadding() {
			var pad = (3 - (bytesRead - 1) % 4);
			if (pad > 0) {
				i.read(pad);
			}
			bytesRead += pad;
		}
		var i = 0; // shadow i so we don't accidentally use it
		while (bytesRead < count) {
			var op = switch (readByte()) {
				case 0x32: Aaload;
				case 0x53: Aastore;
				case 0x01: Aconst_null;
				case 0x19: Aload(readByte());
				case 0x2A: Aload_0;
				case 0x2B: Aload_1;
				case 0x2C: Aload_2;
				case 0x2D: Aload_3;
				case 0xBD: Anewarray(reader.expectClass(readConstantPoolRef()));
				case 0xB0:
					AReturn;
				case 0xBE:
					Arraylength;
				case 0x3A:
					Astore(readByte());
				case 0x4B:
					Astore_0;
				case 0x4C:
					Astore_1;
				case 0x4D:
					Astore_2;
				case 0x4E:
					Astore_3;
				case 0xBF:
					Athrow;
				case 0x33:
					Baload;
				case 0x54:
					Bastore;
				case 0x10:
					Bipush(readByte());
				case 0x34:
					Caload;
				case 0x55:
					Castore;
				case 0xC0:
					Checkcast(reader.expectClass(readConstantPoolRef()));
				case 0x90:
					D2f;
				case 0x8E:
					D2i;
				case 0x8F:
					D2l;
				case 0x63:
					Dadd;
				case 0x31:
					Daload;
				case 0x52:
					Dastore;
				case 0x98:
					Dcmpg;
				case 0x97:
					Dcmpl;
				case 0x0E:
					Dconst_0;
				case 0x0F:
					Dconst_1;
				case 0x6F:
					Ddiv;
				case 0x18:
					Dload(readByte());
				case 0x26:
					Dload_0;
				case 0x27:
					Dload_1;
				case 0x28:
					Dload_2;
				case 0x29:
					Dload_3;
				case 0x6B:
					Dmul;
				case 0x77:
					Dneg;
				case 0x73:
					Drem;
				case 0xAF:
					Dreturn;
				case 0x39:
					Dstore(readByte());
				case 0x47:
					Dstore_0;
				case 0x48:
					Dstore_1;
				case 0x49:
					Dstore_2;
				case 0x4A:
					Dstore_3;
				case 0x67:
					Dsub;
				case 0x59:
					Dup;
				case 0x5A:
					Dup_x1;
				case 0x5B:
					Dup_x2;
				case 0x5C:
					Dup2;
				case 0x5D:
					Dup2_x1;
				case 0x5E:
					Dup2_x2;
				case 0x8D:
					F2d;
				case 0x8B:
					F2i;
				case 0x8C:
					F2l;
				case 0x62:
					Fadd;
				case 0x30:
					Faload;
				case 0x51:
					Fastore;
				case 0x96:
					Fcmpg;
				case 0x95:
					Fcmpl;
				case 0x0B:
					Fconst_0;
				case 0x0C:
					Fconst_1;
				case 0x0D:
					Fconst_2;
				case 0x6E:
					FDiv;
				case 0x17:
					FLoad(readByte());
				case 0x22:
					Fload_0;
				case 0x23:
					Fload_1;
				case 0x24:
					Fload_2;
				case 0x25:
					Fload_3;
				case 0x6A:
					FMul;
				case 0x76:
					FNeg;
				case 0x72:
					Frem;
				case 0xAE:
					FReturn;
				case 0x38:
					Fstore(readByte());
				case 0x43:
					Fstore_0;
				case 0x44:
					Fstore_1;
				case 0x45:
					Fstore_2;
				case 0x46:
					Fstore_3;
				case 0x66:
					Fsub;
				case 0xB4:
					Getfield(reader.expectField(readConstantPoolRef()));
				case 0xB2:
					Getstatic(reader.expectField(readConstantPoolRef()));
				case 0xA7:
					Goto(readInt16());
				case 0xC8:
					Goto_w(readInt32());
				case 0x91:
					I2b;
				case 0x92:
					I2c;
				case 0x87:
					I2d;
				case 0x86:
					I2f;
				case 0x85:
					I2l;
				case 0x93:
					I2s;
				case 0x60:
					Iadd;
				case 0x2E:
					Iaload;
				case 0x7E:
					Iand;
				case 0x4F:
					IAstore;
				case 0x02:
					Iconst_m1;
				case 0x03:
					Iconst_0;
				case 0x04:
					Iconst_1;
				case 0x05:
					Iconst_2;
				case 0x06:
					Iconst_3;
				case 0x07:
					Iconst_4;
				case 0x08:
					Iconst_5;
				case 0x6C:
					Idiv;
				case 0xA5:
					If_acmpeq(readInt16());
				case 0xA6:
					If_acmpne(readInt16());
				case 0x9F:
					If_icmpeq(readInt16());
				case 0xA0:
					If_icmpne(readInt16());
				case 0xA1:
					If_icmplt(readInt16());
				case 0xA2:
					If_icmpge(readInt16());
				case 0xA3:
					If_icmpgt(readInt16());
				case 0xA4:
					If_icmple(readInt16());
				case 0x99:
					If_eq(readInt16());
				case 0x9A:
					If_ne(readInt16());
				case 0x9B:
					If_lt(readInt16());
				case 0x9C:
					If_ge(readInt16());
				case 0x9D:
					If_gt(readInt16());
				case 0x9E:
					If_le(readInt16());
				case 0xC7:
					Ifnonnull(readInt16());
				case 0xC6:
					Ifnull(readInt16());
				case 0x84:
					Iinc(readByte(), readByte());
				case 0x15:
					Iload(readByte());
				case 0x1A:
					Iload_0;
				case 0x1B:
					Iload_1;
				case 0x1C:
					Iload_2;
				case 0x1D:
					Iload_3;
				case 0x68:
					Imul;
				case 0x74:
					Ineg;
				case 0xC1:
					Instanceof(reader.expectClass(readConstantPoolRef()));
				case 0xBA:
					Invokedynamic(reader.expectMethod(readConstantPoolRef()));
				case 0xB9:
					Invokeinterface(reader.expectInterfaceMethod(readConstantPoolRef()), readByte());
				case 0xB7:
					Invokespecial(reader.expectMethod(readConstantPoolRef()));
				case 0xB8:
					Invokestatic(reader.expectMethod(readConstantPoolRef()));
				case 0xB6:
					Invokevirtual(reader.expectMethod(readConstantPoolRef()));
				case 0x80:
					Ior;
				case 0x70:
					Irem;
				case 0xAC:
					Ireturn;
				case 0x78:
					Ishl;
				case 0x7A:
					Ishr;
				case 0x36:
					Istore(readByte());
				case 0x3B:
					Istore_0;
				case 0x3C:
					Istore_1;
				case 0x3D:
					Istore_2;
				case 0x3E:
					Istore_3;
				case 0x64:
					Isub;
				case 0x7C:
					Iushr;
				case 0x82:
					Ixor;
				case 0xA8:
					Jsr(readInt16());
				case 0xC9:
					Jsr_w(readInt32());
				case 0x8A:
					L2d;
				case 0x89:
					L2f;
				case 0x88:
					L2i;
				case 0x61:
					Ladd;
				case 0x2F:
					Laload;
				case 0x7F:
					Land;
				case 0x50:
					Lastore;
				case 0x94:
					Lcmp;
				case 0x09:
					Lconst_0;
				case 0x0A:
					Lconst_1;
				case 0x12:
					Ldc(readByte());
				case 0x13:
					Ldc_w(reader.constantPool[readConstantPoolRef()]);
				case 0x14:
					Ldc2_w(reader.constantPool[readConstantPoolRef()]);
				case 0x6D:
					Ldiv;
				case 0x16:
					Lload(readByte());
				case 0x1E:
					Lload_0;
				case 0x1F:
					Lload_1;
				case 0x20:
					Lload_2;
				case 0x21:
					Lload_3;
				case 0x69:
					Lmul;
				case 0x75:
					Lneg;
				case 0xAB:
					skipPadding();
					var defaultOffset = readInt32();
					var count = readInt32();
					var vec = new Vector(count);
					for (index in 0...count) {
						vec[index] = {match: readInt32(), offset: readInt32()};
					}
					Lookupswitch(defaultOffset, vec);
				case 0x81:
					Lor;
				case 0x71:
					Lrem;
				case 0xAD:
					Lreturn;
				case 0x79:
					Lshl;
				case 0x7B:
					Lshr;
				case 0x37:
					Lstore(readByte());
				case 0x3F:
					Lstore_0;
				case 0x40:
					Lstore_1;
				case 0x41:
					Lstore_2;
				case 0x42:
					Lstore_3;
				case 0x65:
					Lsub;
				case 0x7D:
					Lushr;
				case 0x83:
					Lxor;
				case 0xC2:
					Monitorenter;
				case 0xC3:
					Monitorexit;
				case 0xC5:
					Multianewarray(reader.expectClass(readConstantPoolRef()), readByte());
				case 0xBB:
					New(reader.expectClass(readConstantPoolRef()));
				case 0xBC:
					NewArray(readByte());
				case 0x00:
					Nop;
				case 0x57:
					Pop;
				case 0x58:
					Pop2;
				case 0xB5:
					Putfield(reader.expectField(readConstantPoolRef()));
				case 0xB3:
					Putstatic(reader.expectField(readConstantPoolRef()));
				case 0xA9:
					Ret(readByte());
				case 0xB1:
					Return;
				case 0x35:
					Saload;
				case 0x56:
					Sastore;
				case 0x11:
					Sipush(readInt16());
				case 0x5F:
					Swap;
				case 0xAA:
					skipPadding();
					var defaultOffset = readInt32();
					var low = readInt32();
					var high = readInt32();
					var diff = high - low + 1;
					var offsets = new Vector(diff);
					for (index in 0...diff) {
						offsets[index] = readInt32();
					}
					Tableswitch(defaultOffset, low, high, offsets);
				case 0xC4:
					switch (readByte()) {
						case 0x84: WideIinc(readUInt16(), readInt16());
						case c: Wide(c, readUInt16());
					}
				case code:
					throw 'Unrecozniged instruction: $code';
			}
			ops.push(op);
		}
		return Vector.fromArrayCopy(ops);
	}
}
