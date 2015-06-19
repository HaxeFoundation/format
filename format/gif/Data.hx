package format.gif;

import haxe.io.Bytes;

/**
 * Gif data.
 */
typedef Data =
{
  /**
   * Gif version. There is only 2 Gif version exists. 87a and 89a.
   * 87a have less features and does not support any extensions.
   * Unknown version is adviced to be interpreted as newest (89a) official version.
   */
  var version:Version;
  /**
   * Information about logical screen of Gif that provides basic information about Gif.
   */
  var logicalScreenDescriptor:LogicalScreenDescriptor;
  /**
   * Global color table used for Gif. Present only if Logical Screen Descriptor contained global color table flag.
   * Note that this color table not always present since frames can contain local color tables that overrides global color table.
   */
  @:optional var globalColorTable:Null<ColorTable>;
  /**
   * List of Gif data blocks.
   */
  var blocks:List<Block>;
}

/**
 * Gif data block. Custom blocks are not supported.
 */
enum Block
{
  /**
   * Gif frame block.
   * Note that this block does not contain link to graphic control extension of Frame even if it is present. GraphicControl extension Block commonly present right before frame Block.
   */
  BFrame(frame:Frame);
  /**
   * Additional extension block. This Block does not supported in 87a Gif specification version.
   */
  BExtension(extension:Extension);
  /**
   * End of File block. Represents end of Gif data.
   */
  BEOF;
}

/**
 * Extension block contains additional data about Gif image. This block does not supported by 87a version.
 */
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
   * Application extension allow to insert additional application data into Gif. Mostly used app extension is NETSCAPE2.0 looping extension, used to set up amount of loops in frame.
   */
  EApplicationExtension(ext:ApplicationExtension);
  
  /**
   * Unknown extension. 
   */
  EUnknown(id:Int, data:Bytes);
}

/**
 * Application extension. Mostly used only for one reason - setting up loops count. There is exist other app extensions but they are really rare.
 */
enum ApplicationExtension
{
  /**
   * NETSCAPE2.0 looping extension. Contains only amount of animation repeats.
   * Note that there is two NETSCAPE2.0 app extensions for Gif format and the type of extension is stored in first byte of data. Looping extension have ID 1.
   */
  AENetscapeLooping(loops:Int);
  /**
   * Unknown or unsupported app extension.
   */
  AEUnknown(name:String, version:String, data:Bytes);
}

/**
 * Typical color table for Gif image.
 * Can contain 2, 4, 8, 16, 32, 64, 128 or 256 colors.
 * Data stored in RGB format. Information about alpha channel provided by Graohic Control Extension.
 */
typedef ColorTable = Bytes;

/**
 * Single frame of the image.
 * Actually it's a merge of 3 consequent blocks:
 * 1. Image Descriptor.
 * Contains frame informations like position, size, existing of local color table and interlaced flag.
 * 2. [Local color table].
 * Only present if Image Descriptor contains local color table flag. Overrides global color table.
 * 3. Pixel data blocks.
 * LZW compressed pixel data.
 */
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
   * Note: The pixel data already deinterlaced and this flag presented only for information purpose (and for Writer when there is one).
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
   * This flag may be used by user-defined program but absolutely ignored by any Gif players.
   */
  var userInput:Bool;
  /**
   * Is image have transparency?
   */
  var hasTransparentColor:Bool;
  /**
   * Delay, before next image appears. Delay is in centiseconds (1 centisecond = 1/100 seconds).
   * Note: Some players (like FastStone) cut fraction of elapsed time when progressing to next frame which results in small timing error.
   * Recommended to use `time -= delay` instead of `time = 0`.
   */
  var delay:Int;
  /**
   * Index in color table that used as transparent.
   */
  var transparentIndex:Int;
}

/**
 * Extension for rendering text on Gif logical screen. It does not supported by major Gif decoders.
 * Font and text size decision is left to decoder. (recommended to decide based on grid/cell size)
 * Text must be rendered with one character at cell.
 * It's recommended to replace any characters less than 0x20 and greater than 0xf7 to be rendered as Space (0x20)
 */
typedef PlainTextExtension =
{
  /**
   * X position of text grid on Logical Screen.
   */
  var textGridX:Int;
  /**
   * Y position of text grid on Logical Screen.
   */
  var textGridY:Int;
  /**
   * Width of text grid in pixels.
   */
  var textGridWidth:Int;
  /**
   * Height of text grid in pixels.
   */
  var textGridHeight:Int;
  /**
   * Width of character cell in text grid.
   */
  var charCellWidth:Int;
  /**
   * Height of character cell in text grid.
   */
  var charCellHeight:Int;
  /**
   * Foreground/character color index.
   */
  var textForegroundColorIndex:Int;
  /**
   * Background color index.
   */
  var textBackgroundColorIndex:Int;
  /**
   * Text to render.
   */
  var text:String;
}

/**
 * Logical screen descriptor of GIF file.
 * Contains very basic information about Gif.
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
   * First version of Gif file format from May 1987.
   * 
   * Note: The checking of unsupported blocks disabled by default to save some time. To enable supported blocks check set `yagp_strict_version_check` debug variable.
   */
  GIF87a;
  /**
   * Second and actual version of Gif file format from July 1989.
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