package format.tga;
import format.tga.Data;
import haxe.ds.Vector;
import haxe.io.Input;

/**
 * ...
 * @author Yanrishatum
 */
class Reader
{

  private var i:Input;
  
  public function new(i:Input) 
  {
    this.i = i;
    i.bigEndian = false;
  }
  
  public function read():Data
  {
    var idLength:Int = i.readByte();
    var header:Header = readHeader();
    var id:String = idLength == 0 ? "" : i.readString(idLength);
    var colorMap:Vector<Int> = readColorMapData(header);
    
    return {
      header: header,
      imageId: id,
      colorMapData: colorMap,
      imageData: readImageData(header, colorMap),
      developerData: null
    };
  }
  
  private function readHeader():Header
  {
    var colorMapType:Int = i.readByte();
    var dataType:ImageType;
    var dataId:Int = i.readByte();
    switch (dataId)
    {
      case 0:
        dataType = ImageType.NoImage;
      case 1:
        dataType = ImageType.UncompressedColorMapped;
      case 2:
        dataType = ImageType.UncompressedTrueColor;
      case 3:
        dataType = ImageType.UncompressedBlackAndWhite;
      case 9:
        dataType = ImageType.RunLengthColorMapped;
      case 10:
        dataType = ImageType.RunLengthTrueColor;
      case 11:
        dataType = ImageType.RunLengthBlackAndWhite;
      default:
        dataType = ImageType.Unknown(dataId);
    }
    
    var colorMapOrigin:Int = i.readInt16();
    var colorMapLength:Int = i.readInt16();
    var colorMapDepth:Int = i.readByte();
    
    var xOrigin:Int = i.readInt16();
    var yOrigin:Int = i.readInt16();
    var width:Int = i.readInt16();
    var height:Int = i.readInt16();
    var depth:Int = i.readByte();
    var descriptor:Int = i.readByte();
    var origin:ImageOrigin;
    
    switch ((descriptor & 0x30))
    {
      case 0x30: origin = ImageOrigin.TopRight;
      case 0x20: origin = ImageOrigin.TopLeft;
      case 0x10: origin = ImageOrigin.BottomRight;
      default: origin = ImageOrigin.BottomLeft;
    }
    
    return
    {
      colorMapType: colorMapType,
      imageType: dataType,
      
      colorMapFirstIndex: colorMapOrigin,
      colorMapLength: colorMapLength,
      colorMapEntrySize: colorMapDepth,
      
      xOrigin: xOrigin,
      yOrigin: yOrigin,
      width: width,
      height: height,
      bitsPerPixel: depth,
      
      alphaChannelBits: descriptor & 0xf,
      imageOrigin: origin
    };
  }
  
  // Currently supports only color maps with 
  private function readColorMapData(header:Header):Vector<Int>
  {
    if (header.colorMapType == 0) return null;
    return readPixels(header.colorMapEntrySize, header.colorMapLength, header.alphaChannelBits, false);
  }
  
  private function readImageData(header:Header, colorMap:Vector<Int>):Vector<Int>
  {
    switch (header.imageType)
    {
      case ImageType.NoImage:
        return null;
        
      case ImageType.UncompressedTrueColor:
        return readPixels(header.bitsPerPixel, header.width * header.height, header.alphaChannelBits, false);
      case ImageType.RunLengthTrueColor:
        return readPixels(header.bitsPerPixel, header.width * header.height, header.alphaChannelBits, true);
        
      case ImageType.UncompressedBlackAndWhite: // This one a bit tricky
        return readMono(header.bitsPerPixel, header.width * header.height, header.alphaChannelBits, false);
      case ImageType.RunLengthBlackAndWhite:
        return readMono(header.bitsPerPixel, header.width * header.height, header.alphaChannelBits, true);
        
      case ImageType.UncompressedColorMapped:
        return readIndexes(header.bitsPerPixel, header.width * header.height, colorMap, header.colorMapFirstIndex, false);
      case ImageType.RunLengthColorMapped:
        return readIndexes(header.bitsPerPixel, header.width * header.height, colorMap, header.colorMapFirstIndex, true);
        
      default:
        throw "Unsupported image data type!";
    }
  }
  
  private function readPixels(bitsPerPixel:Int, amount:Int, alphaChannelBits:Int, rle:Bool):Vector<Int>
  {
    var list:Vector<Int> = new Vector(amount);
    // Total length of color map data
    var alpha:Bool = alphaChannelBits != 0;
    
    var bitFieldSize:Int = Std.int(bitsPerPixel / 3);
    if (bitFieldSize > 8) bitFieldSize = 8;
    
    var parsePixel:Int->Bool->Int;
    var readEntry:Void->Int;
    switch (bitsPerPixel)
    {
      case 8:
        readEntry = i.readByte;
        parsePixel = parsePixel1;
      case 16:
        readEntry = i.readUInt16;
        parsePixel = parsePixel2;
      case 24:
        readEntry = i.readUInt24;
        parsePixel = parsePixel3;
      case 32:
        readEntry = i.readInt32;
        parsePixel = parsePixel4;
      default:
        throw "Unsupported bits per pixels amount!";
    }
    
    if (rle)
    {
      var rleChunk:Int;
      var i:Int = 0;
      while (i < amount)
      {
        rleChunk = this.i.readByte();
        if ((rleChunk & 0x80) != 0) // RLE
        {
          rleChunk = rleChunk & 0x7F;
          var pixel:Int = parsePixel(readEntry(), alpha);
          while (rleChunk >= 0)
          {
            list[i++] = pixel;
            rleChunk--;
          }
        }
        else // Raw
        {
          rleChunk = rleChunk & 0x7F;
          while (rleChunk >= 0)
          {
            list[i++] = parsePixel(readEntry(), alpha);
            rleChunk--;
          }
        }
      }
    }
    else
    {
      for (i in 0...amount)
      {
        list[i] = parsePixel(readEntry(), alpha);
      }
      
    }
    
    
    return list;
  }
  
  private function readMono(bitsPerPixel:Int, amount:Int, alphaChannelBits:Int, rle:Bool):Vector<Int>
  {
    var list:Vector<Int> = new Vector(amount);
    // Total length of color map data
    var alpha:Bool = alphaChannelBits != 0;
    
    var parsePixel:Int->Bool->Int;
    var readEntry:Void->Int;
    switch (bitsPerPixel)
    {
      case 8:
        readEntry = i.readByte;
        parsePixel = parsePixel1;
      case 16:
        readEntry = i.readUInt16;
        parsePixel = parsePixelGreyAlpha;
      default:
        throw "Unsupported bits per pixels amount!";
    }
    
    if (rle)
    {
      var rleChunk:Int;
      var i:Int = 0;
      while (i < amount)
      {
        rleChunk = this.i.readByte();
        if ((rleChunk & 0x80) != 0) // RLE
        {
          rleChunk = rleChunk & 0x7F;
          var pixel:Int = parsePixel(readEntry(), alpha);
          while (rleChunk >= 0)
          {
            list[i++] = pixel;
            rleChunk--;
          }
        }
        else // Raw
        {
          rleChunk = rleChunk & 0x7F;
          while (rleChunk >= 0)
          {
            list[i++] = parsePixel(readEntry(), alpha);
            rleChunk--;
          }
        }
      }
    }
    else
    {
      for (i in 0...amount)
      {
        list[i] = parsePixel(readEntry(), alpha);
      }
    }
    
    
    return list;
  }
  
  private function readIndexes(bitsPerPixel:Int, amount:Int, colorMap:Vector<Int>, offset:Int, rle:Bool):Vector<Int>
  {
    var list:Vector<Int> = new Vector(amount);
    
    var readEntry:Void->Int;
    switch (bitsPerPixel)
    {
      case 8:
        readEntry = i.readByte;
      case 16:
        readEntry = i.readUInt16;
      case 24:
        readEntry = i.readUInt24;
      case 32:
        readEntry = i.readInt32;
      default:
        throw "Unsupported bits per pixels amount!";
    }
    
    if (rle)
    {
      var i:Int = 0;
      var rleChunk:Int;
      while (i < amount)
      {
        rleChunk = this.i.readByte();
        if ((rleChunk & 0x80) != 0) // RLE
        {
          rleChunk = rleChunk & 0x7F;
          var pixel:Int = colorMap[offset + readEntry()];
          while (rleChunk >= 0)
          {
            list[i++] = pixel;
            rleChunk--;
          }
        }
        else // RAW
        {
          rleChunk = rleChunk & 0x7F;
          while (rleChunk >= 0)
          {
            list[i++] = colorMap[offset + readEntry()];
            rleChunk--;
          }
        }
      }
    }
    else
    {
      for (i in 0...amount)
      {
        list[i] = colorMap[offset + readEntry()];
      }
    }
    
    return list;
  }
  
  private function parsePixel1(value:Int, alpha:Bool):Int
  {
    return (value << 16) | (value << 8) | value;
  }
  
  private function parsePixelGreyAlpha(value:Int, alpha:Bool):Int
  {
    return (alpha ? (value & 0xff00) << 16 : 0) | parsePixel1(value & 0xff, false);
  }
  
  private function parsePixel2(value:Int, alpha:Bool):Int
  {
    return (alpha ? ((value & 0x8000) == 1 ? 0xff000000 : 0) : 0) | // A
          Std.int(((value & 0x7C00) >> 10) / 0x1F * 0xff) << 16 | // R
          Std.int(((value & 0x3E0) >> 5) / 0x1F * 0xff) << 8 | // G
          Std.int((value & 0x1F) / 0x1F * 0xff); // B
  }
  
  private function parsePixel3(value:Int, alpha:Bool):Int
  {
    return value;
  }
  
  private function parsePixel4(value:Int, alpha:Bool):Int
  {
    return value;
  }
  
}