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
package format.glsl;

#if macro
import format.hxsl.Compiler;
import format.hxsl.Parser;
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
		case TFloat2, TFloat3, TFloat4: "Dynamic";
		case TColor3, TColor: "Int";
		case TMatrix(_): "Dynamic";
		case TTexture(cube): "Dynamic";
		case TArray(t, size): "format.glsl.Shader.GArray<" + realType(t) + ","+size+">";
		};
	}

	static function buildShaderInfos( shader : Code ) {
		var inf = {
			vars : [],
			setup : [],
		};
		if( shader.vertex )
			inf.setup.push("start(true);");
		else
			inf.setup.push("start(false);");
		var vcount = 0;
		function add(v) {
			inf.setup.push("add("+v+");");
			vcount++;
		}
		for( c in shader.args.concat(shader.tex) ) {
			var t = realType(c.type);
			inf.vars.push(c.name + " : " + t);
			function addType( n : String, t : VarType )	{
				switch( t ) {
				case TFloat:
					add(n);
					add(n);
					add(n);
					add(n);
				case TFloat2:
					add(n + ".x");
					add(n + ".y");
					add("1.");
					add("1.");
				case TFloat3:
					add(n + ".x");
					add(n + ".y");
					add(n + ".z");
					add("1.");
				case TFloat4:
					add(n + ".x");
					add(n + ".y");
					add(n + ".z");
					add(n + ".w");
				case TMatrix(w,h,t):
					var tmp = "raw_" + c.name;
					inf.setup.push("var " + tmp + " = " + n + ".rawData;");
					for( y in 0...w )
						for( x in 0...h ) {
							var index = if( t.t ) y + x * 4 else x + y * 4;
							add(tmp + "[" + index + "]");
						}
				case TTexture(_):
					inf.setup.push("texture(" + c.index + "," + n + ");");
				case TColor3:
					add("((" + n + ">>16) & 0xFF) / 255.0");
					add("((" + n + ">>8) & 0xFF) / 255.0");
					add("(" + n + " & 0xFF) / 255.0");
					add("1.");
				case TColor:
					add("((" + n + ">>16) & 0xFF) / 255.0");
					add("((" + n + ">>8) & 0xFF) / 255.0");
					add("(" + n + " & 0xFF) / 255.0");
					add("(" + n + ">>>24) / 255.0");
				case TArray(t, count):
					var old = vcount;
					inf.setup.push("for( _i in 0..." + count + " ) {");
					addType(n + "[_i]", t);
					inf.setup.push("}");
					vcount += (vcount - old) * (count - 1);
				}
			}
			addType( (shader.vertex?"vertex":"fragment") + "." + c.name, c.type);
		}
		for( c in shader.consts ) {
			for( f in c )
				add(f);
			for( i in c.length...4 )
				add("0");
		}

		if( vcount >> 2 >= format.agal.Tools.getProps(RConst, !shader.vertex).count )
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
							haxe.macro.Compiler.removeField(Context.getLocalClass().toString(), "SRC", true);
							break;
						}
					default:
					}
				}
		}
		if( shader == null )
			Context.error("Missing SRC shader", cl.pos);

		var p = new Parser();
		p.includeFile = function(file) {
			var f = Context.resolvePath(file);
			return Context.parse("{"+neko.io.File.getContent(f)+"}", Context.makePosition( { min : 0, max : 0, file : f } ));
		};
		var v = try p.parse(shader) catch( e : Error ) haxe.macro.Context.error(e.message, e.pos);
		var c = new Compiler();
		c.config.padWrites = false;
		c.config.inlInt = false;
		c.config.inlTranspose = false;
		c.config.forceReads = false;
		c.warn = Context.warning;
		var v = try c.compile(v) catch( e : Error ) haxe.macro.Context.error(e.message, e.pos);

		var c = new format.glsl.Compiler();
		c.error = Context.error;

		var codes = c.generate(v);

		var vs = buildShaderInfos(v.vertex);
		var fs = buildShaderInfos(v.fragment);

		var initCode =
			vs.setup.join("\n") + "\n\n" +
			fs.setup.join("\n") + "\n\n" +
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
			"override function getVertexData() return '" + StringTools.replace(codes.vertex, "'", "\\'") + "'",
			"override function getFragmentData() return '" + StringTools.replace(codes.fragment, "'", "\\'") + "'",
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