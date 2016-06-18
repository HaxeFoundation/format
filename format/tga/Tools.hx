package format.tga;
import haxe.io.Bytes;
import format.tga.Data;

/**
 * ...
 * @author Yanrishatum
 */
class Tools
{

  /**
   * Extracts BGRA pixel data from TGA file.  
   * If `extractAlpha` is true, alpha channel will be applied to image, mostly resulting in completely transparent image.  
   * Otherwise alpha will be forced to 0xFF.  
   * If image does not contain image data, 0-filled array returned.
   */
  public static function extract32(data:Data, extractAlpha:Bool):Bytes
  {
    var pixels:Bytes = Bytes.alloc(data.header.width * data.header.height * 4);
    if (data.imageData == null) return pixels;
    var i:Int = 0;
    var alphaOverride:Int = extractAlpha ? 0 : 0xff;
    switch (data.header.imageOrigin)
    {
      case ImageOrigin.TopLeft:
        for (pixel in data.imageData)
        {
          pixels.set(i    , (pixel) & 0xff);
          pixels.set(i + 1, (pixel >> 8) & 0xff);
          pixels.set(i + 2, (pixel >> 16) & 0xff);
          pixels.set(i + 3, ((pixel >> 24) & 0xff) | alphaOverride);
          i += 4;
        }
      case ImageOrigin.BottomLeft:
        var j:Int = 0;
        var y:Int = data.header.height - 1;
        while(y >= 0)
        {
          i = y * data.header.width * 4;
          y--;
          for (x in 0...data.header.width)
          {
            var pixel:Int = data.imageData[j++];
            pixels.set(i    , (pixel) & 0xff);
            pixels.set(i + 1, (pixel >> 8) & 0xff);
            pixels.set(i + 2, (pixel >> 16) & 0xff);
            pixels.set(i + 3, ((pixel >> 24) & 0xff) | alphaOverride);
            i += 4;
          }
        }
      default:
        throw "This origin does not supported";
    }
    return pixels;
  }
  
  /**
   * Extracts alpha channel from TGA file.  
   * If image does not contain image data, 0-filled array returned.
   */
  public static function extractAlpha(data:Data):Bytes
  {
    return extractChannel(data, 24);
  }
  
  /**
   * Extracts grey channel from TGA file.  
   * If image does not contains image data 0-filled array returned.  
   * If image is not black-and-white, error thrown.
   */
  public static function extractGrey(data:Data):Bytes
  {
    if (data.header.imageType != ImageType.RunLengthBlackAndWhite && data.header.imageType != ImageType.UncompressedBlackAndWhite)
    {
      throw "This is not B&W image!";
    }
    return extractChannel(data, 0);
  }
  
  private static function extractChannel(data:Data, offset:Int):Bytes
  {
    var pixels:Bytes = Bytes.alloc(data.header.width * data.header.height);
    if (data.imageData == null) return pixels;
    
    var i:Int = 0;
    
    switch (data.header.imageOrigin)
    {
      case ImageOrigin.TopLeft:
        for (pixel in data.imageData)
        {
          pixels.set(i++, (pixel >> offset) & 0xff);
        }
      case ImageOrigin.BottomLeft:
        var j:Int = 0;
        var y:Int = data.header.height - 1;
        while(y >= 0)
        {
          i = y * data.header.width;
          y--;
          for (x in 0...data.header.width)
          {
            pixels.set(i++, (data.imageData[j++] >> offset) & 0xff);
          }
        }
      default:
        throw "This origin does not supported";
    }
    return pixels;
  }
  
}