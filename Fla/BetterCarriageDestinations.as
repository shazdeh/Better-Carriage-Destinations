import skse;
import ShazdehUtils;

class BetterCarriageDestinations extends MovieClip {

    public static var instance;

    /* refs */
    public var WorldMap:MovieClip;

    public var excludedMarkerType:Array = [
        57, // return to skyrim
        58, // Solstheim
        63, // quest markers
        65, // custom destination
        66 // player position
    ];

    function BetterCarriageDestinations() {
        BetterCarriageDestinations.instance = this;
    }

	function onLoad() {
        WorldMap = _parent._parent.WorldMap;
        duckPunch();
    }

    function duckPunch() {
        WorldMap.BCD__ClickSelectedMarker = WorldMap.ClickSelectedMarker;
        WorldMap.ClickSelectedMarker = ClickSelectedMarker;
    }

    function ClickSelectedMarker() : Void {
        this = BetterCarriageDestinations.instance;

        if ( isValidMapMarker() ) {
            skse.SendModEvent('BCD_SetDestination', WorldMap._selectedMarker._label);
        }
    }

    function isValidMapMarker() : Boolean {
        var currentMarker:Number = WorldMap._selectedMarker.markerType;
        for ( var i = 0; i < excludedMarkerType.length; i++ ) {
            if ( currentMarker === excludedMarkerType[i] ) {
                return false;
            }
        }

        return true;
    }

    function LogObject( obj ) {
        var s = '';
        for ( var i in obj ) {
            s += i + ': ' + obj[i] + ';\n';
        }
        skse.Log(s);
    }
}