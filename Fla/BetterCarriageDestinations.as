import skse;
import ShazdehUtils;

class BetterCarriageDestinations extends MovieClip {

    public static var instance;

    /* refs */
    public var WorldMap:MovieClip;

    private var numMarkers:Number = undefined;

    public var excludedMarkerType:Array = [
        57, // return to skyrim
        58, // Solstheim
        63, // quest markers
        65, // custom destination
        66  // player position
    ];

    function BetterCarriageDestinations() {
        BetterCarriageDestinations.instance = this;
        _root.BCD_filterList = undefined;
    }

	function onLoad() {
        WorldMap = _parent._parent.WorldMap;
        duckPunch();
    }

    function duckPunch() {
        WorldMap.BCD__ClickSelectedMarker = WorldMap.ClickSelectedMarker;
        WorldMap.ClickSelectedMarker = ClickSelectedMarker;

        WorldMap.BCD__CreateMarkers = WorldMap.CreateMarkers;
        WorldMap.CreateMarkers = CreateMarkers;

        WorldMap.BCD__SetNumMarkers = WorldMap.SetNumMarkers;
        WorldMap.SetNumMarkers = SetNumMarkers;
    }

    // @override
    public function SetNumMarkers(a_numMarkers: Number): Void {
        this = BetterCarriageDestinations.instance;
        WorldMap.BCD__SetNumMarkers(a_numMarkers);
        if (numMarkers === undefined) {
            numMarkers = a_numMarkers;
        }
    }

    // @override
    function CreateMarkers() {
        this = BetterCarriageDestinations.instance;
        WorldMap.BCD__CreateMarkers();

        var markerList:Array = WorldMap._markerList;
        if (
            numMarkers !== undefined
            && markerList.length === numMarkers
            && markerList[markerList.length - 1] !== undefined // markers are rendered in batches, this ensures the CreateMarkers() is done
        ) {
            if (_root.BCD_filterList === undefined) {
                _root.CreateFilterList();
            }
            afterRender();
        }
    }

    // @override
    function ClickSelectedMarker() : Void {
        this = BetterCarriageDestinations.instance;

        if (isValidMapMarker(WorldMap._selectedMarker)) {
            skse.SendModEvent('BCD_SetDestination', '', WorldMap._selectedMarker.index);
        }
    }

    function afterRender() {
        if (_root.BCD_filterList === undefined) return;
        var markerList:Array = WorldMap._markerList;
        for (var i = 0; i < markerList.length; i++) {
            if (!isValidMapMarker(markerList[i])) {
                markerList[i]._alpha = 20;
            }
        }
    }

    function isValidMapMarker(marker:Object) : Boolean {
        var type:Number = marker.markerType;
        for ( var i = 0; i < excludedMarkerType.length; i++ ) {
            if ( type === excludedMarkerType[i] ) {
                return false;
            }
        }

        var index = marker.index;
        if (_root.BCD_filterList !== undefined && _root.BCD_filterList[index] === true) {
            return false;
        }

        return true;
    }
}