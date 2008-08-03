class Test {

	static var FILE = #if neko neko.Sys.args()[0] #else "012008.pdf" #end;

	static function main() {
		#if flash9
		var request = new flash.net.URLRequest(FILE);
		var u = new flash.net.URLLoader(request);
		u.dataFormat = flash.net.URLLoaderDataFormat.BINARY;
		u.addEventListener(flash.events.Event.COMPLETE,function(_) {
			var b : flash.utils.ByteArray = u.data;
			read( new haxe.io.BytesInput(haxe.io.Bytes.ofData(b)) );
		});
		#elseif neko
		var f = neko.io.File.read(FILE,true);
		read(f);
		#end
	}

	static function read( i ) {
		var p = new format.pdf.Reader();
		var data = p.read(i);
		i.close();
		var data = new format.pdf.Crypt().decrypt(data);
		var data = new format.pdf.Filter().unfilter(data);
		for( o in data ) {
			trace("------------------------------------------------------------------");
			trace(o);
		}
	}

}