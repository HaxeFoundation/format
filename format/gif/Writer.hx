package format.gif;
import format.gif.Data;
import haxe.ds.Vector;
import haxe.io.Bytes;
import haxe.io.Output;
import haxe.io.UInt8Array;

/**
 * ...
 * @author Yanrishatum
 */
class Writer
{
  
  private var o:Output;
  private var lzw:LZWEncoder;
  private var gctSize:Int;
  
  public function new(o:Output) 
  {
    this.o = o;
    this.lzw = new LZWEncoder();
    o.bigEndian = false;
  }
  
  /**
   * Write entire Data at once.
   * @param data Input gif file data
   */
  public function write(data:Data):Void
  {
    // Header
    writeHeader(data.version);
    
    // Logical screen descriptor.
    writeLogicalScreenDescriptor(data.logicalScreenDescriptor, data.globalColorTable);
    
    for (block in data.blocks)
    {
      switch (block)
      {
        case Block.BEOF:
          writeEOF();
          return;
        case Block.BExtension(ext):
          switch (ext)
          {
            case Extension.EUnknown(id, bytes):
              writeUnknownExtension(id, bytes);
            case Extension.EComment(text):
              writeComment(text);
            case Extension.EText(textExt):
              writeText(textExt);
            case Extension.EGraphicControl(gce):
              writeGraphicControl(gce);
            case Extension.EApplicationExtension(appExt):
              writeAppExtension(appExt);
          }
        case Block.BFrame(frame):
          writeFrame(frame);
      }
    }
    writeEOF(); // If we doesn't encountered EOF block - write it.
  }
  
  /**
   * Writes header of Gif file. Must be first.
   * @param version
   */
  public function writeHeader(version:Version):Void
  {
    o.writeString("GIF");
    switch(version)
    {
      case Version.GIF87a: o.writeString("87a");
      case Version.GIF89a: o.writeString("89a");
      case Version.Unknown(v):
        if (v.length == 3) o.writeString(v);
        else if (v.length > 3) o.writeString(v.substr(0, 3));
        else
        {
          while (v.length < 3) v += "-";
          o.writeString(v);
        }
    }
  }
  
  /**
   * Writes Logical Screen Descriptor block. Must go right after header.
   * @param lsd Logical Screen Descriptor object.
   * @param globalColorTable Global color table. Required only if LSD contains hasGlobalColorTable flag.
   * Color table must be a RGB-aligned Bytes with 3 bytes per color.
   */
  public function writeLogicalScreenDescriptor(lsd:LogicalScreenDescriptor, globalColorTable:Bytes = null):Void
  {
    o.writeUInt16(lsd.width);
    o.writeUInt16(lsd.height);
    
    var packed:Int = 0;
    if (lsd.hasGlobalColorTable) packed |= 128;
    packed |= (lsd.colorResolution << 4) & 112;
    if (lsd.sorted) packed |= 8;
    packed |= Math.round(Tools.log2(lsd.globalColorTableSize) - 1) & 7;
    o.writeByte(packed);
    
    o.writeByte(lsd.backgroundColorIndex);
    if (lsd.pixelAspectRatio == 1) o.writeByte(0);
    else o.writeByte(Std.int(lsd.pixelAspectRatio) * 64 - 15);
    
    if (lsd.hasGlobalColorTable)
    {
      if (globalColorTable != null)
      {
        o.writeBytes(globalColorTable, 0, globalColorTable.length);
        gctSize = lsd.globalColorTableSize;
      }
      else throw "hasGlobalColorTable flag present, but there is no global color table!";
    }
  }
  
  public function writeComment(text:String):Void
  {
    o.writeByte(0x21);
    o.writeByte(0xFE);
    writeStringBlocks(text);
  }
  
  public function writeText(textExt:PlainTextExtension):Void
  {
    o.writeByte(0x21);
    o.writeByte(0x01);
    o.writeByte(12);
    o.writeUInt16(textExt.textGridX);
    o.writeUInt16(textExt.textGridY);
    o.writeUInt16(textExt.textGridWidth);
    o.writeUInt16(textExt.textGridHeight);
    o.writeByte(textExt.charCellWidth);
    o.writeByte(textExt.charCellHeight);
    o.writeByte(textExt.textForegroundColorIndex);
    o.writeByte(textExt.textForegroundColorIndex);
    writeStringBlocks(textExt.text);
  }
  
  public function writeGraphicControl(gce:GraphicControlExtension):Void
  {
    o.writeByte(0x21);
    o.writeByte(0xF9);
    o.writeByte(4);
    var packed:Int = 0;
    
    switch (gce.disposalMethod)
    {
      case DisposalMethod.UNSPECIFIED: // 0
      case DisposalMethod.NO_ACTION: packed |= 4;
      case DisposalMethod.FILL_BACKGROUND: packed |= 8;
      case DisposalMethod.RENDER_PREVIOUS: packed |= 12;
      case DisposalMethod.UNDEFINED(idx): packed |= (idx & 7) << 2;
    }
    if (gce.userInput) packed |= 2;
    if (gce.hasTransparentColor) packed |= 1;
    
    o.writeByte(packed);
    o.writeUInt16(gce.delay);
    o.writeByte(gce.transparentIndex);
    o.writeByte(0); // Terminator
  }
  
  public function writeAppExtension(appExt:ApplicationExtension):Void
  {
    o.writeByte(0x21);
    o.writeByte(0xFF);
    o.writeByte(11);
    switch (appExt)
    {
      case ApplicationExtension.AENetscapeLooping(loops):
        o.writeString("NETSCAPE2.0");
        o.writeByte(3);
        o.writeByte(1); // Looping
        o.writeUInt16(loops);
        o.writeByte(0);
      case ApplicationExtension.AEUnknown(name, version, bytes):
        o.writeString(name);
        o.writeString(version);
        writeBlocks(bytes);
    }
  }
  
  public function writeUnknownExtension(id:Int, bytes:Bytes):Void
  {
    o.writeByte(0x21);
    o.writeByte(id);
    writeBlocks(bytes);
  }
  
  public function writeFrame(frame:Frame):Void
  {
    
    o.writeByte(0x2C);
    o.writeUInt16(frame.x);
    o.writeUInt16(frame.y);
    o.writeUInt16(frame.width);
    o.writeUInt16(frame.height);
    
    var packed:Int = 0;
    if (frame.localColorTable) packed |= 128;
    if (frame.interlaced) packed |= 64;
    if (frame.sorted) packed |= 32;
    packed |= Math.round(Tools.log2(frame.localColorTableSize) - 1) & 7;
    o.writeByte(packed);
    if (frame.localColorTable)
    {
      if (frame.colorTable != null) o.writeBytes(frame.colorTable, 0, frame.colorTable.length);
      else throw "localColorTable flag is set, but there is no local color table!";
    }
    
    lzw.encode(frame.width, frame.height, frame.pixels, frame.localColorTable ? frame.localColorTableSize : gctSize, o, frame.interlaced);
  }
  
  /**
   * Writes EndOfFile block.
   */
  public function writeEOF():Void
  {
    o.writeByte(0x3B);
  }
  
  private  function writeStringBlocks(text:String):Void
  {
    var len:Int;
    var caret:Int = 0;
    while (caret < text.length)
    {
      len = text.length - caret;
      if (len > 0xFF) len = 0xFF;
      o.writeByte(len);
      for (i in 0...len) o.writeByte(text.charCodeAt(i + caret));
      caret += len;
    }
    o.writeByte(0);
  }
  
  private function writeBlocks(bytes:Bytes):Void
  {
    var len:Int;
    var caret:Int = 0;
    while (caret < bytes.length)
    {
      len = bytes.length - caret;
      if (len > 0xFF) len = 0xFF;
      o.writeByte(len);
      o.writeBytes(bytes, caret, len);
      caret += 0xFF;
    }
    o.writeByte(0); // Terminator
  }
  
}


class LZWEncoder
{
  private var EOF:Int = -1;
  private static inline var BITS:Int = 12;
  private static inline var HSIZE:Int = 5003;
  private var masks:Array<Int> = [0x0000, 0x0001, 0x0003, 0x0007, 0x000F, 0x001F,
                                  0x003F, 0x007F, 0x00FF, 0x01FF, 0x03FF, 0x07FF,
                                  0x0FFF, 0x1FFF, 0x3FFF, 0x7FFF, 0xFFFF];
  
  private var out:Output;
  private var bits:Int;
  private var bitsCount:Int;
  
  private var minCodeSize:Int;
  private var codeSize:Int;
  private var codeSizeLimit:Int;
  private var clearFlag:Bool;
  
  private var clearCode:Int;
  private var eofCode:Int;
  
  // Dict
  private var htab:Vector<Int>;
  private var codetab:Vector<Int>;
  private var freeEnt:Int;
  
  // Block buffer
  private var blockBuffer:Bytes;
  private var blockBufferCaret:Int;
  
  // Input data
  private var pixels:Bytes;
  private var width:Int;
  private var height:Int;
  private var remaining:Int;
  
  // Non-interlaced
  private var pixelsCaret:Int;
  // Interlaced
  private var interlaced:Bool;
  private var pixelsX:Int;
  private var pixelsY:Int;
  private var interlacingStage:Int;
  private var interlacingStep:Int;
  
  public function new()
  {
    blockBuffer = Bytes.alloc(256);
  }
  
  public function encode(width:Int, height:Int, pixels:Bytes, colorsCount:Int, out:Output, interlaced:Bool):Void
  {
    minCodeSize = Math.round(Tools.log2(colorsCount));
    
    this.pixels = pixels;
    this.width = width;
    this.height = height;
    this.out = out;
    
    htab = new Vector(HSIZE);
    codetab = new Vector(HSIZE);
    
    blockBufferCaret = 0;
    bits = 0;
    bitsCount = 0;
    
    clearCode = 1 << minCodeSize;
    eofCode = clearCode + 1;
    freeEnt = clearCode + 2;
    
    out.writeByte(minCodeSize);
    remaining = width * height;
    
    this.interlaced = interlaced;
    if (interlaced)
    {
      pixelsX = 0;
      pixelsY = 0;
      interlacingStage = 0;
      interlacingStep = 8;
    }
    else pixelsCaret = 0;
    
    compress();
    out.writeByte(0);
  }
  
  private function char_out(c:Int):Void
  {
    blockBuffer.set(blockBufferCaret++, c);
    if (blockBufferCaret >= 254) flush_char();
  }
  
  private function cl_block():Void
  {
    cl_hash(HSIZE);
    freeEnt = clearCode + 2;
    clearFlag = true;
    output(clearCode);
  }
  
  private function cl_hash(hsize:Int):Void
  {
    for (i in 0...hsize) htab[i] = -1;
  }
  
  private function compress():Void
  {
    var disp:Int;
    var i:Int;
    
    clearFlag = false;
    codeSize = minCodeSize + 1;
    codeSizeLimit = MAXCODE(codeSize);

    var ent:Int = nextPixel();
    
    var hshift:Int = 0;
    var fcode:Int = HSIZE;
    while (fcode < 65536)
    {
      ++hshift;
      fcode *= 2;
    }
    hshift = 8 - hshift;
    var hsize_reg:Int = HSIZE;
    cl_hash(hsize_reg);
    
    output(clearCode);
    
    var c:Int;
    while ((c = nextPixel()) != EOF)
    {
      fcode = (c << BITS) + ent;
      i = (c << hshift) ^ ent;
      if (htab[i] == fcode)
      {
        ent = codetab[i];
        continue;
      }
      else if (htab[i] >= 0)
      {
        disp = hsize_reg - i;
        if (i == 0) disp = 1;
        var skip:Bool = false;
        do
        {
          if ((i -= disp) < 0) i += hsize_reg;
          if (htab[i] == fcode)
          {
            ent = codetab[i];
            skip = true;
            break;
          }
        }
        while (htab[i] >= 0);
        if (skip) continue;
      }
      
      output(ent);
      ent = c;
      if (freeEnt < (1 << BITS))
      {
        codetab[i] = freeEnt++;
        htab[i] = fcode;
      }
      else
      {
        cl_block();
      }
    }
    
    output(ent);
    output(eofCode);
  }
  
  private function flush_char():Void
  {
    if (blockBufferCaret > 0)
    {
      out.writeByte(blockBufferCaret);
      out.writeBytes(blockBuffer, 0, blockBufferCaret);
      blockBufferCaret = 0;
    }
  }
  
  private inline function MAXCODE(n_bits:Int):Int
  {
    return (1 << n_bits) - 1;
  }
  
  private function nextPixel():Int
  {
    if (remaining == 0) return EOF;
    remaining--;
    if (interlaced)
    {
      if (++pixelsX == width)
      {
        pixelsX = 0;
        pixelsY += interlacingStep;
        if (pixelsY >= height)
        {
          switch (interlacingStage)
          {
                                               // first: Every 8 line with start at 0
            case 0: pixelsY = 4;                      // Every 8 line with start at 4
            case 1: pixelsY = 2; interlacingStep = 4; // Every 4 line with start at 2
            case 2: pixelsY = 1; interlacingStep = 2; // Every 2 line with start at 1
            default: return -1; // EOF
          }
          interlacingStage++;
        }
      }
      return pixels.get(pixelsY * width + pixelsX);
    }
    else
    {
      return pixels.get(pixelsCaret++);
    }
  }
  
  private function output(code:Int):Void
  {
    bits &= masks[bitsCount];
    
    if (bitsCount > 0) bits |= (code << bitsCount);
    else bits = code;
    
    bitsCount += codeSize;
    
    while (bitsCount >= 8)
    {
      char_out(bits & 0xFF);
      bits >>= 8;
      bitsCount -= 8;
    }
    
    if (freeEnt > codeSizeLimit || clearFlag)
    {
      if (clearFlag)
      {
        codeSizeLimit = MAXCODE(codeSize = minCodeSize + 1);
        clearFlag = false;
      }
      else
      {
        codeSize++;
        if (codeSize == BITS) codeSizeLimit = 1 << BITS;
        else codeSizeLimit = MAXCODE(codeSize);
      }
    }
    
    if (code == eofCode)
    {
      while (bitsCount > 0)
      {
        char_out(bits & 0xFF);
        bits >>= 8;
        bitsCount -= 8;
      }
      flush_char();
    }
  }
  
}
