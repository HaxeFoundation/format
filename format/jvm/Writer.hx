package format.jvm;

import format.jvm.Data;
import haxe.Int64;
import haxe.io.Encoding;
import haxe.io.Output;

class Writer {
	var o:Output;

	public function new(o:Output) {
		this.o = o;
		o.bigEndian = true;
	}

	function writeUInt16Array<T>(a:Array<T>, f:T->Void) {
		o.writeUInt16(a.length);
		for (x in a) {
			f(x);
		}
	}

	// Constant pool

	function writeConstantPool(constantPool:ConstantPool) {
		o.writeInt16(constantPool.length);

		for (i in 1...constantPool.length) {
			switch (constantPool[i]) {
				case CONSTANT_Class(name_index):
					o.writeByte(7);
					o.writeUInt16(name_index);
				case CONSTANT_Fieldref(class_index, name_and_type_index):
					o.writeByte(9);
					o.writeUInt16(class_index);
					o.writeUInt16(name_and_type_index);
				case CONSTANT_Methodref(class_index, name_and_type_index):
					o.writeByte(10);
					o.writeUInt16(class_index);
					o.writeUInt16(name_and_type_index);
				case CONSTANT_InterfaceMethodref(class_index, name_and_type_index):
					o.writeByte(11);
					o.writeUInt16(class_index);
					o.writeUInt16(name_and_type_index);
				case CONSTANT_String(string_index):
					o.writeByte(8);
					o.writeUInt16(string_index);
				case CONSTANT_Integer(i32):
					o.writeByte(3);
					o.writeInt32(i32);
				case CONSTANT_Float(f32):
					o.writeByte(4);
					o.writeFloat(f32);
				case CONSTANT_Long(i64):
					o.writeByte(5);
					o.writeInt32(i64.high);
					o.writeInt32(i64.low);
				case CONSTANT_Double(f64):
					o.writeByte(6);
					o.writeDouble(f64);
				case CONSTANT_NameAndType(name_index, descriptor_index):
					o.writeByte(12);
					o.writeInt16(name_index);
					o.writeInt16(descriptor_index);
				case CONSTANT_Utf8(bytes):
					o.writeByte(10);
					o.writeUInt16(bytes.length);
					o.write(bytes);
				case CONSTANT_MethodHandle(reference_kind, reference_index):
					o.writeByte(15);
					o.writeByte(reference_kind);
					o.writeInt16(reference_index);
				case CONSTANT_MethodType(descriptor_index):
					o.writeByte(16);
					o.writeInt16(descriptor_index);
				case CONSTANT_InvokeDynamic(bootstrap_method_attr_index, name_and_type_index):
					o.writeByte(18);
					o.writeInt16(bootstrap_method_attr_index);
					o.writeInt16(name_and_type_index);
			}
		}
	}

	// Attribute

	function writeAttribute(a:Attribute) {}

	// Field

	function writeField(f:Field) {
		o.writeUInt16(f.access_flags.getValue());
		o.writeUInt16(f.name_index);
		o.writeUInt16(f.descriptor_index);
		writeUInt16Array(f.attributes, writeAttribute);
	}

	// Class

	public function write(c:JClass) {
		o.writeInt32(0xCAFEBABE);
		o.writeInt16(c.minor_version);
		o.writeInt16(c.major_version);
		writeConstantPool(c.constant_pool);
		o.writeUInt16(c.access_flags.getValue());
		o.writeUInt16(c.this_class);
		o.writeUInt16(c.super_class);
		writeUInt16Array(c.interfaces, o.writeUInt16);
		writeUInt16Array(c.fields, writeField);
	}
}
