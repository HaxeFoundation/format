package ;
import js.Lib;

/**
 * ...
 * @author Waneck
 */

class Main 
{

	public function new() 
	{
		
	}
	
	
	public static function main()
	{
		var s = new Shader(null);
		var shaders = untyped Lib.window.shaders = {};
		Reflect.setField(shaders,"shader-fs", {
			type:"fragment",
			text:s.getFragmentData()
		});
		
		Reflect.setField(shaders, "shader-vs", {
			type:"vertex",
			text:s.getVertexData()
		});
		
		untyped webGLStart();
	}
}

class Shader extends format.glsl.Shader {

	static var SRC = {
		var input : {
			pos : Float3,
		};
		var color : Float3;
		function vertex( mpos : M44, mproj : M44 ) {
			var x = pos.xyzw * mpos;
			var y = x;
			var x = y;
			
			var pos = doFunc((pos.xzxy).xyzw);
			var pos = [pos.length(), pos.length(), pos.length()];
			pos.x = if (pos.x > 1.0) 0.0; else 1.0;
			var pos = [pos.x, pos.y, pos.z, 1.0];
			//var pos = [0.0, 0.0, 0.0, 1.0];
			
			out = x * mproj;
			color = pos.xyz;
		}
		
		function doFunc(pos:Float4)
		{
			return (pos * 2 / 2).rcp().sqrt().neg().neg().rsqrt();
		}
		
		function fragment() {
			out = color.xyzw;
		}
	};

}