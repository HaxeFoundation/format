import format.swf.Data;

class Test {

	static function main() {
		#if neko
		var file = neko.Sys.args()[0];
		var bytes = neko.io.File.getBytes(file);
		decode(bytes);
		#else
		var l = new flash.net.URLLoader();
		l.dataFormat = flash.net.URLLoaderDataFormat.BINARY;
		l.addEventListener(flash.events.Event.COMPLETE,function(_) {
			decode(haxe.io.Bytes.ofData(l.data));
		});
		l.load(new flash.net.URLRequest("file.swf"));
		#end
	}

	static function decode( bytes : haxe.io.Bytes ) {
		// read
		var t = haxe.Timer.stamp();
		var i = new haxe.io.BytesInput(bytes);
		var reader = new format.swf.Reader(i);
		var h = reader.readHeader();
		var tags = reader.readTagList();
		i.close();
		trace( haxe.Timer.stamp() - t );
		trace(h);
		#if neko
		for( t in tags ) {
			var str = tagStr(t);
			#if neko
			neko.Lib.println(str);
			#else
			trace(str);
			#end
		}
		#end
	}

	static function poStr(data:PlaceObject) {
		return "<...>";
	}

	static function tagStr(t) {
		return switch(t) {
		case TShape(sid,version,data):
			"Shape"+version+" #"+sid+" ["+data.length+"]";
		case TShowFrame:
			"ShowFrame";
		case TClip(cid,frames,tags):
			var str = "Clip #"+cid+":"+frames;
			for( t in tags )
				str += "\n  "+tagStr(t);
			return str;
		case TUnknown(id,data):
			"0x"+StringTools.hex(id,2)+" ["+data.length+"]";
		case TPlaceObject3(data):
			"PlaceObject3 "+poStr(data);
		case TPlaceObject2(data):
			"PlaceObject2 "+poStr(data);
		case TRemoveObject2(depth):
			"RemoveObject2 @"+depth;
		case TFrameLabel(label,anchor):
			"FrameLabel "+label+(anchor ? " [ANCHOR]" : "");
		case TExtended(t):
			tagStr(t);
		};
	}

}