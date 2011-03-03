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
		case TFloat2, TFloat3, TFloat4: "flash.geom.Vector3D";
		case TMatrix(_): "flash.geom.Matrix3D";
		case TTexture(cube): "flash.display3D.textures." + (cube ? "CubeTexture" : "Texture");
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
				inf.setup.push(n + ".x");
				inf.setup.push(n + ".y");
				inf.setup.push("0");
				inf.setup.push("0");
			case TFloat3:
				inf.setup.push(n + ".x");
				inf.setup.push(n + ".y");
				inf.setup.push(n + ".z");
				inf.setup.push("0");
			case TFloat4:
				inf.setup.push(n + ".x");
				inf.setup.push(n + ".y");
				inf.setup.push(n + ".z");
				inf.setup.push(n + ".w");
			case TMatrix(w,h,t):
				var tmp = "raw_" + c.name;
				inf.tmp.push("var " + tmp + " = " + n + ".rawData;");
				for( y in 0...w )
					for( x in 0...h ) {
						var index = if( t.t ) y + x * 4 else x + y * 4;
						inf.setup.push(tmp + "[" + index + "]");
					}
			case TTexture(_):
				inf.tmp.push("texture(" + c.index + "," + n + ");");
			}
		}
		for( c in shader.consts ) {
			for( f in c )
				inf.setup.push(f);
			for( i in c.length...4 )
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

		var v = try new Parser().parse(shader) catch( e : Error ) haxe.macro.Context.error(e.message, e.pos);
		var c = new Compiler();
		c.warn = Context.warning;
		var v = try c.compile(v) catch( e : Error ) haxe.macro.Context.error(e.message, e.pos);
		
		var c = new format.agal.Compiler();
		c.error = Context.error;

		var vscode = c.compile(v.vertex);
		var fscode = c.compile(v.fragment);

		var o = new haxe.io.BytesOutput();
		new format.agal.Writer(o).write(vscode);
		var vsbytes = haxe.Serializer.run(o.getBytes());

		var o = new haxe.io.BytesOutput();
		new format.agal.Writer(o).write(fscode);
		var fsbytes = haxe.Serializer.run(o.getBytes());

		var vs = buildShaderInfos(v.vertex);
		var fs = buildShaderInfos(v.fragment);

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
		function debugReg(r:format.agal.Data.Reg) {
			var str = r.t == ROut ? "out" : Std.string(r.t).charAt(1).toLowerCase() + r.index;
			if( r.swiz != null )
				str += "." + r.swiz.join("").toLowerCase();
			return str;
		}
		function debugOp(op:format.agal.Data.Opcode) {
			var pl = Type.enumParameters(op);
			var str = Type.enumConstructor(op).substr(1).toLowerCase() + " " + debugReg(pl[0]);
			switch( op ) {
			case OKil(_): return str;
			case OTex(_, pt, tex): return str + ", tex" + tex.index + "[" + debugReg(pl[1]) + "]" + (tex.flags.length == 0  ? "" : " <" + tex.flags.join(",") + ">");
			default:
			}
			str += ", " + debugReg(pl[1]);
			if( pl[2] != null ) str += ", " + debugReg(pl[2]);
			return str;
		}
		trace("VERTEX");
		for( o in vscode.code )
			trace(debugOp(o));
		trace("FRAGMENT");
		for( o in fscode.code )
			trace(debugOp(o));
		// trace("INIT CODE");
		// for( s in initCode.split("\n") )
		// 	trace(s);
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