const string PVM_MAPPACK_URL = "https://pvms.club/api/mappacks";

string currentMapUid;
PVM@[] pvms;
PVM@ emptyPvm = PVM();
PVM@ currentPvm = emptyPvm;

bool fullReload = false;

#if DEPENDENCY_ULTIMATEMEDALSEXTENDED
array<string> umeMedalNames = {};
bool umeRegistered = false;

class PvmUmeMedal : UltimateMedalsExtended::IMedal
{
    private string medalName;
    private string medalIcon;
    private int goalId;
    private string currentUid;

    PvmUmeMedal(const string &in medalName, const string &in medalIcon, int goalId)
    {
        this.medalName = medalName;
        this.medalIcon = medalIcon;
        this.goalId = goalId;
        this.currentUid = "";
    }

    UltimateMedalsExtended::Config GetConfig() override
    {
        UltimateMedalsExtended::Config config;
        config.defaultName = medalName;
        config.icon = medalIcon;
        return config;
    }

    void UpdateMedal(const string &in uid) override
    {
        currentUid = uid;
    }

    bool HasMedalTime(const string &in uid) override
    {
        if (uid == "") return false;
        PVM@ pvm = GetPvmByMapUid(uid);
        if (pvm is null || pvm.currentMap is null || pvm.currentMap.Uid != uid) return false;
        return pvm.currentMap.GetMedalTime(goalId) > 0;
    }

    uint GetMedalTime() override
    {
        if (currentUid == "") return 0;
        PVM@ pvm = GetPvmByMapUid(currentUid);
        if (pvm is null || pvm.currentMap is null) return 0;
        return pvm.currentMap.GetMedalTime(goalId);
    }
}

PVM@ GetPvmByMapUid(const string &in uid)
{
    for (uint i = 0; i < pvms.Length; i++)
    {
        if (pvms[i].ContainsMap(uid))
        {
            return pvms[i];
        }
    }
    return null;
}

void UnregisterUmeMedals()
{
    for (uint i = 0; i < umeMedalNames.Length; i++)
    {
        UltimateMedalsExtended::RemoveMedal(umeMedalNames[i]);
    }

    umeMedalNames.RemoveRange(0, umeMedalNames.Length);
    umeRegistered = false;
}

void RegisterUmeMedals()
{
    if (umeRegistered) return;

    UnregisterUmeMedals();

    for (uint i = 0; i < pvms.Length; i++)
    {
        PVM@ pvm = pvms[i];
        for (uint j = 0; j < pvm.labels.Length; j++)
        {
            string medalName = pvm.Name + " - " + pvm.labels[j].GetName();
            UltimateMedalsExtended::AddMedal(PvmUmeMedal(medalName, pvm.labels[j].GetIcon(), pvm.labels[j].id));
            umeMedalNames.InsertLast(medalName);
        }
    }

    umeRegistered = true;
}
#endif

void Main()
{
    auto app = cast<CTrackMania>(GetApp());
    auto network = cast<CTrackManiaNetwork>(app.Network);

    // clearing finished tasks
    startnew(API::ClearTaskCoroutine);

    LoadPvmData();

    while (true)
    {
        if (fullReload)
        {
            for (uint i = 0; i < pvms.Length; i++)
            {
                pvms[i].ReloadPvmJson();                
            }
            pvms.RemoveRange(0, pvms.Length);
            @currentPvm = emptyPvm;
            currentMapUid = "";

            LoadPvmData();

            UI::ShowNotification("Reload done");

            fullReload = false;
            continue;
        }

        auto map = app.RootMap;

        if (map !is null && map.MapInfo.MapUid != "" && app.Editor is null)
        {
            if (network.ClientManiaAppPlayground !is null)
            {
                if (currentMapUid != map.MapInfo.MapUid) 
                {
                    currentMapUid = map.MapInfo.MapUid;

                    Logging::Info("Map swapped! " + currentMapUid);
                    bool foundPvm = false;

                    for (uint i = 0; i < pvms.Length; i++)
                    {
                        PVM@ pvm = pvms[i];
                        if (pvm.ContainsMap(currentMapUid))
                        {
                            @currentPvm = pvm;
                            currentPvm.UpdateMap(currentMapUid);
                            foundPvm = true;
                            break;
                        }
                    }

                    if (!foundPvm)
                    {
                        @currentPvm = emptyPvm;
                    }

                    if (!currentPvm.IsEmpty() && currentPvm.currentMap.Uid != currentMapUid)
                    {
                        @currentPvm = emptyPvm;
                    }
                }
                if (!currentPvm.IsEmpty() && currentMapUid != currentPvm.currentMap.Uid)
                {
                    @currentPvm = emptyPvm;
                }
                if (!currentPvm.IsEmpty())
                {
                    auto userMgr = network.ClientManiaAppPlayground.UserMgr;
                    MwId userId;

                    if (userMgr.Users.Length > 0)
                    {
                        userId = userMgr.Users[0].Id;
                    }
                    else
                    {
                        userId.Value = uint(-1);
                    }

                    auto scoreMgr = network.ClientManiaAppPlayground.ScoreMgr;
                    int pb = scoreMgr.Map_GetRecord_v2(userId, currentMapUid, "PersonalBest", "", "TimeAttack", "");

                    currentPvm.UpdatePb(pb);
                    //currentPvm.currentMap.SetPb(pb);
                    //Logging::Info("New pb: " + Utils::ReadableTime(pb) + " [" + pb + "]");
                }
            }
            else
            {
                currentPvm.UpdateMap("");
                @currentPvm = emptyPvm;
            }
        }
        else
        {
            currentMapUid = "";
            currentPvm.UpdateMap("");
            @currentPvm = emptyPvm;
        }

        for (uint i = 0; i < pvms.Length; i++)
        {
            if (pvms[i].ReloadRequested)
            {
                pvms[i].LoadPvmJson();                
            }
        }

        yield(5);
    }
}

void LoadPvms(Json::Value@ json)
{
    if (json.GetType() != Json::Type::Array) {
        Logging::Error("Invalid JSON format for PVMs");
        return;
    }

    auto _ = json;
    for (uint i = 0; i < _.Length; i++)
    {
        PVM@ pvm = PVM::FromJson(_[i]);
        Logging::Info("Found pvm '" + pvm.Name + "' by '" + pvm.Author + "'" + (Logging::IsDebugLogLevel() ? " [" + pvm.Id + "]" : ""));
        pvms.InsertLast(pvm);
    }
}

void LoadPvmData()
{
#if DEPENDENCY_ULTIMATEMEDALSEXTENDED
    if (umeRegistered)
    {
        UnregisterUmeMedals();
    }
#endif

    Logging::Info("Fetching pvm map pack data from " + PVM_MAPPACK_URL);

    Json::Value@ pvmMappackJson;
    int attempts = 0;

    while (attempts <= 4) {
        @pvmMappackJson = API::GetJson(PVM_MAPPACK_URL);

        if (pvmMappackJson.GetType() == Json::Type::Array) {
            break;
        }

        attempts++;

        if (attempts == 4) {
            Logging::Error("Failed to fetch Mappack JSON after 5 attempts!", true);
            return;
        }

        sleep(2000);
    }

    LoadPvms(@pvmMappackJson);
    
    // load (enabled) pvm
    for (uint i = 0; i < pvms.Length; i++)
    {
        PVM@ pvm = pvms[i];
        pvms[i].LoadPvmJson();
        if (Logging::IsDebugLogLevel())
        {
            Logging::Debug("Loaded pvm '" + pvm.Name + "[" + pvm.Id + "]' with " + pvm.maps.Length + " maps");
        }
        else 
        { 
            Logging::Info("Loaded pvm '" + pvm.Name + "' with " + pvm.maps.Length + " maps");
        }
    } 

    Overview::Reload();
    Setting::Init();
    Setting::FinalizeLoadingPvmSettings();

#if DEPENDENCY_ULTIMATEMEDALSEXTENDED
    RegisterUmeMedals();
#endif
}

void RenderMenu()
{
    if (UI::BeginMenu("\\$FC4" + Icons::Circle + "\\$z PVM"))
    {
        if (UI::MenuItem(Icons::ListAlt + " Show Overview", "", Setting::overview_show))
        {
            Setting::overview_show = !Setting::overview_show;
        }
        for (uint i = 0; i < pvms.Length; i++)
        {
            PVM@ pvm = pvms[i];
            if (!Setting::PvmIsEnabled(pvm.Id)) continue;
            if (UI::BeginMenu(pvm.Name))
            {
                if (UI::MenuItem(Icons::Eye + " Show " + Utils::CheckIcon(Setting::PvmIsEnabled(pvm.Id))))
                {
                    Setting::PvmToggleEnabled(pvm.Id);
                    if (!Setting::PvmIsEnabled(pvm.Id))
                    {
                        Overview::needsRefresh = true;
                    }
                }

                // todo: add reload
                // if(UI::MenuItem("\\$0f0" + Icons::Recycle + "\\$z Reload"))
                // {
                //     if (!pvm.Fetching)
                //     {
                //         UI::ShowNotification("Reloading the " + pvm.Name + " pvm");
                //         pvm.ReloadPvmJson();
                //     }
                // }

                if (pvm.SheetUrl != "")
                {
                    if (UI::MenuItem("\\$999" + Icons::Kenney::List + " \\$zOpen pvm sheet"))
                    {                        
                        OpenBrowserURL(pvm.SheetUrl);
                    }
                }
                UI::EndMenu();
            }
        }

        // todo: add full reload
        // if (UI::MenuItem("\\$0f0" + Icons::Recycle + "\\$z Full Reload"))
        // {
        //     fullReload = true;
        //     UI::ShowNotification("Fully reloading pvm!");
        // }
        UI::EndMenu();
    }
}

void Render()
{
    if (fullReload) return;



    if (Setting::pvm_show && !currentPvm.IsEmpty() && currentPvm.enabled)
    {
        currentPvm.Render();
    }

    if (Setting::overview_show)
    {
        Overview::Render();
    }
}

void OnSettingsLoad(Settings::Section& section)
{
    Setting::OnSettingsLoad(section);
}

void OnSettingsSave(Settings::Section& section)
{
    Setting::OnSettingsSave(section);
}

void OnDestroyed()
{
#if DEPENDENCY_ULTIMATEMEDALSEXTENDED
    UnregisterUmeMedals();
#endif
}

bool keyHeld = false;
void OnKeyPress(bool down, VirtualKey key)
{
    if (!keyHeld)
    {
        if (key == Setting::overview_hotkey_show)
        {
            Setting::overview_show = !Setting::overview_show;
        }
        if (key == Setting::pvm_window_hotkey_show)
        {
            Setting::pvm_show = !Setting::pvm_show;
        }
    }

    keyHeld = down;
}

