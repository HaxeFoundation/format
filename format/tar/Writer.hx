package format.tar;
import format.tar.Data;

class Writer {
	
	var o : haxe.io.Output;
	var files : List<{name:String}>;
	
	public function new(o:haxe.io.Output) {
		this.o = o;
		files = new List();
	}

	function sumStr(s:String) {
		var sum = 0;
		for (i in 0...s.length)
			sum += s.charCodeAt(i);
		return sum;
	}

	function createStrNum(num:Int, ?len:Int=7, ?fill:String='0') {
		var str = "";
		var s = Std.string(dec2oct(num));
		for (i in 0...len-s.length)
			str += fill;
		str += s;
		return str;
	}
	
	function writeTarDate(date:Date) {
		var t = date.getTime()/1000;
		var a = Math.floor(t/0x8000); // Avoiding overflow
		var b = Math.floor(t - a*1.0*0x8000);
		return createStrNum(a, 6) + "" + createStrNum(b, 5);
	}
	
	public function writeEntryHeader(f:Entry) {
		var mode = createStrNum(f.fmod & 0x1FF);
		var uid  = createStrNum(f.uid);
		var gid  = createStrNum(f.gid);
		var size = createStrNum(f.fileSize, 11);
		var date = writeTarDate(f.fileTime);
		var chsum = 879; // sum of 8 spaces + "ustar  "
		chsum += sumStr(f.fileName);
		chsum += sumStr(mode);
		chsum += sumStr(uid);
		chsum += sumStr(gid);
		chsum += sumStr(size);
		chsum += sumStr(date);
		chsum += sumStr(f.uname);
		chsum += sumStr(f.gname);
		chsum += sumStr('0');
		o.writeString(f.fileName);
		for(i in 0...100-f.fileName.length) o.writeByte(0);
		o.writeString(mode); o.writeByte(0);
		o.writeString(uid); o.writeByte(0);
		o.writeString(gid); o.writeByte(0);
		o.writeString(size); o.writeByte(0);
		o.writeString(date); o.writeByte(0);
		o.writeString(createStrNum(chsum, 6)); o.writeByte(0);
		o.writeString(" 0");
		for(i in 0...100) o.writeByte(0);
		o.writeString("ustar  "); o.writeByte(0);
		o.writeString(f.uname);
		for(i in 0...32-f.uname.length) o.writeByte(0);
		o.writeString(f.gname);
		for(i in 0...32-f.gname.length) o.writeByte(0);
		for(i in 0...8+8+155+12) o.writeByte(0);
	}

	public function writeEntryData(e:Entry, buf:haxe.io.Bytes, data:haxe.io.Input) {
		format.tools.IO.copy(data, o, buf, e.fileSize);
	}

	public function write(files:Data) {
		for (f in files) {
			writeEntryHeader(f);
			if (f.data != null) {
				o.writeFullBytes(f.data, 0, f.data.length);
				if (f.data.length > 0)
					for (i in 0...512-f.data.length%512)
						o.writeByte(0);
			}
		}
		for (i in 0...2*512)
			o.writeByte(0);
	}

	function dec2oct( d:Int ) {
		var x = 0, i = 1;
		while( d != 0 ) {
			x = x + i*(d & 7);
			d = d >> 3;
			i = i*10;
		}
		return x;
	}
}
