import haxe.io.Bytes;
import sys.io.File;
import sys.io.FileInput;
import sys.io.FileOutput;
class Test {

	static function main() {
    Sys.setCwd("samples");
    // Simple B&W mode
    Sys.println("Testing Black-and-white, [ubw8.tga, cbw8.tga]");
    Sys.println(compare(["ubw8.tga", "cbw8.tga"], "bw.png", false));
    
    // Trickier, this one had another origin
    Sys.println("Testing Black-and-white with bottom-left origin, [monochrome8_bottom_left.tga, monochrome8_bottom_left_rle.tga]");
    Sys.println(compare(["monochrome8_bottom_left.tga", "monochrome8_bottom_left_rle.tga"], "monochrome8.png", false));
    
    // B&W + alpha channel included into data.
    Sys.println("Testing B&W with alpha channel, [monochrome16_top_left.tga, monochrome16_top_left_rle.tga]");
    Sys.println(compare(["monochrome16_top_left.tga", "monochrome16_top_left_rle.tga"], "monochrome16.png", true));
    
    // Simple truecolor
    Sys.println("Testing TrueColor, [utc16.tga, utc24.tga, utc32.tga, ctc16.tga, ctc24.tga, ctc32.tga]");
    Sys.println(compare(["utc16.tga", "utc24.tga", "utc32.tga", "ctc16.tga", "ctc24.tga", "ctc32.tga"], "color.png", false));
    // Simple colormap
    Sys.println("Testing ColorMap, [ucm8.tga, ccm8.tga]");
    Sys.println(compare(["ucm8.tga", "ccm8.tga"], "color.png", false));
    
    // RGB is bascally same as lines
    Sys.println("Testing RGB text TrueColor image [rgb24_bottom_left_rle.tga, rgb24_top_left.tga]");
    Sys.println(compare(["rgb24_bottom_left_rle.tga", "rgb24_top_left.tga"], "rgb24.0.png", false));
    // Don't ask me, why they are different in output, I don't know.
    Sys.println("Testing RGB text ColorMap image [rgb24_top_left_colormap.tga]");
    Sys.println(compare(["rgb24_top_left_colormap.tga"], "rgb24.1.png", false));
    
    // 32bpp with alpha channel + another origin
    Sys.println("Testing RGB text TrueColor w/ alpha [rgb32_bottom_left.tga, rgb32_top_left_rle.tga]");
    Sys.println(compare(["rgb32_bottom_left.tga", "rgb32_top_left_rle.tga"], "rgb32.0.png", true));
    Sys.println("Testing RGB text ColorMap w/ alpha [rgb32_top_left_rle_colormap.tga]");
    Sys.println(compare(["rgb32_top_left_rle_colormap.tga"], "rgb32.1.png", true));
	}
  
  private static function compare(tga:Array<String>, reference:String, compareAlpha:Bool):Array<Bool>
  {
    var i:FileInput = File.read(reference);
    var refPixels = format.png.Tools.extract32(new format.png.Reader(i).read());
    i.close();
    
    var results:Array<Bool> = new Array();
    
    for (file in tga)
    {
      i = File.read(file);
      var tgaData = new format.tga.Reader(i).read();
      i.close();
      var pixels:Bytes = format.tga.Tools.extract32(tgaData, compareAlpha);
      var diff:Int = pixels.compare(refPixels);
      results.push(diff == 0);
      if (diff != 0)
      {
        var out:FileOutput = File.write(file + ".png");
        new format.png.Writer(out).write(format.png.Tools.build32BGRA(tgaData.header.width, tgaData.header.height, pixels));
        out.close();
        trace(tgaData.header);
        trace(diff);
      }
    }
    return results;
  }
  
}