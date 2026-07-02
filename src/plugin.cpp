#include "logger.h"

using namespace RE;

TESGlobal* OnlyDiscovered;
TESGlobal* OnlySettlement;
TESGlobal* AllowCleared;
BGSListForm* SettlementLocKeywordsList;

// temp storage
BGSListForm* filterList;
bool isWhitelist;

void OpenMenu(std::string_view a_menuName) {
    if (const auto UIMsgQueue = RE::UIMessageQueue::GetSingleton(); UIMsgQueue) {
        UIMsgQueue->AddMessage(a_menuName, RE::UI_MESSAGE_TYPE::kShow, nullptr);
    }
}

void CloseMenu(std::string_view a_menuName) {
    if (const auto UIMsgQueue = RE::UIMessageQueue::GetSingleton(); UIMsgQueue) {
        UIMsgQueue->AddMessage(a_menuName, RE::UI_MESSAGE_TYPE::kHide, nullptr);
    }
}

TESObjectREFR* GetRefFromHandle(RefHandle handle) {
    RE::TESObjectREFRPtr refr;
    RE::LookupReferenceByHandle(handle, refr);
    if (auto* ref = refr.get(); ref) {
        return ref;
    }
    return nullptr;
}

bool IsMarkerBlocked(TESObjectREFR* marker) {
    if (filterList) {
        if ((isWhitelist && !filterList->HasForm(marker)) || (!isWhitelist && filterList->HasForm(marker))) {
            return true;
        }
    }

    if (OnlyDiscovered->value == 1.0f) {
        auto* extra = marker->extraList.GetByType<ExtraMapMarker>();
        if (extra && !extra->mapData->flags.any(MapMarkerData::Flag::kCanTravelTo)) return true;
    }

    // following filters only apply when not using a whitelist
    // my feeling is if we have a list of "allow only these markers..." then
    // the other conditions shouldn't apply.
    if (!filterList || !isWhitelist) {
        if (OnlySettlement->value == 1.0f) {
            if (auto* location = marker->GetCurrentLocation(); location) {
                if (!(location->HasKeywordInList(SettlementLocKeywordsList, false) || (AllowCleared->value == 1.0f && location->cleared))) return true;
            }
        }
    }

    return false;
}

class CreateFilterList : public RE::GFxFunctionHandler {
public:
    virtual void Call(Params& params) override {
        auto menu = UI::GetSingleton()->GetMenu<MapMenu>();
        auto& markers = menu->GetRuntimeData2()->mapMarkers;
        auto movie = menu->uiMovie;
        if (!movie) return;
        GFxValue _root;
        movie->GetVariable(&_root, "_root");

        GFxValue data;
        movie->CreateObject(&data);
        for (int i = 0; i < markers.size(); i++) {
            if (auto* ref = GetRefFromHandle(markers[i].ref); ref) {
                if (IsMarkerBlocked(ref)) {
                    data.SetMember(std::to_string(i).c_str(), GFxValue(true));
                }
            }
        }
        _root.SetMember("BCD_filterList", data);
        _root.SetMember("BCD_isWhitelist", GFxValue(isWhitelist));
    }
};


void Inject() {
    auto ui = UI::GetSingleton();
    if (!ui) return;

    auto menu = ui->GetMenu<MapMenu>();
    if (!menu || !menu->uiMovie) {
        return;
    }
    auto movie = menu->uiMovie;

    GFxValue _root;
    movie->GetVariable(&_root, "_root");

    // the white/block list is setup using a call from the injected swf
    // because the at MenuOpenCloseEvent, the markers list is empty
    // it's all jank
    RE::GFxValue fn1;
    movie->CreateFunction(&fn1, new CreateFilterList());
    _root.SetMember("CreateFilterList", fn1);

    GFxValue args[2];
    args[0] = GFxValue("BCD");
    args[1] = GFxValue(8008);
    _root.Invoke("createEmptyMovieClip", nullptr, args, 2);
    if (movie->GetVariable(&_root, "_root.BCD")) {
        GFxValue args[1];
        args[0] = GFxValue("bettercarriage_inject.swf");
        _root.Invoke("loadMovie", nullptr, args, 1);
    }
}

class MyEventSink : public RE::BSTEventSink<MenuOpenCloseEvent> {
public:
    RE::BSEventNotifyControl ProcessEvent(const RE::MenuOpenCloseEvent* event,
                                          RE::BSTEventSource<RE::MenuOpenCloseEvent>* source) {
        if (event->menuName != MapMenu::MENU_NAME) return RE::BSEventNotifyControl::kContinue;
        if (event->opening) {
            Inject();
        } else {
            source->RemoveEventSink(this);
            filterList = nullptr;
        }
        return RE::BSEventNotifyControl::kContinue;
    }
};

RE::TESObjectREFR* GetMapMarkerByIndex(RE::StaticFunctionTag*, int a_index) {
    if (auto ui = UI::GetSingleton(); ui) {
        if (auto menu = ui->GetMenu<MapMenu>(); menu) {
            auto& markers = menu->GetRuntimeData2()->mapMarkers;
            if (a_index >= 0 && a_index < markers.size()) {
                return GetRefFromHandle(markers[a_index].ref);
            }
        }
    }

    return nullptr;
}

// this is awful and doesn't handle all edgecases
// like a cell having a teleport door to another interior cell
// or cells that are nested within multiple levels of interiors
RE::NiPoint3 GetExteriorPosition(RE::TESObjectREFR* ref) {
    if (!ref) return {};

    auto* cell = ref->GetParentCell();
    if (!cell || !cell->IsInteriorCell()) return ref->GetPosition();

    // Interior: find a door with teleport
    for (auto& handle : cell->GetRuntimeData().references) {
        auto door = handle.get();
        if (!door) continue;
        if (door->GetBaseObject()->GetFormType() != RE::FormType::Door) continue;
        auto teleportDoor = door->extraList.GetTeleportLinkedDoor();
        if (!teleportDoor) continue;
        return teleportDoor.get().get()->GetPosition();
    }

    return {};
}

float GetDistance(StaticFunctionTag*, RE::TESObjectREFR* ref1, RE::TESObjectREFR* ref2) {
    if (!ref1 || !ref2) return 0.0f;

    auto pos1 = GetExteriorPosition(ref1);
    auto pos2 = GetExteriorPosition(ref2);

    return pos1.GetDistance(pos2);
}

bool HasAnyKeywordInList(RE::StaticFunctionTag*, RE::TESForm* form, RE::BGSListForm* theList) {
    if (!form || !theList) {
        return false;
    }

    return form->HasKeywordInList(theList, false);
}

void AutoUnlockMarkers() {
    static bool bAdded = false;
    if (bAdded) return;
    bAdded = true;
    BGSListForm* list = TESForm::LookupByEditorID<BGSListForm>("BCD_AutoUnlockMarkers");
    if (!list) return;
    list->ForEachForm([](TESForm* form){
        if (form->Is(FormType::Reference)) {
            auto ref = form->As<TESObjectREFR>();
            auto* extra = ref->extraList.GetByType<ExtraMapMarker>();
            if (!extra) return BSContainer::ForEachResult::kContinue;
            extra->mapData->SetVisible(true);
        }
        return BSContainer::ForEachResult::kContinue;
    });
}

static MyEventSink theSink;

void OpenTheMap(StaticFunctionTag*, BGSListForm* a_whitelist = nullptr, bool a_isWhitelist = true) {
    AutoUnlockMarkers();
    CloseMenu(DialogueMenu::MENU_NAME);
    if (a_whitelist) {
        filterList = a_whitelist;
        isWhitelist = a_isWhitelist;
    }
    UI::GetSingleton()->AddEventSink(&theSink);
    OpenMenu(MapMenu::MENU_NAME);
}

void CloseTheMap(StaticFunctionTag*) { CloseMenu(MapMenu::MENU_NAME); }

bool PapyrusBinder(RE::BSScript::IVirtualMachine* vm) {
    std::string_view script = "BCD_Utils"sv;
    vm->RegisterFunction("GetMapMarkerByIndex", script, GetMapMarkerByIndex);
    vm->RegisterFunction("GetDistance", script, GetDistance);
    vm->RegisterFunction("HasAnyKeywordInList", script, HasAnyKeywordInList);
    vm->RegisterFunction("OpenTheMap", script, OpenTheMap);
    vm->RegisterFunction("CloseTheMap", script, CloseTheMap);

    return false;
}

void OnMessage(SKSE::MessagingInterface::Message* message) {
    if (message->type == SKSE::MessagingInterface::kDataLoaded) {
        OnlyDiscovered = TESForm::LookupByEditorID<TESGlobal>("BCD_OnlyDiscovered");
        OnlySettlement = TESForm::LookupByEditorID<TESGlobal>("BCD_OnlySettlement");
        AllowCleared = TESForm::LookupByEditorID<TESGlobal>("BCD_AllowCleared");
        SettlementLocKeywordsList = TESForm::LookupByEditorID<BGSListForm>("BCD_SettlementLocKeywordsList");
    }
}

SKSEPluginLoad(const SKSE::LoadInterface* skse) {
    SetupLog();
    SKSE::Init(skse);
    SKSE::GetPapyrusInterface()->Register(PapyrusBinder);
    SKSE::GetMessagingInterface()->RegisterListener(OnMessage);
    return true;
}
