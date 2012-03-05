package format.tools;

@:native('Int')
extern class MemoryBytes {
	
	public static inline function make( pos : Int ) : MemoryBytes {
		return cast pos;
	}
	
	inline function getPos() : Int {
		return cast this;
	}
	
	public inline function get( p : Int ) : Int {
		return flash.Memory.getByte(getPos() + p);
	}

	public inline function set( p : Int, v : Int ) : Void {
		flash.Memory.setByte(getPos() + p, v);
	}
	
}
