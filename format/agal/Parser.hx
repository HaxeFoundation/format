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
package format.agal;
import format.agal.Data;
import haxe.macro.Expr;

class ParserError {
	public var message : String;
	public var pos : Position;
	public function new(msg, p) {
		this.message = msg;
		this.pos = p;
	}
}

private typedef Reg = {
	var t : RegType;
	var index : Int;
	var fields : Null<Array<C>>;
	var pos : Position;
}

class Parser {

	var fragment : Bool;
	var code : Array<Opcode>;

	public function new(frag) {
		this.fragment = frag;
	}

	function error(msg,p) : Dynamic {
		throw new ParserError(msg, p);
		return null;
	}

	public function parse( e : Expr ) : Data {
		code = [];
		loop(e);
		return { code : code, fragmentShader : fragment };
	}

	function makeOp( op : Dest -> Src -> Src -> Opcode, dst : Reg, args : Array<Expr>, p : Position ) {
		if( args.length != 2 )
			error("Two parameters are required", p);
		code.push(op(makeDest(dst), makeSrc(getReg(args[0])), makeSrc(getReg(args[1]))));
	}

	function makeUnop( op : Dest -> Src -> Opcode, dst : Reg, args : Array<Expr>, p : Position ) {
		if( args.length != 1 )
			error("One single parameter is accepted", p);
		code.push(op(makeDest(dst), makeSrc(getReg(args[0]))));
	}

	function loop( e : Expr ) {
		switch( e.expr ) {
		case EBlock(el):
			for( e in el )
				loop(e);
			return;
		case EBinop(op, dst, v):
			switch( op ) {
			case OpAssign:
				var dst = getReg(dst);
				switch( v.expr ) {
				case ECall(f, args):
					var id = getIdent(f);
					switch( id ) {
					case "dp4": return makeOp(ODp4, dst, args, e.pos);
					case "dp3": return makeOp(ODp3, dst, args, e.pos);
					case "min": return makeOp(OMin, dst, args, e.pos);
					case "max": return makeOp(OMax, dst, args, e.pos);
					case "pow": return makeOp(OPow, dst, args, e.pos);
					case "cos": return makeUnop(OCos, dst, args, e.pos);
					case "sin": return makeUnop(OSin, dst, args, e.pos);
					case "sqrt": return makeUnop(OSqt, dst, args, e.pos);
					case "frac": return makeUnop(OFrc, dst, args, e.pos);
					case "tex":
						if( args.length < 2 ) error("Missing arguments : (index,position) required", e.pos);
						var idx = getInt(args[0]);
						var r = getReg(args[1]);
						var flags = [];
						for( i in 2...args.length ) {
							var n = getIdent(args[i]);
							var f = switch( n ) {
							case "wrap": TWrap;
							case "clamp": TClamp;
							case "linear": TFilterLinear;
							case "nearest": TFilterNearest;
							case "t2d": T2D;
							case "cube": TCube;
							case "t3d": T3D;
							case "mmnone": TMipMapDisable;
							case "mmnearest": TMipMapNearest;
							case "mmlinear": TMipMapLinear;
							case "centroid": TCentroidSample;
							default: error("Unknown texture flag '" + n + "'", args[i].pos);
							}
							flags.push(f);
						}
						if( flags.length == 0 ) flags = null;
						code.push(OTex(makeDest(dst), makeSrc(r), { index : idx, flags : flags } ));
						return;
					default:
						error("Unknown operation '" + id + "'", f.pos);
					}
				case EBinop(op, e1, e2):
					switch( op ) {
					case OpAdd: return makeOp(OAdd, dst, [e1,e2], e.pos);
					case OpSub: return makeOp(OSub, dst, [e1,e2], e.pos);
					case OpMult: return makeOp(OMul, dst, [e1, e2], e.pos);
					case OpDiv: return makeOp(ODiv, dst, [e1,e2], e.pos);
					default:
						error("Unsupported operation", v.pos);
					}
				default:
					var src = getReg(v);
					code.push(OMov(makeDest(dst), makeSrc(src)));
					return;
				}
			default:
			}
		default:
		}
		error("Unsupported expression", e.pos);
		return null;
	}

	function makeDest( r : Reg ) : Dest {
		if( r.fields != null ) {
			var min = -1;
			for( c in r.fields ) {
				var i = Type.enumIndex(c);
				if( i <= min ) error("Invalid write mask", r.pos);
				min = i;
			}
		}
		var p = Tools.getProps(r.t, fragment);
		if( !p.write )
			error("Register is read-only", r.pos);
		if( r.index >= p.count )
			error("Index out of bounds", r.pos);
		return {
			t : r.t,
			index : r.index,
			mask : r.fields,
		};
	}

	function makeSrc( r : Reg ) : Src {
		if( r.fields != null ) {
			if( r.fields.length == 0 || r.fields.length > 4 )
				error("Invalid swizzle", r.pos);
		}
		var p = Tools.getProps(r.t, fragment);
		if( !p.read )
			error("Register is write-only", r.pos);
		if( r.index >= p.count )
			error("Index out of bounds", r.pos);
		return {
			t : r.t,
			index : r.index,
			swiz : r.fields,
		};
	}

	function getIdent( e : Expr ) {
		return switch( e.expr ) {
		case EConst(c):
			switch( c ) {
			case CIdent(n), CType(n): n;
			default: error("Identifier expected", e.pos);
			}
		default: error("Identifier expected", e.pos);
		};
	}

	function getInt( e : Expr ) {
		return switch( e.expr ) {
		case EConst(c):
			switch( c ) {
			case CInt(n): Std.parseInt(n);
			default: error("Constant integer expected", e.pos);
			}
		default: error("Constant integer expected", e.pos);
		};
	}

	function getReg( e : Expr ) : Reg {
		switch( e.expr ) {
		case EArray(id, index):
			var n = getIdent(id);
			var t = switch( n ) {
			case "vars": RVar;
			case "tmp": RTemp;
			case "attr": RAttr;
			case "const": RConst;
			default: error("Unknown identifier '" + n + "'", id.pos);
			}
			return { t : t, index : getInt(index), fields : null, pos : e.pos };
		case EConst(c):
			switch( c ) {
			case CIdent(n):
				if( n == "out" )
					return { t : ROut, index : 0, fields : null, pos : e.pos };
			default:
			}
		case EField(f, ident):
			var r = getReg(f);
			if( r.fields != null )
				error("Invalid field access", e.pos);
			var fields = [];
			for( i in 0...ident.length )
				switch( ident.charAt(i) ) {
				case "x": fields.push(X);
				case "y": fields.push(Y);
				case "z": fields.push(Z);
				case "w": fields.push(W);
				default: error("Register component should be xyzw", e.pos);
				}
			r.fields = fields;
			r.pos = e.pos;
			return r;
		default:
		}
		return error("Invalid register", e.pos);
	}

}