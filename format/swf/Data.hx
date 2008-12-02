package format.swf;

typedef Float16 = Int;

enum SWFTag {
	TShowFrame;
	TShape( id : Int, version : Int, data : haxe.io.Bytes );
	TUnknown( id : Int, data : haxe.io.Bytes );
	TClip( id : Int, frames : Int, tags : Array<SWFTag> );
	TPlaceObject2( po : PlaceObject );
	TPlaceObject3( po : PlaceObject );
	TRemoveObject2( depth : Int );
	TFrameLabel( label : String, anchor : Bool );
	TExtended( t : SWFTag );
}

typedef SWF = {
	var version : Int;
	var compressed : Bool;
	var width : Int;
	var height : Int;
	var fps : Float16;
	var nframes : Int;
}

typedef PlaceObject = {
	var depth : Int;
	var move : Bool;
	var cid : Null<Int>;
	var matrix : Null<Matrix>;
	var color : Null<CXA>;
	var ratio : Null<Float16>;
	var instanceName : Null<String>;
	var clipDepth : Null<Int>;
	var events : Null<Array<ClipEvent>>;
	var filters : Null<Array<Filter>>;
	var blendMode : Null<Int>;
	var bitmapCache : Null<Int>;
}

typedef MatrixPart = {
	var nbits : Int;
	var x : Float16;
	var y : Float16;
}

typedef Matrix = {
	var scale : Null<MatrixPart>;
	var rotate : Null<MatrixPart>;
	var translate : MatrixPart;
}

typedef RGBA = {
	var r : Int;
	var g : Int;
	var b : Int;
	var a : Int;
}

typedef CXA = {
	var nbits : Int;
	var add : Null<RGBA>;
	var mult : Null<RGBA>;
}

typedef ClipEvent = {
	var eventsFlags : Int;
	var data : haxe.io.Bytes;
}

enum Filter {
	FDropShadow( data : haxe.io.Bytes );
	FBlur( data : haxe.io.Bytes );
	FGlow( data : haxe.io.Bytes );
	FBevel( data : haxe.io.Bytes );
	FGradientGlow( data : FilterGradient );
	FAdjustColor( data : haxe.io.Bytes );
	FGradientBevel( data : FilterGradient );
}

typedef FilterGradient = {
	var colors : Array<{ color : RGBA, position : Int }>;
	var data : haxe.io.Bytes;
}
