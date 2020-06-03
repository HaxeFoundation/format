package format.jvm;

import format.jvm.Data;
import haxe.Int64;
import haxe.io.Encoding;
import haxe.io.Input;

class ConstantPoolReader {
	static function readConstantPoolEntry(i:Input) {
		return switch (i.readByte()) {
			case 1: CONSTANT_Utf8(i.read(i.readUInt16()));
			case 3: CONSTANT_Integer(i.readInt32());
			case 4: CONSTANT_Float(i.readFloat());
			case 5: CONSTANT_Long(Int64.make(i.readInt32(), i.readInt32()));
			case 6: CONSTANT_Double(i.readDouble());
			case 7: CONSTANT_Class(i.readUInt16());
			case 8: CONSTANT_String(i.readUInt16());
			case 9: CONSTANT_Fieldref(i.readUInt16(), i.readUInt16());
			case 10: CONSTANT_Methodref(i.readUInt16(), i.readUInt16());
			case 11: CONSTANT_InterfaceMethodref(i.readUInt16(), i.readUInt16());
			case 12: CONSTANT_NameAndType(i.readUInt16(), i.readUInt16());
			case 15: CONSTANT_MethodHandle(i.readByte(), i.readUInt16());
			case 16: CONSTANT_MethodType(i.readUInt16());
			case 18: CONSTANT_InvokeDynamic(i.readUInt16(), i.readUInt16());
			case i: throw 'Invalid constant pool kind: $i';
		}
	}

	static public function readConstantPool(i:Input) {
		var count = i.readUInt16();
		var constantPool = [];
		var entryNumber = 1;
		while (entryNumber < count) {
			var entry = readConstantPoolEntry(i);
			constantPool[entryNumber] = entry;
			switch (entry) {
				case CONSTANT_Long(_) | CONSTANT_Double(_):
					entryNumber += 2;
				case _:
					++entryNumber;
			}
		}
		return constantPool;
	}
}

class Reader {
	var i:Input;
	var constantPool:ConstantPool;

	public function new(i:Input) {
		this.i = i;
		i.bigEndian = true;
	}

	function readUInt16Array<T>(f:Void->T) {
		return [for (_ in 0...i.readUInt16()) f()];
	}

	// Constant pool

	function readConstantPoolIndex() {
		return i.readUInt16();
	}

	public function expectUtf8(index:Int) {
		return switch (constantPool[index]) {
			case CONSTANT_Utf8(bytes): bytes.getString(0, bytes.length, Encoding.UTF8);
			case _: throw 'Expected CONSTANT_Utf8';
		}
	}

	public function expectClass(index:Int) {
		return switch (constantPool[index]) {
			case CONSTANT_Class(nameIndex): expectUtf8(nameIndex);
			case _: throw 'Expected CONSTANT_Class';
		}
	}

	function expectNameAndType(index:Int) {
		return switch (constantPool[index]) {
			case CONSTANT_NameAndType(nameIndex, descriptorIndex): {
					name: expectUtf8(nameIndex),
					type: expectUtf8(descriptorIndex)
				}
			case _: throw 'Expected CONSTANT_NameAndType';
		}
	}

	function makeConstantField(classIndex:Int, nameAndTypeIndex:Int) {
		var nameAndType = expectNameAndType(nameAndTypeIndex);
		return {
			className: expectClass(classIndex),
			name: nameAndType.name,
			type: nameAndType.type
		}
	}

	public function expectField(index:Int) {
		return switch (constantPool[index]) {
			case CONSTANT_Fieldref(classIndex, nameAndTypeIndex):
				makeConstantField(classIndex, nameAndTypeIndex);
			case _: throw 'Expected CONSTANT_Fieldref';
		}
	}

	public function expectMethod(index:Int) {
		return switch (constantPool[index]) {
			case CONSTANT_Methodref(classIndex, nameAndTypeIndex):
				makeConstantField(classIndex, nameAndTypeIndex);
			case _: throw 'Expected CONSTANT_Methodref';
		}
	}

	public function expectInterfaceMethod(index:Int) {
		return switch (constantPool[index]) {
			case CONSTANT_InterfaceMethodref(classIndex, nameAndTypeIndex):
				makeConstantField(classIndex, nameAndTypeIndex);
			case _: throw 'Expected CONSTANT_InterfaceMethodref';
		}
	}

	// Annotation

	function readElementValue() {
		var tag = i.readByte();
		var value = switch (tag) {
			case 'B'.code | 'C'.code | 'D'.code | 'F'.code | 'I'.code | 'J'.code | 'S'.code | 'Z'.code | 's'.code:
				ConstValue(constantPool[readConstantPoolIndex()]);
			case 'e'.code:
				EnumConstValue(expectUtf8(readConstantPoolIndex()), expectUtf8(readConstantPoolIndex()));
			case 'c'.code:
				ClassInfo(expectUtf8(readConstantPoolIndex()));
			case '@'.code:
				AnnotationValue(readAnnotation());
			case '['.code:
				ArrayValue(readUInt16Array(readElementValue));
			case c:
				throw 'Unrecognized element_value tag: ${String.fromCharCode(c)}';
		}
		return {
			tag: tag,
			value: value
		}
	}

	function readElementValuePairs() {
		return readUInt16Array(() -> {
			elementName: expectUtf8(readConstantPoolIndex()),
			elementValue: readElementValue()
		});
	}

	function readParameterAnnotations() {
		return [
			for (_ in 0...i.readByte())
				readUInt16Array(readAnnotation)
		];
	}

	function readAnnotation() {
		return {
			type: expectUtf8(readConstantPoolIndex()),
			elementValuePairs: readElementValuePairs()
		}
	}

	function readAnnotations() {
		return readUInt16Array(readAnnotation);
	}

	// Attribute

	function readCode():Code {
		function readCode() {
			var count = i.readInt32();
			var r = new InstructionReader(i, this);
			return r.read(count);
		}
		function readExceptionTable() {
			return readUInt16Array(() -> {
				startPc: i.readUInt16(),
				endPc: i.readUInt16(),
				handlerPc: i.readUInt16(),
				catchType: expectClass(readConstantPoolIndex())
			});
		}
		return {
			maxStack: i.readUInt16(),
			maxLocals: i.readUInt16(),
			code: readCode(),
			exceptionTable: readExceptionTable(),
			attributes: readAttributes()
		}
	}

	function readVerificationType() {
		return switch (i.readByte()) {
			case 0: VTop;
			case 1: VInteger;
			case 2: VFloat;
			case 3: VDouble;
			case 4: VLong;
			case 5: VNull;
			case 6: VUninitializedThis;
			case 7: VObject(expectClass(readConstantPoolIndex()));
			case 8: VUninitialized(i.readUInt16());
			case i: throw 'Unrecognized verification type: $i';
		}
	}

	function readStackMapFrame() {
		var frameType = i.readByte();
		var kind = if (frameType < 64) {
			SameFrame;
		} else if (frameType < 128) {
			SameLocals1StackItemFrame(readVerificationType());
		} else if (frameType < 247) {
			throw 'Invalid frameType: $frameType';
		} else if (frameType == 247) {
			SameLocals1StackItemFrameExtended(i.readUInt16(), readVerificationType());
		} else if (frameType < 251) {
			ChopFrame(i.readUInt16());
		} else if (frameType == 251) {
			SameFrameExtended(i.readUInt16());
		} else if (frameType < 255) {
			AppendFrame(i.readUInt16(), [for (_ in 0...frameType - 251) readVerificationType()]);
		} else {
			FullFrame(i.readUInt16(), readUInt16Array(readVerificationType), readUInt16Array(readVerificationType));
		}
		return {
			frameType: frameType,
			kind: kind
		}
	}

	function readExceptions() {
		return readUInt16Array(() -> expectClass(readConstantPoolIndex()));
	}

	function readInnerClasses() {
		return readUInt16Array(() -> {
			innerClassInfo: expectClass(readConstantPoolIndex()),
			outerClassInfo: expectClass(readConstantPoolIndex()),
			innerName: expectUtf8(readConstantPoolIndex()),
			innerClassAccessFlags: new ClassAccessFlags(i.readInt16())
		});
	}

	function readLineNumberTable() {
		return readUInt16Array(() -> {
			startPc: i.readUInt16(),
			lineNumber: i.readUInt16()
		});
	}

	function readLocalVariableTable() {
		return readUInt16Array(() -> {
			startPc: i.readUInt16(),
			length: i.readUInt16(),
			name: expectUtf8(readConstantPoolIndex()),
			descriptor: expectUtf8(readConstantPoolIndex()),
			index: i.readUInt16()
		});
	}

	function readLocalVariableTypeTable() {
		return readUInt16Array(() -> {
			startPc: i.readUInt16(),
			length: i.readUInt16(),
			name: expectUtf8(readConstantPoolIndex()),
			signature: expectUtf8(readConstantPoolIndex()),
			index: i.readUInt16()
		});
	}

	function readBootstrapMethods() {
		return readUInt16Array(() -> {
			bootstrapMethodRef: readConstantPoolIndex(),
			bootstrapArguments: readUInt16Array(() -> constantPool[readConstantPoolIndex()])
		});
	}

	function readAttribute():Attribute {
		var name = expectUtf8(readConstantPoolIndex());
		var length = i.readInt32();
		return switch (name) {
			case "ConstantValue": ConstantValue(constantPool[readConstantPoolIndex()]);
			case "Code": Code(readCode());
			case "StackMapTable": StackMapTable(readUInt16Array(readStackMapFrame));
			case "Exceptions": Exceptions(readExceptions());
			case "InnerClasses": InnerClasses(readInnerClasses());
			case "EnclosingMethod": EnclosingMethod(expectClass(readConstantPoolIndex()), expectNameAndType(readConstantPoolIndex()));
			case "Synthetic": Synthetic;
			case "Signature": Signature(expectUtf8(readConstantPoolIndex()));
			case "SourceFile": SourceFile(expectUtf8(readConstantPoolIndex()));
			case "SourceDebugExtension": SourceDebugExtension(i.read(length));
			case "LineNumberTable": LineNumberTable(readLineNumberTable());
			case "LocalVariableTable": LocalVariableTable(readLocalVariableTable());
			case "LocalVariableTypeTable": LocalVariableTypeTable(readLocalVariableTypeTable());
			case "Deprecated": Deprecated;
			case "RuntimeVisibleAnnotations": RuntimeVisibleAnnotations(readAnnotations());
			case "RuntimeInvisibleAnnotations": RuntimeInvisibleAnnotations(readAnnotations());
			case "RuntimeVisibleParameterAnnotations": RuntimeVisibleParameterAnnotations(readParameterAnnotations());
			case "RuntimeInvisibleParameterAnnotations": RuntimeInvisibleParameterAnnotations(readParameterAnnotations());
			case "AnnotationDefault": AnnotationDefault(readElementValue());
			case "BootstrapMethods": BootstrapMethods(readBootstrapMethods());
			case s: throw 'Unrecognized attribute name: $s';
		}
	}

	function readAttributes() {
		return readUInt16Array(readAttribute);
	}

	// Field

	function readField() {
		return {
			accessFlags: new FieldAccessFlags(i.readUInt16()),
			name: expectUtf8(readConstantPoolIndex()),
			descriptor: expectUtf8(readConstantPoolIndex()),
			attributes: readAttributes()
		}
	}

	function readMethod() {
		return {
			accessFlags: new MethodAccessFlags(i.readUInt16()),
			name: expectUtf8(readConstantPoolIndex()),
			descriptor: expectUtf8(readConstantPoolIndex()),
			attributes: readAttributes()
		}
	}

	// Class

	function readInterfaces() {
		return readUInt16Array(() -> expectClass(readConstantPoolIndex()));
	}

	function readFields() {
		return readUInt16Array(readField);
	}

	function readMethods() {
		return readUInt16Array(readMethod);
	}

	public function read():JClass {
		if (i.readInt32() != 0xCAFEBABE) {
			throw "Invalid header";
		}
		var minor = i.readUInt16();
		var major = i.readUInt16();
		constantPool = ConstantPoolReader.readConstantPool(i);
		return {
			minorVersion: minor,
			majorVersion: major,
			accessFlags: new ClassAccessFlags(i.readUInt16()),
			thisClass: expectClass(readConstantPoolIndex()),
			superClass: expectClass(readConstantPoolIndex()),
			interfaces: readInterfaces(),
			fields: readFields(),
			methods: readMethods(),
			attributes: readAttributes()
		};
	}
}
