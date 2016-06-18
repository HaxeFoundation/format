package format.tga;
import haxe.ds.Vector;

typedef Header =
{
  /**
   * Indicated type of color map.
   * 0 = no color map present.
   * 1 = color map included.
   * 2-127 is reserved by Truevision
   * 128-255 may be used by app developers.
   */
  var colorMapType:Int;
  /** Image data type. */
  var imageType:ImageType;
  // Color map specification
  /**
   * Index of the first color map entry. Index refers to the starting entry in
   * loading the color map.
   */
  var colorMapFirstIndex:Int;
  /** Total number of color map entries included. */
  var colorMapLength:Int;
  /**
   * Establishes the number of bits per entry. Typically 15, 16, 24 or 32-bit
   * values are used.
   */
  var colorMapEntrySize:Int;
  
  // Image specification
  /**
   * These bytes specify the absolute horizontal coordinate for the lower left
   * corner of the image as it is positioned on a display device having an
   * origin at the lower left of the screen (e.g., the TARGA series).
   */
  var xOrigin:Int;
  /**
   * These bytes specify the absolute vertical coordinate for the lower left
   * corner of the image as it is positioned on a display device having an
   * origin at the lower left of the screen (e.g., the TARGA series).
   */
  var yOrigin:Int;
  /** This field specifies the width of the image in pixels. */
  var width:Int;
  /** This field specifies the height of the image in pixels. */
  var height:Int;
  /**
   * This field indicates the number of bits per pixel. This number includes
   * the Attribute or Alpha channel bits. Common values are 8, 16, 24 and
   * 32 but other pixel depths could be used.
   */
  var bitsPerPixel:Int;
  /**
   * the number of attribute bits per
   * pixel. In the case of the TrueVista, these bits
   * indicate the number of bits per pixel which are
   * designated as Alpha Channel bits. For the ICB
   * and TARGA products, these bits indicate the
   * number of overlay bits available per pixel.
   */
  var alphaChannelBits:Int;
  var imageOrigin:ImageOrigin;
  
  /*
   * There is probably additional flag adding interlaced encoding?
   * 
   * Bits 7-6 - Data storage interleaving flag. 
   * 00 = non-interleaved.
   * 01 = two-way (even/odd) interleaving.
   * 10 = four way interleaving.
   * 11 = reserved.
   */
}

enum ImageOrigin
{
  BottomLeft;
  BottomRight;
  TopLeft;
  TopRight;
}

enum ImageType
{
  /** There is no image data present */
  NoImage;                   // 0
  /** Uncompressed image with color-map usage */
  UncompressedColorMapped;   // 1
  /** True-color uncompressed image */
  UncompressedTrueColor;     // 2
  /** Black-and-White uncompresed image */
  UncompressedBlackAndWhite; // 3
  /** Run-length encoded image with color-map usage */
  RunLengthColorMapped;      // 9
  /** Run-length encoded true-color image */
  RunLengthTrueColor;        // 10
  /** Run-length encoded black-and-white image */
  RunLengthBlackAndWhite;    // 11
  /** Unknown type */
  Unknown(type:Int);
  
  /*
   * Found also:
   * 32  -  Compressed color-mapped data, using Huffman, Delta, and
   *        runlength encoding.
   * 33  -  Compressed color-mapped data, using Huffman, Delta, and
   *        runlength encoding.  4-pass quadtree-type process. 
   * */
}

typedef Data =
{
  var header:Header;
  var imageId:String;
  var colorMapData:Vector<Int>;
  var imageData:Vector<Int>;
  var developerData:Dynamic; // Not supported ATM
};