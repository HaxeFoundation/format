package format.pex;

@:enum
abstract EmitterType(Int) from Int to Int
{
	var Gravity = 0;
	var Radial = 1;
}

@:enum
abstract BlendFunction(Int) from Int to Int
{
	var Zero = 0;
	var One = 1;
	var SourceColor = 0x300;
	var OneMinusSourceColor = 0x301;
	var SourceAlpha = 0x302;
	var OneMinusSourceAlpha = 0x303;
	var DestinationAlpha = 0x304;
	var OneMinusDestinationAlpha = 0x305;
	var DestinationColor = 0x306;
	var OneMinusDestinationColor = 0x307;
}

@:forward(base, variance)
abstract ValueWithVariance<T:Float>({base:T, variance:T})
{
	public inline function new(base:T, variance:T)
	{
		this = {base:base, variance:variance};
	}

	/**
	 * Choose a random float within this range.
	 */
	public inline function random():Float
	{
		return this.base + (Math.random() * 2 - 1) * this.variance;
	}

	/**
	 * Choose a random integer within this range.
	 */
	public inline function randomInt():Int
	{
		return Std.int(Math.round(random()));
	}
}

typedef FloatWithVariance = ValueWithVariance<Float>;
typedef UIntWithVariance = ValueWithVariance<UInt>;

class PexParticle
{
	public var emitterType:EmitterType = EmitterType.Gravity;
	public var textureName:String;
	public var emitterXVariance:Float = 0;
	public var emitterYVariance:Float = 0;
	public var duration:Float = 0;
	public var maxParticles:Int = 0;

	public var lifespan:FloatWithVariance;
	public var startSize:FloatWithVariance;
	public var endSize:FloatWithVariance;
	public var emitAngle:FloatWithVariance;
	public var startRotation:FloatWithVariance;
	public var endRotation:FloatWithVariance;

	public var speed:FloatWithVariance;
	public var gravityX:Float = 0;
	public var gravityY:Float = 0;
	public var radialAcceleration:FloatWithVariance;
	public var tangentialAcceleration:FloatWithVariance;

	public var maxRadius:FloatWithVariance;
	public var minRadius:FloatWithVariance;
	public var rotatePerSecond:FloatWithVariance;

	public var startColor:UIntWithVariance;
	public var endColor:UIntWithVariance;

	public var blendSource:BlendFunction;
	public var blendDestination:BlendFunction;

	public function new() {}
}
