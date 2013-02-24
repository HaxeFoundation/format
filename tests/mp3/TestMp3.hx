import format.mp3.Data;
import format.mp3.Tools;

class TestMp3 {

	static function main() {
      var fn = Sys.args()[0];
      Sys.print("trying to open '" + fn + "'\n");
		var f = sys.io.File.read(fn, true);
      var r = new format.mp3.Reader(f);
      var mp3 = r.read();
      
      Sys.print("#valid frames: " + mp3.frames.length + "\n");

      var data_size = 0;
      var samples = 0;
      
      var i = 0;
      var nframes = mp3.frames.length;
      var nframes2 = Std.int(nframes / 2);
      for (f in mp3.frames) {
         data_size += Tools.getSampleDataSizeHdr(f.header) + 4;
         samples += Tools.getSampleCountHdr(f.header);

         if (i < 5 || i > nframes-5)
            Sys.print(Tools.getFrameInfo(f) + "\n");

         if (nframes > 25) {
            if (i > nframes2 && i < nframes2 + 5)
               Sys.print(Tools.getFrameInfo(f) + "\n");   

            if (i == nframes2 + 5) {
               Sys.print("...\n");
            }
         }

         if (i == 5)
            Sys.print("...\n");

         i++;
      }
      
      Sys.print("valid frames total length (with hdr): " + data_size + "\n");
      Sys.print("valid frames total #samples: " + samples + "\n");

      if (mp3.id3v2 != null) {
         Sys.print("found id3v2 tag, version bytes: " + mp3.id3v2.versionBytes + "\n");
      }

      // write back
      Sys.print("writing back to __" + fn + "\n");
      var fo = sys.io.File.write("__" + fn, true);
      var w = new format.mp3.Writer(fo);
      w.write(mp3);
      fo.close();

	}

}
