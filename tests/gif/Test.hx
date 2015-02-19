import haxe.io.Bytes;
import sys.io.File;
import format.gif.Reader;
import format.gif.Data;
import format.gif.Tools;
import format.png.Writer;

class Test
{
	static function main()
  {
    var i = File.read("read.gif", true);
    var data:Data = new Reader(i).read();
    
    var frames:Int = Tools.framesCount(data);
    for (i in 0...frames)
    {
      var frame:Frame = Tools.frameAtIndex(data, i);
      var bytes:Bytes = Tools.extractBGRA(data, i);
      var pngData:format.png.Data = format.png.Tools.build32BGRA(frame.width, frame.height, bytes);
      var out = File.write("frame_" + i + ".png", true);
      new Writer(out).write(pngData);
      out.flush();
      out.close();
    }
	}

}