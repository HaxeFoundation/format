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
import format.hxsl.Data;
using Lambda;

class Compiler {

	private var buf:StringBuf;
	private var indent:String;
	private var inVertex:Bool;
	private var declaredVars:Hash<Bool>;
	private var code:Code;
	private var constMatch:EReg;
	
	public function new() 
	{
		this.indent = "\t";
		this.constMatch = ~/\$c([0-9]+)/;
	}
	
	private function newline()
	{
		buf.add("\n");
		buf.add(indent);
	}
	
	private function startBlock()
	{
		buf.add("{\n");
		buf.add(indent += "\t");
	}
	
	private function endBlock()
	{
		indent = indent.substr(1);
		buf.add("\n");
		buf.add(indent);
		buf.add("}");
		
		newline();
	}

	public dynamic function error(msg:String, p) : Dynamic {
		throw new Error(msg, p);
		return null;
	}

	public dynamic function warn( msg:String, p:Position) {
	}

	public function generate( data : format.hxsl.Data ) : format.glsl.Data 
	{
		return
		{
			vertex:genShader(data, true),
			fragment:genShader(data, false)
		}
	}
	
	function constToString(const:String):String
	{
		if (const.indexOf(".") == -1)
			return const + ".0";
		else if (const.charAt(const.length - 1) == ".")
			return const + "0";
		else
			return const;
	}
	
	function isConst( v : Variable ) : Null<Int>
	{
		switch(v.kind)
		{
			case VParam:
				if (constMatch.match(v.name))
				{
					return Std.parseInt(constMatch.matched(1));
				} else {
					return null;
				}
			default:
				return null;
		}
		
	}
	
	function varName( v : Variable, ?swiz:Null<Array<Comp>> ) : String
	{
		var ret = switch(v.kind)
		{
			case VTmp:
				v.name + "_tmp_" + v.index;
			case VParam:
				var idx = isConst(v);
				if (idx != null)
				{
					var const = code.consts[idx];
					var len = const.length;
					
					if (swiz != null)
					{
						if (swiz.length == 1)
						{
							constToString(const[compIndex(swiz[0])]);
						} else {
							"vec" + (swiz.length) + "(" + swiz.map(function(comp) return constToString(const[compIndex(comp)])).join(", ") + ")";
						}
					} else if (len > 1) {
						"vec" + len + "(" + const.map(constToString).join(", ") + ")";
					} else {
						constToString(const[0]);
					}
				} else {
					v.name;
				}
			case VVar, VInput, VTexture:
				v.name;
			case VOut:
				if (inVertex) "gl_Position"; else "gl_FragColor";
		}
		
		return StringTools.replace(ret, "$", "_dollar_");
	}
	
	function getVaryings( data : format.hxsl.Code ) : Array<Variable>
	{
		var varyings = new Hash();
		for (e in data.exprs)
			lookVaryings(e.e, varyings);
		
		return Lambda.array(varyings);
	}
	
	function lookVaryings( c, vs:Hash<Variable> )
	{
		switch(c.d)
		{
			case CVar( v, _ ):
				switch(v.kind)
				{
					case VVar: vs.set(v.name, v);
					default:
				}
			case COp( op, e1, e2 ):
				lookVaryings(e1, vs);
				lookVaryings(e2, vs);
			case CUnop( op, e ):
				lookVaryings(e, vs);
			case CAccess( v, idx ):
				switch(v.kind)
				{
					case VVar: vs.set(v.name, v);
					default:
				}
			case CTex( v, acc, flags ):
				switch(v.kind)
				{
					case VVar: vs.set(v.name, v);
					default:
				}
			case CSwiz( e, swiz ):
				lookVaryings(e, vs);
			case CBlock( exprs, v ):
				for (e in exprs) lookVaryings(e.e, vs);
				lookVaryings(v, vs);
		}
	}
	
	function genShader( data : format.hxsl.Data, vertex : Bool)
	{
		trace(data);
		
		this.declaredVars = new Hash();
		var buf = this.buf =  new StringBuf();
		var code = (vertex) ? data.vertex : data.fragment;
		this.inVertex = vertex;
		this.code = code;
		
		if (vertex)
		{
			//add uniforms
			
			for (uniform in code.args)
			{
				buf.add("\tuniform ");
				buf.add( declareVar(uniform) );
				buf.add(";\n");
			}
			
			//add attributes (input)
			for (att in data.input)
			{
				buf.add("\tattribute ");
				buf.add( declareVar(att) );
				buf.add(";\n");
			}
			
			//add varyings
			for (v in getVaryings(data.fragment))
			{
				buf.add("\tvarying ");
				buf.add( declareVar(v) );
				buf.add(";\n");
			}
		} else {
			//add precision statement
			buf.add('#ifdef GL_ES\n\tprecision highp float;\n\t#endif\n\t');
			
			for (uniform in code.args)
			{
				buf.add("\tuniform ");
				buf.add( declareVar(uniform) );
				buf.add(";\n");
			}
			
			for (uniform in code.tex)
			{
				buf.add("\tuniform ");
				buf.add( declareVar(uniform) );
				buf.add(";\n");
			}
			
			//add varyings
			for (v in getVaryings(data.fragment))
			{
				buf.add("\tvarying ");
				buf.add( declareVar(v) );
				buf.add(";\n");
			}
		}
		
		
		genFunction("main", [], "void", code.exprs);
		return buf.toString();
	}
	
	function genFunction(funcName:String, args:Array<Variable>, retType:String, code: Array<{ v:Null<CodeValue>, e:CodeValue }> )
	{
		buf.add(retType); buf.add(" "); buf.add(funcName); buf.add("(");
		for (arg in args) buf.add(declareVar(arg));
		buf.add(")");
		newline();
		genCode( { v:null, e: { d:CBlock(code, null), p:code[0].e.p, t:code[code.length - 1].e.t } } );
	}
	
	function tryInitialize(v:CodeValue)
	{
		switch(v.d)
		{
			case CVar(v, swiz):
				if (!varIsDeclared(v))
				{
					buf.add(declareVar(v));
					buf.add(";");
					newline();
				}
			default:
		}
	}
	
	function extractBlock(c:CodeValue): { block:Null<CodeValue>, mapped:CodeValue, v:CodeValue }
	{
		var found = null;
		var retv = null;
		
		function runner(c:CodeValue):CodeValue
		{
			if (found != null)
				return c;
			
			return switch(c.d)
			{
				case CVar( _, _ ), CTex(_,_,_):
					c;
				case CAccess(v, idx):
					{d:CAccess(v, runner(idx)), p:c.p, t:c.t}
				case COp( op, e1, e2 ):
					{d:COp(op, runner(e1), runner(e2)), p:c.p, t:c.t}
				case CUnop( op, e ):
					{d:CUnop(op, runner(e)), p:c.p, t:c.t}
				case CSwiz( e, swiz ):
					{d:CSwiz(runner(e), swiz), p:c.p, t:c.t}
				case CBlock( exprs, v ):
					found = c;
					retv = v;
					v;
			}
		}
		
		var mapped = runner(c);
		return { block:found, mapped:mapped, v:retv };
	}
	
	function genCode(c: { v:Null<CodeValue>, e:CodeValue } )
	{
		switch(c.e.d)
		{
			case CBlock(exprs, v):
				if (c.v != null)
				{
					tryInitialize(c.v);
				}
				
				startBlock();
				for (e in exprs) 
				{
					var block = extractBlock(e.e);
					while (block.block != null)
					{
						genCode({e:block.block, v:block.v});
						e.e = block.mapped;
						
						block = extractBlock(e.e);
					}
					
					genCode(e);
					switch(e.e.d)
					{
						case CBlock(_, _):
						default:
							buf.add(";");
							newline();
					}
				}
				
				if (c.v != null)
				{
					genCode( { v:c.v, e:v } );
					buf.add(";");
					newline();
				}
				endBlock();
			default:
				if (c.v != null)
				{
					genCodeVal(c.v);
					buf.add(" = ");
					genCodeVal(c.e);
				} else {
					genCodeVal(c.e);
				}
		}
	}
	
	//we need this function here because of some erroneous type delcaration
	//for some constants
	function varBytesSize(v:Variable)
	{
		var isConst = isConst(v);
		if (isConst != null)
		{
			return code.consts[isConst].length;
		} else {
			return bytesSize(v.type);
		}
	}
	
	function bytesSize(t:VarType)
	{
		return switch(t)
		{
			case TFloat: 1;
			case TFloat2: 2;
			case TFloat3: 3;
			case TFloat4: 4;
			case TInt: 1;
			case TMatrix( r, c, transpose ): switch(Std.int(Math.max(r, c)))
			{
				case 2: 4;
				case 3: 9;
				case 4: 16;
				default: throw "assert";
			}
			case TArray( t, size ): bytesSize(t) * size;
			case TTexture( cube ): throw "assert";
		}
	}
	
	//get minimum vector length of the requested swizzle
	function swizLength(swiz:Array<Comp>)
	{
		var max = 0.0;
		for (s in swiz)
		{
			switch(s)
			{
				case X: max = Math.max(max, 1);
				case Y: max = Math.max(max, 2);
				case Z: max = Math.max(max, 3);
				case W: max = Math.max(max, 4);
			}
		}
		
		return Std.int(max);
	}
	
	function compIndex(swiz:Comp)
	{
		return switch(swiz)
		{
			case X: 0;
			case Y: 1;
			case Z: 2;
			case W: 3;
		}
	}
	
	//this will only work if toSize > fromSize
	function getVecConvert(fromSize:Int, toSize:Int): { before:String, after:String }
	{
		if (toSize <= fromSize) throw "assert";
		var after = new StringBuf();
		for (i in fromSize...toSize)
		{
			switch(i)
			{
				case 3: after.add(", 1.0");
				default: after.add(", 0.0");
			}
		}
		return { before:"vec" + toSize + "(", after:after + ")" };
	}
	
	function handleSwizzle(c:CodeValue, swiz:Array<Comp>)
	{
		var cvar = null;
		var cLen = bytesSize(c.t);
			switch(c.d)
			{
				case CVar(v, _):
					cvar = v;
					if (!varIsDeclared(v))
					{
						buf.add(declareVar(v));
						buf.add(";");
						newline();
					}
					varBytesSize(v);
				default:
					bytesSize(c.t);
			}
		var sLen = swizLength(swiz);
		var convert = null;
		
		if (cvar != null)
		{
			var isConst = isConst(cvar);
			if (isConst != null)
			{
				buf.add(this.varName(cvar, swiz));
				return;
			}
		}
		
		if (sLen > cLen)
		{
			convert = getVecConvert(cLen, sLen);
			buf.add(convert.before);
			genCodeVal(c);
		} else if (cLen == 1)
		{
			if (swiz.length == 1 && swiz[0] == X ) 
			{
				genCodeVal(c);
				
				return; //no need to add the swizzle in this case
			} else {
				//if next bytes size is one and swizzle is not X, something is wrong
				this.error("Invalid swizzle", c.p);
			}
		} else {
			genCodeVal(c);
		}
		
		if (convert != null) buf.add(convert.after);
		
		buf.add(".");
		for (s in swiz)
		{
			buf.add(compToString(s));
		}
	}
	
	function genCodeVal(c:CodeValue)
	{
		switch(c.d)
		{
			case CVar( v, swiz ):
				if ( swiz != null && swiz.length > 0)
				{
					handleSwizzle( { d:CVar(v, null), t:v.type, p:c.p }, swiz );
				} else {
					buf.add(tryDeclareVar(v));
				}
			case COp( op, e1, e2 ):
				buf.add("(");
				switch(op)
				{
					//FIXME
					//this might cause some big consequences to our code. so we better watch out
					//and maybe always invert if we should transpose a matrix
					case CMul:
						genCodeVal(e2);
						buf.add(codeOpToString(op));
						genCodeVal(e1);
					case CAdd, CSub, CDiv:
						genCodeVal(e1);
						buf.add(codeOpToString(op));
						genCodeVal(e2);
					case CLt, CGte, CMod, CEq, CNeq:
						buf.add("float(");
						genCodeVal(e1);
						buf.add(codeOpToString(op));
						genCodeVal(e2);
						buf.add(")");
					case CMin, CMax, CPow, CCross, CDot:
						buf.add(codeOpToString(op));
						buf.add("(");
						genCodeVal(e1);
						buf.add(", ");
						genCodeVal(e2);
						buf.add(")");
				}
				buf.add(")");
			case CUnop( op, e ):
				buf.add("(");
				switch(op)
				{
					case CRcp:
						//get vec size
						var size = bytesSize(e.t);
						if (size > 1)
						{
							buf.add("vec");
							buf.add(size);
							buf.add("(");
							var j = [];
							for (i in 0...size)
								j.push("1.0");
							buf.add(j.join(", "));
							buf.add(") / ");
							genCodeVal(e);
						}
					case CNeg:
						buf.add(codeUnopToString(op));
						genCodeVal(e);
					case CSat:
						buf.add("clamp(");
						genCodeVal(e);
						buf.add(", 0.0, 1.0)");
					default:
						buf.add(codeUnopToString(op));
						buf.add("(");
						genCodeVal(e);
						buf.add(")");
				}
				buf.add(")");
			case CAccess( v, idx ):
				buf.add(varName(v));
				buf.add("[");
				genCodeVal(idx);
				buf.add("]");
			case CTex( v, acc, flags ):
				//TODO do not ignore the flags
				
				var swizSize = 0;
				var swiz = 
					switch(v.type)
					{
						case TTexture(cube):
							if (cube) 
							{
								buf.add("textureCube(");
								swizSize = 3;
								[X,Y,Z];
							} else {
								buf.add("texture2D(");
								swizSize = 2;
								[X,Y];
							}
						default: throw "assert";
					};
				//buf.add("texture(");
				buf.add(varName(v));
				buf.add(", ");
				switch(acc.t)
				{
					case TFloat:
						buf.add("vec");
						buf.add(swizSize);
						buf.add("(");
						var first = true;
						for (i in 0...swizSize)
						{
							if (first) first = false; else buf.add(", ");
							genCodeVal(acc);
						}
						buf.add(")");
					default:
						genCodeVal(acc);
				}
				buf.add(")");
				
			case CSwiz( e, swiz ):
				handleSwizzle(e, swiz);
				
			case CBlock( exprs, v ):
				if (v != null)
				{
					tryInitialize(v);
				}
				
				startBlock();
				for (e in exprs) 
				{
					genCode(e);
					switch(e.e.d)
					{
						case CBlock(_, _):
						default:
							buf.add(";");
							newline();
					}
				}
				
				endBlock();
		}
	}
	
	function codeUnopToString(op:CodeUnop)
	{
		return switch(op)
		{
			case CRcp: " 1.0 / ";
			case CSqrt: "sqrt";
			case CRsq: "inversesqrt";
			case CLog: "log";
			case CExp: "exp";
			case CLen: "length";
			case CSin: "sin";
			case CCos: "cos";
			case CAbs: "abs";
			case CNeg: " - ";
			case CFrac: "fract";
			case CInt: "int";
			case CNorm: "normalize";
			case CKill: "discard";
			case CTrans: "transpose";
			case CSat: throw "assert";
		}
	}
	
	function codeOpToString(op:CodeOp)
	{
		return switch(op)
		{
			case CAdd: " + ";
			case CSub: " - ";
			case CMul: " * ";
			case CDiv: " / ";
			case CMin: "min";
			case CMax: "max";
			case CPow: "pow";
			case CCross: "cross";
			case CDot: "dot";
			case CLt: "<";
			case CGte: ">=";
			case CMod: " % ";
			case CEq: " == ";
			case CNeq: " != ";
		}
	}
	
	function compToString(c:Comp):String
	{
		return switch(c)
		{
			case X: "x";
			case Y: "y";
			case Z: "z";
			case W: "w";
		}
	}
	
	function varIsDeclared(v:Variable):Bool
	{
		return switch(v.kind)
		{
			case VTmp:
				var vname = varName(v);
				declaredVars.exists(vname);
			default: true;
		}
	}
	
	function tryDeclareVar(v:Variable):String
	{
		var vname = varName(v);
		if (varIsDeclared(v))
			return vname;
		else
			return declareVar(v);
	}
	
	function declareVar(v:Variable):String
	{
		this.declaredVars.set(varName(v), true);
		return typeToString(v.type, v.pos) + " " + varName(v);
	}
	
	function typeToString( t:VarType, pos ) : String
	{
		return switch(t)
		{
			case TFloat: "float";
			case TFloat2: "vec2";
			case TFloat3: "vec3";
			case TFloat4: "vec4";
			case TInt: "float"; //at least for now TInt -> float
			case TMatrix( r, c, transpose ): switch(Std.int(Math.max(r, c)))
			{
				case 2: "mat2";
				case 3: "mat3";
				case 4: "mat4";
				default: error("Invalid matrix number: " + Std.int(Math.max(r, c)), pos);
			}
			case TTexture( cube ): (!cube) ? "sampler2D" : "samplerCube";
			case TArray( t, size ): typeToString(t, pos) + "[" + size + "]";
		}
	}
}