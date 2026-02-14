#include "logger.h"

bool iequals(const std::string& a, const std::string& b) {
    if (a.size() != b.size()) return false;
    return std::equal(a.begin(), a.end(), b.begin(),
                      [](char c1, char c2) { return std::tolower(c1) == std::tolower(c2); });
}

RE::TESObjectREFR* GetMapMarkerByName(RE::StaticFunctionTag*, std::string a_name) {
    auto* pc = RE::PlayerCharacter::GetSingleton();
    auto& data = pc->GetPlayerRuntimeData();
    auto& mapMarkers = data.currentMapMarkers;

    for (auto& mapMarker : mapMarkers) {
        const auto refr = mapMarker.get().get();
        const auto marker = refr ? refr->extraList.GetByType<RE::ExtraMapMarker>() : nullptr;
        if (marker && marker->mapData && iequals(marker->mapData->locationName.GetFullName(), a_name)) {
            return refr;
        }
    }

    return nullptr;
}

float GetDistance(RE::StaticFunctionTag*, RE::TESObjectREFR* ref1, RE::TESObjectREFR* ref2) {
    if (!ref1 || !ref2) {
        return 0;
    }

    return ref1->GetPosition().GetSquaredDistance(ref2->GetPosition()) / 1000;
}

bool HasAnyKeywordInList(RE::StaticFunctionTag*, RE::TESForm* form, RE::BGSListForm* theList) {
    if (!form || !theList) {
        return false;
    }

    return form->HasKeywordInList(theList, false);
}

bool PapyrusBinder(RE::BSScript::IVirtualMachine* vm) {
    vm->RegisterFunction("GetMapMarkerByName", "BCD_Utils", GetMapMarkerByName);
    vm->RegisterFunction("GetDistance", "BCD_Utils", GetDistance);
    vm->RegisterFunction("HasAnyKeywordInList", "BCD_Utils", HasAnyKeywordInList);

    return false;
}

SKSEPluginLoad(const SKSE::LoadInterface *skse) {
    SetupLog();
    SKSE::Init(skse);
    SKSE::GetPapyrusInterface()->Register(PapyrusBinder);
    return true;
}
