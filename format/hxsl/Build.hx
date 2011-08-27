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
		case TColor3, TColor: "Int";
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
				inf.setup.push("1.");
				inf.setup.push("1.");
			case TFloat3:
				inf.setup.push(n + ".x");
				inf.setup.push(n + ".y");
				inf.setup.push(n + ".z");
				inf.setup.push("1.");
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
			case TColor3:
				inf.setup.push("((" + n + ">>16) & 0xFF) / 255.0");
				inf.setup.push("((" + n + ">>8) & 0xFF) / 255.0");
				inf.setup.push("(" + n + " & 0xFF) / 255.0");
				inf.setup.push("1.");
			case TColor:
				inf.setup.push("((" + n + ">>16) & 0xFF) / 255.0");
				inf.setup.push("((" + n + ">>8) & 0xFF) / 255.0");
				inf.setup.push("(" + n + " & 0xFF) / 255.0");
				inf.setup.push("(" + n + ">>>24) / 255.0");
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

	@:macro public static function shader() : Array<Field> {
		var cl = Context.getLocalClass().get();
		var fields = Context.getBuildFields();
		var shader = null;
		for( m in cl.meta.get() )
			if( m.name == ":shader" ) {
				if( m.params.length != 1 )
					Context.error("@:shader metadata should only have one parameter", m.pos);
				shader = m.params[0];
				break;
			}
		if( shader == null ) {
			for( f in fields )
				if( f.name == "SRC" ) {
					switch( f.kind ) {
					case FVar(_, e):
						if( e != null ) {
							shader = e;
							fields.remove(f);
							break;
						}
					default:
					}
				}
		}
		if( shader == null )
			Context.error("Missing @:shader metadata", cl.pos);

		var p = new Parser();
		p.includeFile = function(file) {
			var f = Context.resolvePath(file);
			return Context.parse("{"+neko.io.File.getContent(f)+"}", Context.makePosition( { min : 0, max : 0, file : f } ));
		};
		var v = try p.parse(shader) catch( e : Error ) haxe.macro.Context.error(e.message, e.pos);
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

		var unbindCode = null;
		if( v.fragment.tex.length > 0 ) {
			unbindCode = "super.unbind();\n";
			for( t in v.fragment.tex )
				unbindCode += "unbindTex(" + t.index + ");\n";
		}

		#if (debug && shaderDebug)
		trace("VERTEX");
		for( o in vscode.code )
			trace(format.agal.Tools.opStr(o));
		trace("FRAGMENT");
		for( o in fscode.code )
			trace(format.agal.Tools.opStr(o));
		// trace("INIT CODE");
		// for( s in initCode.split("\n") )
		// 	trace(s);
		#end
		var decls = [
			"override function getVertexData() return format.agal.Tools.ofString('" + vsbytes + "')",
			"override function getFragmentData() return format.agal.Tools.ofString('" + fsbytes + "')",
			"override function bind(buf) {"+bindCode+"}",
			"public function init( vertex : {" + vs.vars.join(",") + "}, fragment : {" + fs.vars.join(",") + "} ) {" + initCode + "}",
		];
		if( unbindCode != null )
			decls.push("override function unbind() {" + unbindCode + "}");

		var e = Context.parse("{ var x : {" + decls.join("\n") + "}; }", shader.pos);
		var fdecls = switch( e.expr ) {
			case EBlock(el):
				switch( el[0].expr ) {
				case EVars(vl):
					switch( vl[0].type) {
					case TAnonymous(fl): fl;
					default: null;
					}
				default: null;
				}
			default: null;
		};
		if( fdecls == null ) throw "assert";

		return fields.concat(fdecls);
	}

}