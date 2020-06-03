package format.jvm;

import haxe.Int64;
import haxe.ds.Vector;
import haxe.io.Bytes;

// Constant pool

enum ConstantPoolEntry {
	CONSTANT_Class(name:Int);
	CONSTANT_Fieldref(classIndex:Int, nameAndTypeIndex:Int);
	CONSTANT_Methodref(classIndex:Int, nameAndTypeIndex:Int);
	CONSTANT_InterfaceMethodref(classIndex:Int, nameAndTypeIndex:Int);
	CONSTANT_String(stringIndex:Int);
	CONSTANT_Integer(i32:Int);
	CONSTANT_Float(f32:Float);
	CONSTANT_Long(i64:Int64);
	CONSTANT_Double(f64:Float);
	CONSTANT_NameAndType(nameIndex:Int, descriptorIndex:Int);
	CONSTANT_Utf8(bytes:Bytes);
	CONSTANT_MethodHandle(referenceKind:Int, reference:Int);
	CONSTANT_MethodType(descriptorIndex:Int);
	CONSTANT_InvokeDynamic(bootstrapMethodAttrIndex:Int, nameAndTypeIndex:Int);
}

typedef ConstantPool = Array<ConstantPoolEntry>;

// Resolved constants

typedef ConstantClass = String;

typedef ConstantNameAndType = {
	var name:String;
	var type:String;
}

typedef ConstantField = {
	var className:String;
} &
	ConstantNameAndType;

// Instruction

enum abstract ArrayTypeCode(Int) from Int {
	var T_BOOLEAN = 4;
	var T_CHAR = 5;
	var T_FLOAT = 6;
	var T_DOUBLE = 7;
	var T_BYTE = 8;
	var T_SHORT = 9;
	var T_INT = 10;
	var T_LONG = 11;
}

enum Instruction {
	Aaload;
	Aastore;
	Aconst_null;
	Aload(index:Int);
	Aload_0;
	Aload_1;
	Aload_2;
	Aload_3;
	Anewarray(type:ConstantClass);
	AReturn;
	Arraylength;
	Astore(index:Int);
	Astore_0;
	Astore_1;
	Astore_2;
	Astore_3;
	Athrow;
	Baload;
	Bastore;
	Bipush(byte:Int);
	Caload;
	Castore;
	Checkcast(type:ConstantClass);
	D2f;
	D2i;
	D2l;
	Dadd;
	Daload;
	Dastore;
	Dcmpg;
	Dcmpl;
	Dconst_0;
	Dconst_1;
	Ddiv;
	Dload(index:Int);
	Dload_0;
	Dload_1;
	Dload_2;
	Dload_3;
	Dmul;
	Dneg;
	Drem;
	Dreturn;
	Dstore(index:Int);
	Dstore_0;
	Dstore_1;
	Dstore_2;
	Dstore_3;
	Dsub;
	Dup;
	Dup_x1;
	Dup_x2;
	Dup2;
	Dup2_x1;
	Dup2_x2;
	F2d;
	F2i;
	F2l;
	Fadd;
	Faload;
	Fastore;
	Fcmpg;
	Fcmpl;
	Fconst_0;
	Fconst_1;
	Fconst_2;
	FDiv;
	FLoad(index:Int);
	Fload_0;
	Fload_1;
	Fload_2;
	Fload_3;
	FMul;
	FNeg;
	Frem;
	FReturn;
	Fstore(index:Int);
	Fstore_0;
	Fstore_1;
	Fstore_2;
	Fstore_3;
	Fsub;
	Getfield(field:ConstantField);
	Getstatic(field:ConstantField);
	Goto(branch:Int);
	Goto_w(branch:Int);
	I2b;
	I2c;
	I2d;
	I2f;
	I2l;
	I2s;
	Iadd;
	Iaload;
	Iand;
	IAstore;
	Iconst_m1;
	Iconst_0;
	Iconst_1;
	Iconst_2;
	Iconst_3;
	Iconst_4;
	Iconst_5;
	Idiv;
	If_acmpeq(branch:Int);
	If_acmpne(branch:Int);
	If_icmpeq(branch:Int);
	If_icmpne(branch:Int);
	If_icmplt(branch:Int);
	If_icmpge(branch:Int);
	If_icmpgt(branch:Int);
	If_icmple(branch:Int);
	If_eq(branch:Int);
	If_ne(branch:Int);
	If_lt(branch:Int);
	If_ge(branch:Int);
	If_gt(branch:Int);
	If_le(branch:Int);
	Ifnonnull(branch:Int);
	Ifnull(branch:Int);
	Iinc(index:Int, const:Int);
	Iload(index:Int);
	Iload_0;
	Iload_1;
	Iload_2;
	Iload_3;
	Imul;
	Ineg;
	Instanceof(type:ConstantClass);
	Invokedynamic(field:ConstantField);
	Invokeinterface(field:ConstantField, count:Int);
	Invokespecial(field:ConstantField);
	Invokestatic(field:ConstantField);
	Invokevirtual(field:ConstantField);
	Ior;
	Irem;
	Ireturn;
	Ishl;
	Ishr;
	Istore(index:Int);
	Istore_0;
	Istore_1;
	Istore_2;
	Istore_3;
	Isub;
	Iushr;
	Ixor;
	Jsr(branch:Int);
	Jsr_w(branch:Int);
	L2d;
	L2f;
	L2i;
	Ladd;
	Laload;
	Land;
	Lastore;
	Lcmp;
	Lconst_0;
	Lconst_1;
	Ldc(index:Int);
	Ldc_w(entry:ConstantPoolEntry);
	Ldc2_w(entry:ConstantPoolEntry);
	Ldiv;
	Lload(index:Int);
	Lload_0;
	Lload_1;
	Lload_2;
	Lload_3;
	Lmul;
	Lneg;
	Lookupswitch(defaultOffset:Int, pairs:Vector<{match:Int, offset:Int}>);
	Lor;
	Lrem;
	Lreturn;
	Lshl;
	Lshr;
	Lstore(index:Int);
	Lstore_0;
	Lstore_1;
	Lstore_2;
	Lstore_3;
	Lsub;
	Lushr;
	Lxor;
	Monitorenter;
	Monitorexit;
	Multianewarray(type:ConstantClass, dimensions:Int);
	New(type:ConstantClass);
	NewArray(atype:ArrayTypeCode);
	Nop;
	Pop;
	Pop2;
	Putfield(field:ConstantField);
	Putstatic(field:ConstantField);
	Ret(index:Int);
	Return;
	Saload;
	Sastore;
	Sipush(value:Int);
	Swap;
	Tableswitch(defaultOffset:Int, low:Int, high:Int, offsets:Vector<Int>);
	WideIinc(index:Int, const:Int);
	Wide(opcode:Int, index:Int);
}

// Annotation

enum Value {
	ConstValue(constValue:ConstantPoolEntry);
	EnumConstValue(typeName:String, constName:String);
	ClassInfo(classInfo:String);
	AnnotationValue(annotationValue:Annotation);
	ArrayValue(arrayValue:Array<ElementValue>);
}

typedef ElementValue = {
	var tag:Int;
	var value:Value;
}

typedef Annotation = {
	var type:String;
	var elementValuePairs:Array<{elementName:String, elementValue:ElementValue}>;
}

// Attribute

typedef LocalVariableTableEntryBase = {
	var startPc:Int;
	var length:Int;
	var name:String;
	var index:Int;
}

typedef LocalVariableTableEntry = LocalVariableTableEntryBase & {
	var descriptor:String;
}

typedef LocalVariableTypeTableEntry = LocalVariableTableEntryBase & {
	var signature:String;
}

typedef LineNumberTableEntry = {
	var startPc:Int;
	var lineNumber:Int;
}

typedef ExceptionTableEntry = {
	var startPc:Int;
	var endPc:Int;
	var handlerPc:Int;
	var catchType:ConstantClass;
}

typedef Code = {
	var maxStack:Int;
	var maxLocals:Int;
	var code:Vector<Instruction>;
	var exceptionTable:Array<ExceptionTableEntry>;
	var attributes:Array<Attribute>;
}

enum VerificationType {
	VTop;
	VInteger;
	VFloat;
	VDouble;
	VLong;
	VNull;
	VUninitializedThis;
	VObject(index:ConstantClass);
	VUninitialized(offset:Int);
}

enum StackMapFrameKind {
	SameFrame;
	SameLocals1StackItemFrame(stack:VerificationType);
	SameLocals1StackItemFrameExtended(offsetDelta:Int, stack:VerificationType);
	ChopFrame(offsetDelta:Int);
	SameFrameExtended(offsetDelta:Int);
	AppendFrame(offsetDelta:Int, locals:Array<VerificationType>);
	FullFrame(offsetDelta:Int, locals:Array<VerificationType>, stack:Array<VerificationType>);
}

typedef StackMapFrame = {
	var frameType:Int;
	var kind:StackMapFrameKind;
}

typedef InnerClassEntry = {
	var innerClassInfo:ConstantClass;
	var outerClassInfo:ConstantClass;
	var innerName:String;
	var innerClassAccessFlags:ClassAccessFlags;
}

typedef BootstrapMethods = {
	var bootstrapMethodRef:Int;
	var bootstrapArguments:Array<ConstantPoolEntry>;
}

enum Attribute {
	ConstantValue(constantvalue:ConstantPoolEntry);
	Code(code:Code);
	StackMapTable(entries:Array<StackMapFrame>);
	Exceptions(exceptions:Array<ConstantClass>);
	InnerClasses(classes:Array<InnerClassEntry>);
	EnclosingMethod(clazz:ConstantClass, method:ConstantNameAndType);
	Synthetic;
	Signature(signature:String);
	SourceFile(sourcefile:String);
	SourceDebugExtension(debugExtension:Bytes);
	LineNumberTable(table:Array<LineNumberTableEntry>);
	LocalVariableTable(locals:Array<LocalVariableTableEntry>);
	LocalVariableTypeTable(locals:Array<LocalVariableTypeTableEntry>);
	Deprecated;
	RuntimeVisibleAnnotations(annotations:Array<Annotation>);
	RuntimeInvisibleAnnotations(annotations:Array<Annotation>);
	RuntimeVisibleParameterAnnotations(parameterAnnotations:Array<Array<Annotation>>);
	RuntimeInvisibleParameterAnnotations(parameterAnnotations:Array<Array<Annotation>>);
	AnnotationDefault(defaultValue:ElementValue);
	BootstrapMethods(bootstrapMethods:Array<BootstrapMethods>);
}

// Flag

enum abstract ClassAccessFlags(Int) {
	var ACC_PUBLIC = 0x0001;
	var ACC_FINAL = 0x0010;
	var ACC_SUPER = 0x0020;
	var ACC_INTERFACE = 0x0200;
	var ACC_ABSTRACT = 0x0400;
	var ACC_SYNTHETIC = 0x1000;
	var ACC_ANNOTATION = 0x2000;
	var ACC_ENUM = 0x4000;

	public function new(value:Int) {
		this = value;
	}

	public function getValue() {
		return this;
	}
}

enum abstract FieldAccessFlags(Int) {
	var ACC_PUBLIC = 0x0001;
	var ACC_PRIVATE = 0x0002;
	var ACC_PROTECTED = 0x0004;
	var ACC_STATIC = 0x0008;
	var ACC_FINAL = 0x0010;
	var ACC_VOLATILE = 0x0040;
	var ACC_TRANSIENT = 0x0080;
	var ACC_SYNTHETIC = 0x1000;
	var ACC_ENUM = 0x4000;

	public function new(value:Int) {
		this = value;
	}

	public function getValue() {
		return this;
	}
}

enum abstract MethodAccessFlags(Int) {
	var ACC_PUBLIC = 0x0001;
	var ACC_PRIVATE = 0x0002;
	var ACC_PROTECTED = 0x0004;
	var ACC_STATIC = 0x0008;
	var ACC_FINAL = 0x0010;
	var ACC_SYNCHRONIZED = 0x0020;
	var ACC_BRIDGE = 0x0040;
	var ACC_VARARGS = 0x0080;
	var ACC_NATIVE = 0x0100;
	var ACC_ABSTRACT = 0x0400;
	var ACC_STRICT = 0x0800;
	var ACC_SYNTHETIC = 0x1000;

	public function new(value:Int) {
		this = value;
	}

	public function getValue() {
		return this;
	}
}

// Class

typedef Field = {
	var accessFlags:FieldAccessFlags;
	var name:String;
	var descriptor:String;
	var attributes:Array<Attribute>;
}

typedef Method = {
	var accessFlags:MethodAccessFlags;
	var name:String;
	var descriptor:String;
	var attributes:Array<Attribute>;
}

typedef JClass = {
	var minorVersion:Int;
	var majorVersion:Int;
	var accessFlags:ClassAccessFlags;
	var thisClass:ConstantClass;
	var superClass:ConstantClass;
	var interfaces:Array<ConstantClass>;
	var fields:Array<Field>;
	var methods:Array<Method>;
	var attributes:Array<Attribute>;
}
