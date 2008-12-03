package format.swf;

typedef Fixed = haxe.Int32;
typedef Fixed8 = Int;

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
	var fps : Fixed8;
	var nframes : Int;
}

typedef PlaceObject = {
	var depth : Int;
	var move : Bool;
	var cid : Null<Int>;
	var matrix : Null<Matrix>;
	var color : Null<CXA>;
	var ratio : Null<Fixed8>;
	var instanceName : Null<String>;
	var clipDepth : Null<Int>;
	var events : Null<Array<ClipEvent>>;
	var filters : Null<Array<Filter>>;
	var blendMode : Null<BlendMode>;
	var bitmapCache : Bool;
}

typedef MatrixPart = {
	var nbits : Int;
	var x : Int;
	var y : Int;
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

enum BlendMode {
	BNormal;
	BLayer;
	BMultiply;
	BScreen;
	BLighten;
	BDarken;
	BAdd;
	BSubtract;
	BDifference;
	BInvert;
	BAlpha;
	BErase;
	BOverlay;
	BHardLight;
}

enum Filter {
	FDropShadow( data : FilterData );
	FBlur( data : BlurFilterData );
	FGlow( data : FilterData );
	FBevel( data : FilterData );
	FGradientGlow( data : GradientFilterData );
	FColorMatrix( data : Array<Float> );
	FGradientBevel( data : GradientFilterData );
}

typedef FilterFlags = {
	var inner : Bool;
	var knockout : Bool;
	var ontop : Bool;
	var passes : Int;
}

typedef FilterData = {
	var color : RGBA;
	var color2 : RGBA;
	var blurX : Fixed;
	var blurY : Fixed;
	var angle : Fixed;
	var distance : Fixed;
	var strength : Fixed8;
	var flags : FilterFlags;
}

typedef BlurFilterData = {
	var blurX : Fixed;
	var blurY : Fixed;
	var passes : Int;
}

typedef GradientFilterData = {
	var colors : Array<{ color : RGBA, position : Int }>;
	var data : FilterData;
}
