package format.gif;

import format.gif.Data;
import haxe.io.Bytes;
import haxe.io.BytesData;

/**
 * ...
 * @author Yanrishatum
 */
class Tools
{

  public static function framesCount(data:Data):Int
  {
    var frames:Int = 0;
    for (block in data.blocks)
    {
      switch(block)
      {
        case Block.BFrame(_):
          trace(block.getName());
          frames++;
        default : trace(block.getName());
      }
    }
    return frames;
  }
  
  public static function frameAtIndex(data:Data, frameIndex:Int):Frame
  {
    var frames:Int = 0;
    for (block in data.blocks)
    {
      switch(block)
      {
        case Block.BFrame(frame):
          if (frames == frameIndex) return frame;
          frames++;
        default :
      }
    }
    return null;
  }
  
  public static function extractBGRA(data:Data, frameIndex:Int):Bytes
  {
    var gce:GraphicControlExtension = null;
    var frameCaret:Int = 0;
    for (block in data.blocks)
    {
      switch (block)
      {
        case Block.BExtension(ext):
          switch(ext)
          {
            case Extension.EGraphicControl(g):
              gce = g;
            default:
          }
        case Block.BFrame(frame):
          if (frameCaret == frameIndex)
          {
            var bytes:Bytes = Bytes.alloc(frame.width * frame.height * 4);
            var ct:Bytes = frame.localColorTable ? frame.colorTable : data.globalColorTable;
            if (ct == null) throw "Frame does not have a color table!";
            var transparentIndex:Int = gce != null && gce.hasTransparentColor ? gce.transparentIndex * 3 : -1;
            var writeCaret:Int = 0;
            for (i in 0...frame.pixels.length)
            {
              var index:Int = frame.pixels.get(i) * 3;
              bytes.set(writeCaret    , ct.get(index + 2)); // B
              bytes.set(writeCaret + 1, ct.get(index + 1)); // G
              bytes.set(writeCaret + 2, ct.get(index    )); // R
              if (transparentIndex == index) bytes.set(writeCaret + 3, 0); // A = 0
              else bytes.set(writeCaret + 3, 0xFF);                        // A = FF
              
              writeCaret += 4;
            }
            return bytes;
          }
          frameCaret++;
          gce = null;
        default:
      }
    }
    return null;
  }
  
}