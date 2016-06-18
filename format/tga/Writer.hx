package format.tga;
import format.tga.Data;
import haxe.ds.Vector;
import haxe.io.Output;

/**
 * ...
 * @author Yanrishatum
 */
class Writer
{
  
  private var o:Output;

  public function new(o:Output) 
  {
    this.o = o;
  }
  
  public function write(data:Data):Void
  {
    writeHeader(data);
    if (data.imageId != null) o.writeString(data.imageId);
    switch (data.header.imageType)
    {
      case ImageType.NoImage:
        writeColorMap(data);
        
      case ImageType.UncompressedColorMapped:
        writeColorMap(data);
        writeIndexes(data, false);
      case ImageType.UncompressedTrueColor:
        writeTrueColor(data, false);
      case ImageType.UncompressedBlackAndWhite:
        writeMono(data, false);
      case ImageType.RunLengthColorMapped:
        writeColorMap(data);
        writeIndexes(data, true);
      case ImageType.RunLengthTrueColor:
        writeTrueColor(data, true);
      case ImageType.RunLengthBlackAndWhite:
        writeMono(data, true);
        
      default: 
        throw "Unsupported image type";
    }
    
  }
  
  private function writeTrueColor(data:Data, rle:Bool):Void
  {
    writePixels(data.imageData, data.header.bitsPerPixel, data.header.alphaChannelBits != 0, rle);
  }
  
  private function writeColorMap(data:Data):Void
  {
    writePixels(data.colorMapData, data.header.colorMapEntrySize, data.header.alphaChannelBits != 0, false);
  }
  
  private function writeIndexes(data:Data, rle:Bool):Void
  {
    var pal:Vector<Int> = data.colorMapData;
    var pixels:Vector<Int> = data.imageData;
    if (rle)
    {
      throw "Run-Length encoding does not supported yet";
    }
    else
    {
      var writeFunc:Int->Void;
      switch (data.header.bitsPerPixel)
      {
        case 8:
          writeFunc = o.writeByte;
        case 24:
          writeFunc = o.writeUInt24;
        case 32:
          writeFunc = o.writeInt32;
        default:
          throw "Unsupported bits per pixels amount";
      }
      
      var i:Int = 0;
      
      inline function indexOf(val:Int):Int
      {
        var off:Int = 0;
        while (off < pal.length)
        {
          if (pal[off] == val) break;
          off++;
        }
        return off;
      }
      
      while (i < pixels.length)
      {
        writeFunc(indexOf(pixels[i++]));
      }
    }
  }
  
  private function writeMono(data:Data, rle:Bool):Void
  {
    var pixels:Vector<Int> = data.imageData;
    if (rle)
    {
      throw "Run-Length encoding does not supported yet";
    }
    else
    {
      var alhpa:Bool = data.header.bitsPerPixel == 16;
      
      var i:Int = 0;
      while (i < pixels.length)
      {
        var pix:Int = pixels[i++];
        o.writeByte(pix & 0xff);
        if (alhpa) o.writeByte((pix >> 24) & 0xff);
      }
    }
  }
  
  private function writePixels(pixels:Vector<Int>, bitsPerPixel:Int, alpha:Bool, rle:Bool):Void
  {
    if (rle) throw "Run-Length encoding does not supported yet";
    else
    {
      var writeFunc:Int->Void;
      var encodeFunc:Int->Bool->Int;
      switch (bitsPerPixel)
      {
        case 16:
          writeFunc = o.writeUInt16;
          encodeFunc = encode16;
        case 24:
          writeFunc = o.writeUInt24;
          encodeFunc = encode24;
        case 32:
          writeFunc = o.writeInt32;
          encodeFunc = encode32;
        default:
          throw "Unsupported bits per pixels amount";
      }
      
      var i:Int = 0;
      while (i < pixels.length)
      {
        writeFunc(encodeFunc(pixels[i++], alpha));
      }
    }
  }
  
  private function encode16(color:Int, alpha:Bool):Int
  {
    return (alpha ? ((color & 0xff000000) != 0 ? 0x8000 : 0) : 0)  | // A
           Std.int(((color & 0xff0000) >> 16) / 0xff * 0x1f) << 10 | // R
           Std.int(((color & 0xff00) >> 8) / 0xff * 0x1f) << 5     | // G
           Std.int((color & 0xff) / 0xff * 0x1f);                    // B
  }
  
  private function encode24(color:Int, alpha:Bool):Int
  {
    return color & 0xffffff;
  }
  
  private function encode32(color:Int, alpha:Bool):Int
  {
    return alpha ? color : color & 0xffffff;
  }
  
  private function writeHeader(data:Data):Void
  {
    var h:Header = data.header;
    o.writeByte(data.imageId != null ? data.imageId.length : 0);
    o.writeByte(h.colorMapType);
    switch (h.imageType)
    {
      case ImageType.NoImage:
        o.writeByte(0);
      case ImageType.UncompressedColorMapped:
        o.writeByte(1);
      case ImageType.UncompressedTrueColor:
        o.writeByte(2);
      case ImageType.UncompressedBlackAndWhite:
        o.writeByte(3);
      case ImageType.RunLengthColorMapped:
        o.writeByte(9);
      case ImageType.RunLengthTrueColor:
        o.writeByte(10);
      case ImageType.RunLengthBlackAndWhite:
        o.writeByte(11);
      case ImageType.Unknown(type):
        o.writeByte(type);
    }
    
    o.writeInt16(h.colorMapFirstIndex);
    o.writeInt16(h.colorMapLength);
    o.writeByte(h.colorMapEntrySize);
    
    o.writeInt16(h.xOrigin);
    o.writeInt16(h.yOrigin);
    o.writeInt16(h.width);
    o.writeInt16(h.height);
    o.writeByte(h.bitsPerPixel);
    var descriptor:Int = h.alphaChannelBits;
    switch (h.imageOrigin)
    {
      case ImageOrigin.BottomLeft:
        // None
      case ImageOrigin.BottomRight:
        descriptor |= 0x10;
      case ImageOrigin.TopLeft:
        descriptor |= 0x20;
      case ImageOrigin.TopRight:
        descriptor |= 0x30;
    }
    o.writeByte(descriptor);
  }
  
}