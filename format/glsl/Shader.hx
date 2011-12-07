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

typedef GArray<T,Const> = Array<T>;

@:autoBuild(format.glsl.Build.shader()) class Shader {

	//var c : flash.display3D.Context3D;
	//var p : flash.display3D.Program3D;
	//var buf : flash.display3D.VertexBuffer3D;
	//var cst : flash.Vector<Float>;
	//var pos : Int;
	//var regIndex : Int;
	//var bufSize : Int;

	public function new(c) {
		//this.c = c;
		//this.p = c.createProgram();
		//p.upload(getVertexData().getData(), getFragmentData().getData());
	}

	public function getVertexData() : String {
		throw "needs subclass";
		return null;
	}

	public function getFragmentData() : String {
		throw "needs subclass";
		return null;
	}

	function send(vertex:Bool) {
		//var pt = vertex?flash.display3D.Context3DProgramType.VERTEX:flash.display3D.Context3DProgramType.FRAGMENT;
		//c.setProgramConstantsFromVector(pt, 0, cst);
		//cst = null;
	}
/*
	static var FORMATS = [
		null,
		flash.display3D.Context3DVertexBufferFormat.FLOAT_1,
		flash.display3D.Context3DVertexBufferFormat.FLOAT_2,
		flash.display3D.Context3DVertexBufferFormat.FLOAT_3,
		flash.display3D.Context3DVertexBufferFormat.FLOAT_4,
	];
*/
	function bindInit(buf) {
		//this.buf = buf;
		//regIndex = 0;
		//bufSize = 0;
	}

	function bindDone() {
		//buf = null;
	}

	inline function bindReg(nfloats:Int) {
		//c.setVertexBufferAt( regIndex, buf, bufSize, FORMATS[nfloats] );
		//regIndex++;
		//bufSize += nfloats;
	}

	public function bind(buf) {
		//this.buf = buf;
		//throw "needs subclass";
	}

	public function unbind() {
		//while( regIndex-- > 0 )
		//	c.setVertexBufferAt(regIndex,null);
	}

	public function draw( vbuf, ibuf ) {
		//bind(vbuf);
		//c.drawTriangles(ibuf);
		//unbind();
	}

	public function dispose() {
		//if( p == null ) return;
		//p.dispose();
		//p = null;
	}

	function start(vertex) {
		//if( vertex )
		//	c.setProgram(p);
		//else
		//	send(true);
		//cst = new flash.Vector<Float>();
		//pos = 0;
	}

	inline function add( v : Float ) {
		//cst[pos++] = v;
	}

	function texture( index : Int, t ) {
		//c.setTextureAt(index, t);
	}

	inline function unbindTex(index) {
		//c.setTextureAt(index, null);
	}

	function done() {
		send(false);
		//cst = null;
	}

}