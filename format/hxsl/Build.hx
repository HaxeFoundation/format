/*
 * format - haXe File Formats
 *
 * Copyright (c) 2008, The haXe Project Contributors
 * All rights reserved.
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 *   - Redistributions of source code must retain the above copyright
 *     notice, this list of conditions and the following disclaimer.
 *   - Redistributions in binary form must reproduce the above copyright
 *     notice, this list of conditions and the following disclaimer in the
 *     documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE HAXE PROJECT CONTRIBUTORS "AS IS" AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE HAXE PROJECT CONTRIBUTORS BE LIABLE FOR
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 * CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH
 * DAMAGE.
 */
package format.hxsl;

#if macro
import haxe.macro.Expr;
import haxe.macro.Context;
import format.agal.Data.RegType;
import format.hxsl.Data;
#end

class Build {

	#if macro
	static function realType( t : VarType ) {
		return switch( t ) {
		case TFloat: "Float";
		case TFloat2, TFloat3, TFloat4: "flash.Vector<Float>";
		case TMatrix44(_): "flash.geom.Matrix3D";
		case TTexture: "flash.display3D.textures.Texture";
		};
	}

	static function buildShaderInfos( shader : Code ) {
		var inf = {
			vars : [],
			setup : [],
			tmp : [],
		};
		if( shader.vertex )
			inf.tmp.push("start(true);");
		else
			inf.tmp.push("start(false);");
		for( c in shader.args.concat(shader.tex) ) {
			var t = realType(c.type);
			inf.vars.push(c.name + " : " + t);
			var n = (shader.vertex?"vertex":"fragment") + "." + c.name;
			switch( c.type ) {
			case TFloat:
				inf.setup.push(n);
				inf.setup.push(n);
				inf.setup.push(n);
				inf.setup.push(n);
			case TFloat2:
				inf.setup.push(n + "[0]");
				inf.setup.push(n + "[1]");
				inf.setup.push("0");
				inf.setup.push("0");
			case TFloat3:
				inf.setup.push(n + "[0]");
				inf.setup.push(n + "[1]");
				inf.setup.push(n + "[2]");
				inf.setup.push("0");
			case TFloat4:
				inf.setup.push(n + "[0]");
				inf.setup.push(n + "[1]");
				inf.setup.push(n + "[2]");
				inf.setup.push(n + "[3]");
			case TMatrix44(t):
				var tmp = "raw_" + c.name;
				inf.tmp.push("var " + tmp + " = " + n + ".rawData;");
				if( t.t )
					// transpose
					for( i in [0,4,8,12,1,5,9,13,2,6,10,14,3,7,11,15] )
						inf.setup.push(tmp + "[" + i + "]");
				else
					for( i in 0...16 )
						inf.setup.push(tmp + "[" + i + "]");
			case TTexture:
				inf.tmp.push("texture(" + c.index + "," + n + ");");
			}
		}
		for( c in shader.consts ) {
			for( f in c.vals )
				inf.setup.push(f);
			for( i in c.vals.length...4 )
				inf.setup.push("0");
		}

		if( inf.setup.length >> 2 >= format.agal.Tools.getProps(RConst, !shader.vertex).count )
			Context.error("This shader has reached the maximum number of allowed parameters/constants", shader.pos);

		return inf;
	}
	#end

	@:macro public static function shader() {
		var cl = Context.getLocalClass().get();
		var shader = null;
		for( m in cl.meta.get() )
			if( m.name == ":shader" ) {
				if( m.params.length != 1 )
					Context.error("@:shader metadata should only have one parameter", m.pos);
				shader = m.params[0];
				break;
			}
		if( shader == null )
			Context.error("Missing @:shader metadata", cl.pos);

		var p = new Parser();
		p.warn = Context.warning;
		var v = try p.parse(shader) catch( e : Parser.ParserError ) haxe.macro.Context.error(e.message, e.pos);
		var c = new format.agal.Compiler();
		c.error = Context.error;

		var vscode = c.compile(v.vs);
		var fscode = c.compile(v.fs);

		var o = new haxe.io.BytesOutput();
		new format.agal.Writer(o).write(vscode);
		var vsbytes = haxe.Serializer.run(o.getBytes());

		var o = new haxe.io.BytesOutput();
		new format.agal.Writer(o).write(fscode);
		var fsbytes = haxe.Serializer.run(o.getBytes());

		var vs = buildShaderInfos(v.vs);
		var fs = buildShaderInfos(v.fs);

		var initCode =
			vs.tmp.concat(Lambda.array(Lambda.map(vs.setup, function(s) return "add(" + s + ");"))).join("\n") + "\n\n" +
			fs.tmp.concat(Lambda.array(Lambda.map(fs.setup, function(s) return "add(" + s + ");"))).join("\n") + "\n\n" +
			"done();\n"
		;
		
		var bindCode =
			"bindInit(buf);\n" +
			Lambda.map(v.input, function(v) return "bindReg(" + Tools.floatSize(v.type) + ");\n").join("") +
			"bindDone();\n"
		;
		
		#if (debug && shaderDebug)
		trace("VERTEX");
		for( o in vscode.code )
			trace(o);
		trace("FRAGMENT");
		for( o in fscode.code )
			trace(o);
		//trace("INIT CODE");
		//for( s in initCode.split("\n") )
		//	trace(s);
		#end
		var decls = [
			"function override__getVertexData() return format.agal.Tools.ofString('" + vsbytes + "');",
			"function override__getFragmentData() return format.agal.Tools.ofString('" + fsbytes + "');",
			"function override__bind(buf) {"+bindCode+"};",
			"function init( vertex : {" + vs.vars.join(",") + "}, fragment : {" + fs.vars.join(",") + "} ) {" + initCode + "};",
		];
		return Context.parse("{" + decls.join("\n")+"}",shader.pos);
	}

}