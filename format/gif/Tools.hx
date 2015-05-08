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
          frames++;
        default :
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
  
  public static function frameGraphicControlExtension(data:Data, frameIndex:Int):GraphicControlExtension
  {
    var frames:Int = 0;
    var gce:GraphicControlExtension = null;
    for (block in data.blocks)
    {
      switch (block)
      {
        case Block.BFrame(frame):
          if (frames == frameIndex) return gce;
          gce = null;
          frames++;
        case Block.BExtension(Extension.EGraphicControl(g)):
          gce = g;
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
  
  public static function extractRGBA(data:Data, frameIndex:Int):Bytes
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
              bytes.set(writeCaret    , ct.get(index    )); // R
              bytes.set(writeCaret + 1, ct.get(index + 1)); // G
              bytes.set(writeCaret + 2, ct.get(index + 2)); // B
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
  
  public static function extractFullBGRA(data:Data, frameIndex:Int):Bytes
  {
    var gce:GraphicControlExtension = null;
    var frameCaret:Int = 0;
    
    var bytes:Bytes = Bytes.alloc(data.logicalScreenDescriptor.width* data.logicalScreenDescriptor.height * 4);
    
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
          var ct:Bytes = frame.localColorTable ? frame.colorTable : data.globalColorTable;
          if (ct == null) throw "Frame does not have a color table!";
          var transparentIndex:Int = gce != null && gce.hasTransparentColor ? gce.transparentIndex * 3 : -1;
          var pixels:Bytes = frame.pixels;
          var x:Int = 0;
          var writeCaret:Int = (frame.y * data.logicalScreenDescriptor.width + frame.x) * 4;
          var lineSkip:Int = (data.logicalScreenDescriptor.width - frame.width) * 4 + 4;
          
          var disposalMethod:DisposalMethod = frameCaret != frameIndex && gce != null ? gce.disposalMethod : DisposalMethod.NO_ACTION;
          
          switch (disposalMethod)
          {
            case DisposalMethod.RENDER_PREVIOUS:
              // Do not render frame at all
            case DisposalMethod.FILL_BACKGROUND:
              for (i in 0...pixels.length)
              {
                bytes.set(writeCaret    , 0); // B
                bytes.set(writeCaret + 1, 0); // G
                bytes.set(writeCaret + 2, 0); // R
                bytes.set(writeCaret + 3, 0); // A
                
                if (++x == frame.width)
                {
                  x = 0;
                  writeCaret += lineSkip;
                }
                else writeCaret += 4;
              }
            default:
              for (i in 0...pixels.length)
              {
                var index:Int = pixels.get(i) * 3;
                if (transparentIndex != index) // Render only if pixel non-transparent
                {
                  bytes.set(writeCaret    , ct.get(index + 2)); // B
                  bytes.set(writeCaret + 1, ct.get(index + 1)); // G
                  bytes.set(writeCaret + 2, ct.get(index    )); // R
                  bytes.set(writeCaret + 3, 0xFF);              // A
                }
                
                if (++x == frame.width)
                {
                  x = 0;
                  writeCaret += lineSkip;
                }
                else writeCaret += 4;
              }
          }
          
          if (frameCaret == frameIndex) return bytes;
          frameCaret++;
          gce = null;
        default:
      }
    }
    
    return bytes;
  }
  
  public static function buildFrameFromTrueColor(pixels:Bytes, width:Int, height:Int):Void
  {
    
  }
  
  public static function loopCount(data:Data):Int
  {
    var frames:Int = 0;
    for (block in data.blocks)
    {
      switch(block)
      {
        case Block.BExtension(Extension.EApplicationExtension(ApplicationExtension.AENetscapeLooping(loops))): return loops;
        default :
      }
    }
    return frames;
  }
  
  private static var LN2:Float = Math.log(2);
  @:noCompletion public static inline function log2(val:Float):Float
  {
    return Math.log(val) / LN2;
  }
}