package format.gif;

import haxe.io.Bytes;

/**
 * ...
 * @author Yanrishatum
 */

typedef Data =
{
  var version:Version;
  var logicalScreenDescriptor:LogicalScreenDescriptor;
  @:optional var globalColorTable:Null<ColorTable>;
  var blocks:List<Block>;
}

enum Block
{
  /**
   * Gif frame block.
   */
  BFrame(frame:Frame);
  /**
   * Additional extension block.
   */
  BExtension(extension:Extension);
  /**
   * End of File block.
   */
  BEOF;
}

enum Extension
{
  /**
   * Graphic Control extension gives additional control over next frame, like frame delay, disposal method, alpha channel and other information.
   */
  EGraphicControl(gce:GraphicControlExtension);
  /**
   * Commentary extension. Not show up as any visual, just a text in file.
   */
  EComment(text:String);
  /**
   * Text extension. Must work as text rendering on the image, but ignored by all major Gif decoders.
   */
  EText(pte:PlainTextExtension);
  /**
   * Application extension allow to insert additional application data into Gif. Most used app extension is NETSCAPE2.0 looping extension, used to set up amount of loops in frame.
   */
  EApplicationExtension(ext:ApplicationExtension);
  
  /**
   * Unknown extension. 
   */
  EUnknown(id:Int, data:Bytes);
}

enum ApplicationExtension
{
  AENetscapeLooping(loops:Int);
  AEUnknown(name:String, version:String, data:Bytes);
}

/**
 * Typical color table for Gif image.
 * Can contain 2, 4, 8, 16, 32, 64, 128 or 256 colors.
 * Data stored in RGB format. Information about alpha channel provided by Graohic Control Extension.
 */
typedef ColorTable = Bytes;

typedef Frame =
{
  /**
   * X position of image on the Logical Screen
   */
  var x:Int;
  
  /**
   * Y position of image on the Logical Screen
   */
  var y:Int;
  
  /**
   * Width of image in pixels
   */
  var width:Int;
  
  /**
   * Height of image in pixels
   */
  var height:Int;
  
  /**
   * Is this image uses local color table?
   */
  var localColorTable:Bool;
  
  /**
   * Is this image written in interlace mode?
   */
  var interlaced:Bool;
  
  /**
   * Is local color table sorted in order of decreasing priority?
   */
  var sorted:Bool;
  
  /**
   * Size of local color table
   */
  var localColorTableSize:Int;
  
  /**
   * Pixel data of frame. Stored as Indexed colors, 1 byte per pixel.
   */
  var pixels:Bytes;
  
  /**
   * Local color table used by frame. Stored as 3-byte RGB colors. If value is null, must be used global color table.
   */
  var colorTable:ColorTable;
}

/**
 * Graphic Control Extension block, used for setting up disposal method, transparency, delay and user input.
 */
typedef GraphicControlExtension =
{
  /**
   * Disposal method of frame.
   */
  var disposalMethod:DisposalMethod;
  /**
   * Is image must wait for user input, before dispose?
   * This flag may be used by user-defined program.
   */
  var userInput:Bool;
  /**
   * Is image have transparency?
   */
  var hasTransparentColor:Bool;
  /**
   * Delay, before next image appears. Delay is in centiseconds (1 centisecond = 1/100 seconds).
   */
  var delay:Int;
  /**
   * Index in color table that used as transparent.
   */
  var transparentIndex:Int;
}

typedef PlainTextExtension =
{
  var textGridX:Int;
  var textGridY:Int;
  var textGridWidth:Int;
  var textGridHeight:Int;
  var charCellWidth:Int;
  var charCellHeight:Int;
  var textForegroundColorIndex:Int;
  var textBackgroundColorIndex:Int;
  var text:String;
}

/**
 * Logical screen descriptor of GIF file.
 */
typedef LogicalScreenDescriptor =
{
  /**
   * Width of GIF image in pixels
   */
  var width:Int;
  
  /**
   * Height of GIF image in pixels
   */
  var height:Int;
  
  /**
   * Is this file uses global color table?
   */
  var hasGlobalColorTable:Bool;
  
  /**
   * Specification:
   * Number of bits per primary color available
     to the original image, minus 1. This value represents the size of
     the entire palette from which the colors in the graphic were
     selected, not the number of colors actually used in the graphic.
     For example, if the value in this field is 3, then the palette of
     the original image had 4 bits per primary color available to create
     the image.  This value should be set to indicate the richness of
     the original palette, even if not every color from the whole
     palette is available on the source machine.
   */
  var colorResolution:Int;
  
  /**
   * Specification:
   * Indicates whether the Global Color Table is sorted.
     If the flag is set, the Global Color Table is sorted, in order of
     decreasing importance. Typically, the order would be decreasing
     frequency, with most frequent color first. This assists a decoder,
     with fewer available colors, in choosing the best subset of colors;
     the decoder may use an initial segment of the table to render the
     graphic.
   */
  var sorted:Bool;
  
  /**
   * Size of global color table.
   */
  var globalColorTableSize:Int;
  
  /**
   * Background color index in global color table
   */
  var backgroundColorIndex:Int;
  
  /**
   * Factor used to compute an approximation of the aspect ratio of the pixel in the original image.
   */
  var pixelAspectRatio:Float;
}

/**
 * Version of Gif file.  
 * The only 2 official versions is GIF87a and GIF89a.
 */
enum Version
{
  /**
   * First version of Gif file format from year 1987.
   * 
   * Note: The checking of unsupported blocks disabled by default to save some time. To enable supported blocks check set `yagp_strict_version_check` debug variable.
   */
  GIF87a;
  /**
   * Second and actual version of Gif file format from year 1989.
   */
  GIF89a;
  /**
   * Unknown version of Gif file.
   */
  Unknown(version:String);
}

/**
 * Disposal method of GIF frame.
 */
enum DisposalMethod
{
  /**
   * The disposal method is unspecified. Action on demand of viewer.
   * 
   * Mostly interpreted as NO_ACTION.
   */
  UNSPECIFIED;
  /**
   * No action required. 
   */
  NO_ACTION;
  /**
   * Fill frame rectangle with background color.
   * 
   * Usage note: 
   * Most renderers clears to transparency instead of filling background color, when frame's transparent color index not equals to background color index.
   */
  FILL_BACKGROUND;
  /**
   * Render previous state of gif as it before rendering disposing frame.
   */
  RENDER_PREVIOUS;
  /**
   * Reserved disposal methods.
   */
  UNDEFINED(index:Int);
}