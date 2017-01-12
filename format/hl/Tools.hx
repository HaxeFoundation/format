package format.hl;
import format.hl.Data;

class Tools {

	public static function isDynamic( t : HLType ) {
		return switch( t ) {
		case HVoid, HUi8, HUi16, HI32, HF32, HF64, HBool, HAt(_):
			false;
		case HBytes, HType, HRef(_), HAbstract(_), HEnum(_):
			false;
		case HDyn, HFun(_), HObj(_), HArray, HVirtual(_), HDynObj, HNull(_):
			true;
		}
	}

	public static function isPtr( t : HLType ) {
		return switch( t ) {
		case HVoid, HUi8, HUi16, HI32, HF32, HF64, HBool, HAt(_):
			false;
		case HBytes, HType, HRef(_), HAbstract(_), HEnum(_):
			true;
		case HDyn, HFun(_), HObj(_), HArray, HVirtual(_), HDynObj, HNull(_):
			true;
		}
	}

	public static function hash( name : String ) {
		var h = 0;
		for( i in 0...name.length )
			h = 223 * h + StringTools.fastCodeAt(name,i);
		h %= 0x1FFFFF7B;
		return h;
	}

}