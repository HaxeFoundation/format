package format.gif;
import format.gif.Data;
import haxe.io.Bytes;
import haxe.io.BytesOutput;
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
    for (b in [71, 73, 70])
    {
      if (i.readByte() != b) throw "Invalid header";
    }
    
    var gifVer:String = i.readString(3);
    var version:Version = Version.GIF89a;
    switch(gifVer)
    {
      case "87a": version = Version.GIF87a;
      case "89a": version = Version.GIF89a;
      default: version = Version.Unknown(gifVer);
    }
    
    // Logical screen descriptor.
    var width:Int = i.readUInt16();
    var height:Int = i.readUInt16();
    var packedField:Int = i.readByte();
    var bgIndex:Int = i.readByte();
    var pixelAspectRatio:Float = i.readByte();
    if (pixelAspectRatio != 0) pixelAspectRatio = (pixelAspectRatio + 15) / 64;
    else pixelAspectRatio = 1;
    
    var lsd:LogicalScreenDescriptor =
    {
      width: width,
      height: height,
      hasGlobalColorTable: (packedField & 128) == 128,
      colorResolution: (packedField & 112) >>> 4,
      sorted: (packedField & 8) == 8,
      globalColorTableSize: 2 << (packedField & 7),
      backgroundColorIndex: bgIndex,
      pixelAspectRatio: pixelAspectRatio
    }
    
    var gct:ColorTable = null;
    if (lsd.hasGlobalColorTable) gct = readColorTable(lsd.globalColorTableSize);
    
    var blocks:List<Block> = new List();
    
    while (true)
    {
      var b:Block = readBlock();
      blocks.add(b);
      if (b == Block.BEOF) break;
    }
    
    return
    {
      version: version,
      logicalScreenDescriptor: lsd,
      globalColorTable: gct,
      blocks: blocks
    }
  }
  
  private function readBlock():Block
  {
    var blockID:Int = i.readByte();
    switch(blockID)
    {
      case 0x2C:
        // Image
        return readImage();
      case 0x21:
        // Extension
        return readExtension();
      case 0x3B:
        return Block.BEOF;
    }
    // The behaviour of taking unknown block ID is unspecified.
    return Block.BEOF;
  }
  
  private function readImage():Block
  {
    var x:Int = i.readUInt16();
    var y:Int = i.readUInt16();
    var width:Int = i.readUInt16();
    var height:Int = i.readUInt16();
    var packed:Int = i.readByte();
    var localColorTable:Bool = (packed & 128) == 128;
    var interlaced:Bool = (packed & 64) == 64;
    var sorted:Bool = (packed & 32) == 32;
    var localColorTableSize:Int = 2 << (packed & 7);
    
    var lct:ColorTable = null;
    if (localColorTable) lct = readColorTable(localColorTableSize);
    
    return Block.BFrame(
    {
      x: x, 
      y: y,
      width: width,
      height: height,
      localColorTable: localColorTable,
      interlaced:interlaced,
      sorted:sorted,
      localColorTableSize:localColorTableSize,
      pixels:readPixels(width, height, interlaced),
      colorTable:lct
    });
    
  }
  
  private function readPixels(width:Int, height:Int, interlaced:Bool):Bytes
  {
    var input:Input = this.i;
    
    var pixelsCount:Int = width * height;
    var pixels:Bytes = Bytes.alloc(pixelsCount);
    
    var minCodeSize:Int = input.readByte();
    
    var blockSize:Int = input.readByte() - 1;
    var bits:Int = input.readByte();
    var bitsCount:Int = 8;
    
    var clearCode:Int = 1 << minCodeSize;
    var eoiCode:Int = clearCode + 1;
    
    var codeSize:Int = minCodeSize + 1;
    var codeSizeLimit:Int = 1 << codeSize;
    var codeMask = codeSizeLimit - 1;
    
    
    var baseDict:Array<Array<Int>> = new Array();
    for (i in 0...clearCode) baseDict[i] = [i];
    
    var dict:Array<Array<Int>> = new Array();
    var dictLen:Int = clearCode + 2;
    var newRecord:Array<Int>;
    
    var i:Int = 0;
    var code:Int = 0;
    var last:Int;
    
    while (i < pixelsCount)
    {
      last = code;
      while (bitsCount < codeSize)
      {
        if (blockSize == 0) break;
        bits |= input.readByte() << bitsCount;
        bitsCount += 8;
        blockSize--;
        if (blockSize == 0) blockSize = input.readByte();
      }
      code = bits & codeMask;
      bits >>= codeSize;
      bitsCount -= codeSize;
      
      if (code == clearCode)
      {
        dict = baseDict.copy();
        dictLen = clearCode + 2;
        codeSize = minCodeSize + 1;
        codeSizeLimit = (1 << codeSize);
        codeMask = codeSizeLimit - 1;
        continue;
      }
      if (code == eoiCode) break;
      
      if (code < dictLen)
      {
        if (last != clearCode)
        {
          newRecord = dict[last].copy();
          newRecord.push(dict[code][0]);
          dict[dictLen++] = newRecord;
        }
      }
      else
      {
        if (code != dictLen) throw 'Invalid LZW code. Excepted: $dictLen, got: $code';
        newRecord = dict[last].copy();
        newRecord.push(newRecord[0]);
        dict[dictLen++] = newRecord;
      }
      
      newRecord = dict[code];
      for (item in newRecord) pixels.set(i++, item);
      
      if (dictLen == codeSizeLimit && codeSize < 12)
      {
        codeSize++;
        codeSizeLimit = (1 << codeSize);
        codeMask = codeSizeLimit - 1;
      }
    }
    
    // Just in case
    while (blockSize > 0)
    {
      input.readByte();
      blockSize--;
      if (blockSize == 0) blockSize = input.readByte();
    }
    
    while (i < pixelsCount) pixels.set(i++, 0);
    if (interlaced)
    {
      var buffer:Bytes = Bytes.alloc(pixelsCount);
      var offset:Int = deinterlace(pixels, buffer, 8, 0, 0     , width, height); // Every 8 line with start at 0
          offset     = deinterlace(pixels, buffer, 8, 4, offset, width, height); // Every 8 line with start at 4
          offset     = deinterlace(pixels, buffer, 4, 2, offset, width, height); // Every 4 line with start at 2
                       deinterlace(pixels, buffer, 2, 1, offset, width, height); // Every 2 line with start at 1
      pixels = buffer;
    }
    return pixels;
  }
  
  private function deinterlace(input:Bytes, output:Bytes, step:Int, y:Int, offset:Int, width:Int, height:Int):Int
  {
    while (y < height)
    {
      output.blit(y * width, input, offset, width);
      offset += width;
      y += step;
    }
    return offset;
  }
  
  private function readExtension():Block
  {
    var subId:Int = i.readByte();
    
    switch(subId)
    {
      case 0xF9:
        // Graphics Control Extension
        if (i.readByte() != 4) throw "Incorrect Graphic Control Extension block size!";
        var packed:Int = i.readByte();
        var disposalMethod:DisposalMethod = switch ( (packed & 28) >> 2)
        {
          case 0: DisposalMethod.UNSPECIFIED;
          case 1: DisposalMethod.NO_ACTION;
          case 2: DisposalMethod.FILL_BACKGROUND;
          case 3: DisposalMethod.RENDER_PREVIOUS;
          default: DisposalMethod.UNDEFINED((packed & 28) >> 2);
        };
        var b:Block = Block.BExtension(Extension.EGraphicControl(
        {
          disposalMethod:disposalMethod,
          userInput: (packed & 2) == 2,
          hasTransparentColor: (packed & 1) == 1,
          delay: i.readUInt16(),
          transparentIndex: i.readByte()
        }));
        i.readByte(); // Terminator
        return b;
      case 0x01:
        // Text block
        // Exists only on paper, nobody ever used it.
        if (i.readByte() != 12) throw "Incorrect size of Plain Text Extension introducer block.";
        return Block.BExtension(Extension.EText(
        {
          textGridX: i.readUInt16(),
          textGridY: i.readUInt16(),
          textGridWidth: i.readUInt16(),
          textGridHeight: i.readUInt16(),
          charCellWidth: i.readByte(),
          charCellHeight: i.readByte(),
          textForegroundColorIndex: i.readByte(),
          textBackgroundColorIndex: i.readByte(),
          text: readBlocks().toString()
        }));
      case 0xFE:
        // Commentary
        return Block.BExtension(Extension.EComment(readBlocks().toString()));
      case 0xFF:
        // Application extension
        return readApplicationExtension();
      default:
        return Block.BExtension(Extension.EUnknown(subId, readBlocks()));
    }
  }
  
  private function readApplicationExtension():Block
  {
    if (i.readByte() != 11) throw "Incorrect size of Application Extension introducer block.";
    var name:String = i.readString(8);
    var version:String = i.readString(3);
    var data:Bytes = readBlocks();
    if (name == "NETSCAPE" && version == "2.0" && data.get(0) == 1)
    {
      return Block.BExtension(Extension.EApplicationExtension(ApplicationExtension.AENetscapeLooping(data.get(1) | (data.get(2) << 8))));
    }
    return Block.BExtension(Extension.EApplicationExtension(ApplicationExtension.AEUnknown(name, version, data)));
  }
  
  private inline function readBlocks():Bytes
  {
    var buffer:BytesOutput = new BytesOutput();
    var bytes:Bytes = Bytes.alloc(255);
    var len:Int = i.readByte();
    while (len != 0)
    {
      i.readBytes(bytes, 0, len);
      buffer.writeBytes(bytes, 0, len);
      len = i.readByte();
    }
    buffer.flush();
    bytes = buffer.getBytes();
    buffer.close();
    return bytes;
  }
  
  private function readColorTable(size:Int):ColorTable
  {
    size *= 3;
    var output:ColorTable = ColorTable.alloc(size);
    var c:Int = 0;
    while (c < size)
    {
      output.set(c    , i.readByte()); // R
      output.set(c + 1, i.readByte()); // G
      output.set(c + 2, i.readByte()); // B
      c += 3;
    }
    return output;
  }
}