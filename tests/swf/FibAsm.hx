import format.swf.Data;
import format.abc.Data;

class FibAsm {

	static function time( text : String, f : Void -> Dynamic, ?pos : haxe.PosInfos ) {
		var t = haxe.Timer.stamp();
		var ret = f();
		var dt = haxe.Timer.stamp() - t;
		haxe.Log.trace(text+" = "+Std.string(ret)+" in "+dt+" sec",pos);
		return dt;
	}

	function new() {
	}

	function fib( x : Int ) {
		if( x <= 1 ) return 1;
		return fib(x-1) + fib(x-2);
	}

	static function main() {
		var swf = build();
		#if neko
		var f = neko.io.File.write("fib.swf",true);
		f.write(swf);
		f.close();
		#else
		// load locally
		var l = new flash.display.Loader();
		l.contentLoaderInfo.addEventListener(flash.events.Event.COMPLETE,function(e) {
			var m = l.contentLoaderInfo.applicationDomain.getDefinition("Main");
			var inst : Dynamic = Type.createInstance(m,[]);
			var n = 34;
			var t1 = time("ASM Fib("+n+")",function() { return inst.fib(n); });
			var t2 = time("Normal Fib("+n+")",function() { return new FibAsm().fib(n); });
			trace("Speedup = +"+Std.int(((t2/t1) - 1)*100)+"%");
		});
		l.loadBytes(swf.getData());
		#end
	}

	static function build() {
		var ctx = new format.abc.Context();
		ctx.beginClass("Main");
		var tint = ctx.type("int");
		var m = ctx.beginMethod("fib",[tint],tint);
		m.maxStack = 3;
		ctx.ops([
			OReg(1),
			OSmallInt(1),
		]);
		var j = ctx.jump(JGt);
		ctx.ops([
			OInt(1),
			ORet,
		]);
		j();
		ctx.ops([
			ODecrIReg(1),
			OThis,
			OReg(1),
			OCallProperty(ctx.property("fib"),1),
			ODecrIReg(1),
			OThis,
			OReg(1),
			OCallProperty(ctx.property("fib"),1),
			OOp(OpIAdd),
			ORet,
		]);
		ctx.finalize();
		var o = new haxe.io.BytesOutput();
		format.abc.Writer.write(o,ctx.getData());
		var abc = o.getBytes();
		var header : SWFHeader = {
			version : 9,
			width : 400,
			height : 300,
			nframes : 1,
			fps : format.swf.Tools.toFixed8(30.0),
			compressed : false,
		};
		var tags = [
			TSandBox(25),
			TActionScript3(abc),
			TShowFrame,
		];
		o = new haxe.io.BytesOutput();
		new format.swf.Writer(o).write({ header : header, tags : tags });
		return o.getBytes();
	}

}