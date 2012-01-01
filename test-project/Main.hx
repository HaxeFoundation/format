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
			
			out = x * mproj;
			color = pos.xyz;
		}
		
		function fade( t : Float3 ) : Float3 
		{
			return (t * (t * 6 - 15) + 10);
		}
		
		function fragment() {
			out = fade(color).xyzz;
		}
	};

}