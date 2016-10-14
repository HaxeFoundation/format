package format.pex;

import haxe.io.Input;
import haxe.xml.Fast;
import format.pex.Data;

class Reader
{
	/**
	 * Parse a PexParticle from a .pex XML file.
	 */
	public static function read(i:Input):PexParticle
	{
		var contents = i.readAll().toString();
		return parse(contents);
	}

	/**
	 * Parse a PexParticle from a string contianing .pex XML.
	 */
	public static function parse(contents:String):PexParticle
	{
		var data = new Fast(Xml.parse(contents).firstElement());
		var particle:PexParticle = new PexParticle();

		particle.emitterType = parseInt(data, "emitterType");
		particle.textureName = data.node.texture.att.name;
		particle.duration = parseFloat(data, "duration");
		particle.maxParticles = parseInt(data, "maxParticles");
		particle.emitterXVariance = parseFloat(data, "sourcePositionVariance", "x");
		particle.emitterYVariance = parseFloat(data, "sourcePositionVariance", "y");
		particle.gravityX = parseFloat(data, "gravity", "x");
		particle.gravityY = parseFloat(data, "gravity", "y");
		particle.lifespan = parseFloatWithVariance(data, "particleLifespan");
		particle.startSize = parseFloatWithVariance(data, "startParticleSize");
		particle.endSize = parseFloatWithVariance(data, "finishParticleSize");
		particle.emitAngle = parseFloatWithVariance(data, "angle");
		particle.startRotation = parseFloatWithVariance(data, "rotationStart");
		particle.endRotation = parseFloatWithVariance(data, "rotationEnd");
		particle.speed = parseFloatWithVariance(data, "speed");
		particle.radialAcceleration = parseFloatWithVariance(data, "radialAcceleration", "radialAccelVariance");
		particle.tangentialAcceleration = parseFloatWithVariance(data, "tangentialAcceleration", "tangentialAccelVariance");
		particle.maxRadius = parseFloatWithVariance(data, "maxRadius");
		particle.minRadius = parseFloatWithVariance(data, "minRadius");
		particle.rotatePerSecond = parseFloatWithVariance(data, "rotatePerSecond");
		particle.startColor = parseColor(data, "startColor");
		particle.endColor = parseColor(data, "finishColor");
		particle.blendSource = parseInt(data, "blendFuncSource");
		particle.blendDestination = parseInt(data, "blendFuncDestination");

		return particle;
	}

	static inline function parseFloat(data:Fast, nodeName:String, att:String = "value"):Float
	{
		return Std.parseFloat(findNode(data, nodeName).att.resolve(att));
	}

	static inline function parseInt(data:Fast, nodeName:String, att:String = "value"):Int
	{
		return Std.parseInt(findNode(data, nodeName).att.resolve(att));
	}

	static inline function parseFloatWithVariance(data:Fast, nodeName:String, ?varianceName:String):FloatWithVariance
	{
		if (varianceName == null) varianceName = nodeName + "Variance";
		var base = parseFloat(data, nodeName);
		var variance = parseFloat(data, varianceName);
		return new FloatWithVariance(base, variance);
	}

	static inline function parseColor(data:Fast, nodeName:String, ?varianceName:String):UIntWithVariance
	{
		if (varianceName == null) varianceName = nodeName + "Variance";
		var a = parseFloat(data, nodeName, "alpha"),
			r = parseFloat(data, nodeName, "red"),
			g = parseFloat(data, nodeName, "green"),
			b = parseFloat(data, nodeName, "blue"),
			av = parseFloat(data, varianceName, "alpha"),
			rv = parseFloat(data, varianceName, "red"),
			gv = parseFloat(data, varianceName, "green"),
			bv = parseFloat(data, varianceName, "blue");
		return new UIntWithVariance(makeColor(a, r, g, b), makeColor(av, rv, gv, bv));
	}

	static inline function makeColor(a:Float, r:Float, g:Float, b:Float):UInt
	{
		return (Std.int(0xFF * a) << 16) | (Std.int(0xFF * r) << 16) | (Std.int(0xFF * g) << 8) | Std.int(0xFF * b);
	}

	/**
	 * Case-insensitive node search to deal with historical case changes of pex
	 * element names.
	 */
	static function findNode(data:Fast, nodeName:String):Fast
	{
		nodeName = nodeName.toLowerCase();
		for (child in data.x.iterator())
		{
			if (child.nodeType == Element && child.nodeName.toLowerCase() == nodeName)
			{
				return new Fast(child);
			}
		}
		throw 'pex node not found: $nodeName';
	}
}
