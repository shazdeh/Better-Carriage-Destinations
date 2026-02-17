import mx.transitions.Tween;
import mx.transitions.easing.*;

class ShazdehUtils {

    public static var i18nCache:Object = new Object();

    public static function randomNumber( minVal, maxVal ) {
        return minVal + Math.floor(Math.random( ) * (maxVal + 1 - minVal));
    }

    public static function ShuffleArray( input:Array ) {
        for (var i:Number = input.length-1; i >=0; i--) {
            var randomIndex:Number = Math.floor(Math.random()*(i+1));
            var itemAtIndex:Object = input[randomIndex];
            input[randomIndex] = input[i];
            input[i] = itemAtIndex;
        }
    }

    static function get_i18n( lookup:String ) {
        if ( ShazdehUtils.i18nCache[ lookup ] === undefined ) {
            var tf = _root.createTextField( 'temp', _root.getNextHighestDepth(), -100, -100, 0, 0 );
            tf.text = lookup;
            ShazdehUtils.i18nCache[ lookup ] = tf.text;
            tf.removeTextField();
        }

        return ShazdehUtils.i18nCache[ lookup ];
    }

    public static function str_replace( search, replace, subject ) {
        var temp = '';
        var searchIndex = -1;
        var startIndex = 0;

        while ((searchIndex = subject.indexOf(search, startIndex)) != -1) {
            temp += subject.substring(startIndex, searchIndex);
            temp += replace;
            startIndex = searchIndex + search.length;
        }

        return temp + subject.substring(startIndex);
    }

    public static function setText( input:TextField, text:String ) {
        var textFormat:TextFormat = input.getTextFormat();
        textFormat.font = '$EverywhereMediumFont';
        input.text = text;
        input.setTextFormat( textFormat );
    }

    public static function clampValue(a_val: Number, a_min: Number, a_max: Number): Number {
        return Math.min(a_max, Math.max(a_min, a_val));
    }

    /**
     * custom decimal to Hex
     * unlike toString(16) handles big numbers
     */
    public static function toHex( num:Number ) : String {
        if (num === 0) return "0";

        var hexDigits:String = "0123456789ABCDEF";
        var hexString:String = "";
        var isNegative:Boolean = num < 0;

        // Handle negative numbers by converting to two's complement for 32-bit integers
        if (isNegative) {
            num = 0xFFFFFFFF + num + 1;
        }

        while (num > 0) {
            var remainder = num % 16;  // Get the remainder when dividing by 16
            hexString = hexDigits.charAt(remainder) + hexString;  // Prepend the corresponding hex digit
            num = Math.floor(num / 16);  // Divide the number by 16 and continue
        }

        return '0x' + hexString;
    }

    public static function hexToNum( hexStr ) : Number {
        var hexDigits:String = "0123456789ABCDEF";
        var num:Number = 0;
        var isNegative:Boolean = false;

        // If the hex string starts with a negative two's complement, treat it as negative
        if (hexStr.length === 8 && hexStr[0].toUpperCase() === "F") {
            isNegative = true;
        }

        hexStr = hexStr.toUpperCase();  // Convert to uppercase to handle both 'a-f' and 'A-F'

        for (var i = 0; i < hexStr.length; i++) {
            var currentChar = hexStr.charAt(i);
            var currentVal = hexDigits.indexOf(currentChar);  // Get the numeric value for each hex digit

            if (currentVal === -1) {
                return 0;
            }

            num = num * 16 + currentVal;  // Shift previous value and add current hex digit value
        }

        // If it's a negative number (two's complement), convert it back
        if ( isNegative ) {
            num = num - 0x100000000;
        }

        return num;
    }

    /**
     * Search haystack for needle, returns the index of found item, otherwise -1
     */
    public static function array_search( needle, haystack:Array ) : Number {
        for ( var i = 0; i < haystack.length; i++ ) {
            if ( haystack[ i ] === needle ) {
                return i;
            }
        }

        return -1;
    }

    public static function array_remove_index(arr:Array, index:Number) {
        return arr.splice(0, index).concat(arr.splice(index + 1));
    }

    public static function setScaleAndPosition(mc:MovieClip) {
        var defaultWidth:Number  = 1280;
        var defaultHeight:Number = 720;

        // Save original design position
        var origX:Number = mc._x;
        var origY:Number = mc._y;

        // Calculate scale based on height (to maintain original aspect ratio)
        var scale:Number = (Stage.visibleRect.height / defaultHeight) * 100;
        mc._xscale = scale;
        mc._yscale = scale;

        // Center the "virtual stage" in the real visible area
        var stageScaledWidth:Number  = defaultWidth  * (scale / 100);
        var stageScaledHeight:Number = defaultHeight * (scale / 100);

        var offsetX:Number = (Stage.visibleRect.width  - stageScaledWidth)  / 2;
        var offsetY:Number = (Stage.visibleRect.height - stageScaledHeight) / 2;

        // Convert to local coords
        var globalOffset:Object = { 
            x: Stage.visibleRect.x + offsetX, 
            y: Stage.visibleRect.y + offsetY 
        };
        mc._parent.globalToLocal(globalOffset);

        // Position MC using scaled original design coordinates + centered offset
        mc._x = globalOffset.x + (origX * (scale / 100));
        mc._y = globalOffset.y + (origY * (scale / 100));
    }

    public static function clearMovieClip(parentMC:MovieClip) : Void {
        for ( var mc in parentMC ) {
            if ( typeof parentMC[mc] === 'movieclip' ) {
                parentMC[mc].removeMovieClip();
            }
        }
    }

    public static function fadeMC(mc:MovieClip, targetAlpha:Number, duration:Number):Void {
        // Store any existing tween reference on the clip and stop it
        if (mc._fadeTween instanceof Tween) {
            mc._fadeTween.stop();
        }

        // Ensure MC is visible if fading in
        if (targetAlpha > mc._alpha) {
            mc._visible = true;
        }

        // Create and store the new tween
        mc._fadeTween = new Tween(mc, "_alpha", Regular.easeOut, mc._alpha, targetAlpha, duration, true);

        // If fading out, hide at the end
        mc._fadeTween.onMotionFinished = function() {
            if (targetAlpha == 0) {
                mc._visible = false;
            }
        };
    }

    public static function LogObject( obj ) {
        var s = '';
        for ( var i in obj ) {
            s += i + ': ' + obj[i] + ';\n';
        }
        skse.Log(s);
    }

    public static function dumpObject(obj:Object, indent:String, visited:Array):String {
        if (indent == undefined) indent = "";
        if (visited == undefined) visited = [];

        var output:String = "";
        if (obj == null) {
            return "null\n";
        }

        // prevent infinite recursion for cyclic references
        for (var i:Number = 0; i < visited.length; i++) {
            if (visited[i] === obj) {
                return "[Circular Reference]\n";
            }
        }
        visited.push(obj);

        for (var prop in obj) {
            var val = obj[prop];
            var type = typeof(val);

            if (type == "object") {
                output += indent + prop + " (Object):\n";
                output += ShazdehUtils.dumpObject(val, indent + "    ", visited.concat());
            } else if (type == "function") {
                output += indent + prop + " (Function)\n";
            } else {
                output += indent + prop + " (" + type + "): " + val + "\n";
            }
        }

        return output;
    }
}