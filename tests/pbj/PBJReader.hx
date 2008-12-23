import flash.events.Event;
import flash.events.MouseEvent;

class PBJReader {

	static var tf : flash.text.TextField;

	static function main() {
		var root = flash.Lib.current;
		tf = new flash.text.TextField();
		tf.width = root.stage.stageWidth;
		tf.height = root.stage.stageHeight;
		tf.text = "Click to load PBJ file";
		root.addChild(tf);
		root.stage.addEventListener(MouseEvent.CLICK,onClick);
	}

	static function onClick(_) {
		var l = new flash.net.FileReference();
		l.addEventListener(Event.SELECT,function(_) l.load());
		l.addEventListener(Event.COMPLETE,function(_) dumpPBJ(l.data));
		l.browse([new flash.net.FileFilter("Pixel Bender File","*.pbj")]);
	}

	static function dumpPBJ( data : flash.utils.ByteArray ) {
		var bytes = haxe.io.Bytes.ofData(data);
		var input = new haxe.io.BytesInput(bytes);
		var reader = new format.pbj.Reader(input);
		var pbj = reader.read();
		tf.text = format.pbj.Tools.dump(pbj);
	}

}