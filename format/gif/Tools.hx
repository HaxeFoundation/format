package format.gif;

import format.gif.Data;
import haxe.io.Bytes;
import haxe.io.BytesData;

/**
 * Tools for gif data.
 * @author Yanrishatum
 */
class Tools
{
  /**
   * Returns amount of frames in Gif data.
   */
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
  
  /**
   * Returns frame at given index.
   * @param data Gif data.
   * @param frameIndex Index of frame.
   * @return Frame at given index or null, if there is no frame at that index.
   */
  public static function frame(data:Data, frameIndex:Int):Frame
  {
    var counter:Int = 0;
    for (block in data.blocks)
    {
      switch (block)
      {
        case Block.BFrame(frame):
          if (counter == frameIndex) return frame;
          counter++;
        default :
      }
    }
    return null;
  }
  
  /**
   * Returns Graphic Control extension for frame at given index.
   * @param data Gif data.
   * @param frameIndex Index of frame.
   * @return GCE extension if it is exists for given frame, null otherwise.
   */
  public static function graphicControl(data:Data, frameIndex:Int):GraphicControlExtension
  {
    var counter:Int = 0;
    var gce:GraphicControlExtension = null;
    for (block in data.blocks)
    {
      switch (block)
      {
        case Block.BFrame(frame):
          if (counter == frameIndex) return gce;
          gce = null;
          counter++;
        case Block.BExtension(Extension.EGraphicControl(g)):
          gce = g;
        default :
      }
    }
    return null;
  }
  
  //==========================================================
  // Extracting.
  //==========================================================
  
  /**
   * Extracts frame pixel data in Blue-Green-Red-Alpha pixel format.
   * This function extracts only exact frame and does put previous frame pixel data into resulting Bytes. Note that frame size may not equal to Gif logical screen size.
   * @param data Gif data.
   * @param frameIndex Frame index.
   * @return BGRA pixel data with dimensions equals to specified Frame size. If frame does not present in Gif data returns null.
   */
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
  
  /**
   * Extracts frame pixel data in Red-Green-Blue-Alpha pixel format.
   * This function extracts only exact frame and does put previous frame pixel data into resulting Bytes. Note that frame size may not equal to Gif logical screen size.
   * @param data Gif data.
   * @param frameIndex Frame index.
   * @return RGBA pixel data with dimensions equals to specified Frame size. If frame does not present in Gif data returns null.
   */
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
  
  /**
   * Extracts full Gif pixel data to specified frame in Blue-Green-Red-Alpha pixel format.
   * This functions returns full representation of frame including rendering of all other frames before.
   * @param data Gif data.
   * @param frameIndex Frame index.
   * @return BGRA pixel data with dimensions equals to Gif logical screen with full pixel data of Gif image at specified frame.
   */
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
  
  /**
   * Extracts full Gif pixel data to specified frame in Red-Green-Blue-Alpha pixel format.
   * This functions returns full representation of frame including rendering of all other frames before.
   * @param data Gif data.
   * @param frameIndex Frame index.
   * @return RGBA pixel data with dimensions equals to Gif logical screen with full pixel data of Gif image at specified frame.
   */
  public static function extractFullRGBA(data:Data, frameIndex:Int):Bytes
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
                bytes.set(writeCaret    , 0); // R
                bytes.set(writeCaret + 1, 0); // G
                bytes.set(writeCaret + 2, 0); // B
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
                  bytes.set(writeCaret    , ct.get(index    )); // R
                  bytes.set(writeCaret + 1, ct.get(index + 1)); // G
                  bytes.set(writeCaret + 2, ct.get(index + 2)); // B
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
  
  /**
   * Returns amount of animation repeats stored in Gif data.
   * This is link to Netscape Looping application extension. If this extension does not present amount of loops equals to 1.
   * @param data Gif data.
   * @return Amount of animation repeats. Zero equals to infinite amount of repeats.
   */
  public static function loopCount(data:Data):Int
  {
    for (block in data.blocks)
    {
      switch(block)
      {
        case Block.BExtension(Extension.EApplicationExtension(ApplicationExtension.AENetscapeLooping(loops))): return loops;
        default :
      }
    }
    return 1;
  }
  
  //==========================================================
  // In-Dev writer tools.
  //==========================================================
  
  //public static function buildFrameFromTrueColor(pixels:Bytes, width:Int, height:Int):Void
  //{
    //
  //}
  
  private static var LN2:Float = Math.log(2);
  @:noCompletion public static inline function log2(val:Float):Float
  {
    return Math.log(val) / LN2;
  }
}