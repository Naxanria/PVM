const string PVM_MAPPACK_URL = "https://pvms.club/api/mappacks";

string currentMapUid;
PVM@[] pvms;
PVM@ emptyPvm = PVM();
PVM@ currentPvm = emptyPvm;

bool fullReload = false;

void ResolveCurrentPvmForUid(const string &in uid)
{
    currentMapUid = uid;
    @currentPvm = emptyPvm;

    if (uid == "")
    {
        return;
    }

    for (uint i = 0; i < pvms.Length; i++)
    {
        PVM@ pvm = pvms[i];
        if (pvm.ContainsMap(uid))
        {
            @currentPvm = pvm;
            currentPvm.UpdateMap(uid);
            return;
        }
    }
}

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
                ResolveCurrentPvmForUid(map.MapInfo.MapUid);

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
                }
            }
            else
            {
                ResolveCurrentPvmForUid("");
            }
        }
        else
        {
            ResolveCurrentPvmForUid("");
        }

        SyncUmeState();

        for (uint i = 0; i < pvms.Length; i++)
        {
            if (pvms[i].ReloadRequested)
            {
                if (pvms[i].LoadPvmJson())
                {
                    Overview::Reload();
                    Logging::Info("PVM " + pvms[i].Name + " by " + pvms[i].Author);
                }
            }
        }

        yield(5);
    }
}

void LoadPvms(Json::Value@ json)
{
    if (json.GetType() != Json::Type::Array) {
        Logging::Error("PVM mappacks [all] invalid JSON format");
        return;
    }

    auto _ = json;
    for (uint i = 0; i < _.Length; i++)
    {
        PVM@ pvm = PVM::FromJson(_[i]);
        Logging::Debug(pvm.GetLogIdentity() + " found in mappack list; author=" + pvm.Author);
        pvms.InsertLast(pvm);
    }
}

void LoadPvmData()
{
#if DEPENDENCY_ULTIMATEMEDALSEXTENDED
    if (umeRegistered)
    {
        OnDestroyedUME();
    }
#endif

    Logging::Info("Loading PVM mappacks [all]");

    Json::Value@ pvmMappackJson;
    int attempts = 0;

    while (attempts <= 4) {
        @pvmMappackJson = API::GetJson(PVM_MAPPACK_URL);

        if (pvmMappackJson.GetType() == Json::Type::Array) {
            break;
        }

        attempts++;

        if (attempts == 4) {
            Logging::Error("PVM mappacks [all] failed to load after 5 attempts", true);
            return;
        }

        sleep(2000);
    }

    LoadPvms(@pvmMappackJson);
    Logging::Info("Loaded PVM mappacks [all] successfully");
    
    // load (enabled) pvm
    for (uint i = 0; i < pvms.Length; i++)
    {
        PVM@ pvm = pvms[i];
        bool loaded = pvms[i].LoadPvmJson();
        if (!loaded) continue;

        Logging::Info("PVM " + pvm.Name + " by " + pvm.Author);
    } 

    Overview::Reload();
    Setting::Init();
    Setting::FinalizeLoadingPvmSettings();

    SyncUmeState();
}

void RenderMenu()
{
    if (UI::BeginMenu("\\$FC4" + Icons::Circle + "\\$z PVM"))
    {
        if (UI::MenuItem(Icons::ListAlt + " Show Overview", "", Setting::overview_show))
        {
            Setting::overview_show = !Setting::overview_show;
        }
        if (UI::MenuItem(Icons::Recycle + " Reload all mappacks", "", fullReload, !fullReload))
        {
            fullReload = true;
            UI::ShowNotification("Reloading all PVM mappacks");
        }
        for (uint i = 0; i < pvms.Length; i++)
        {
            PVM@ pvm = pvms[i];
            if (!Setting::PvmIsEnabled(pvm.Id)) continue;
            if (UI::BeginMenu(pvm.Name))
            {
                if (UI::MenuItem(Icons::ListAlt + " Show mappack"))
                {
                    Overview::OpenPvm(pvm.Id, false);
                }
                if (UI::MenuItem(Icons::ListAlt + " Show leaderboard"))
                {
                    Overview::OpenPvm(pvm.Id, true);
                }
                if (UI::MenuItem(Icons::Recycle + " Reload mappack", "", false, !pvm.Fetching && !pvm.ReloadRequested))
                {
                    pvm.ReloadPvmJson();
                    UI::ShowNotification("Reloading " + pvm.Name);
                }

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

        UI::EndMenu();
    }
}

void Render()
{
    if (fullReload) return;

#if DEPENDENCY_ULTIMATEMEDALSEXTENDED
    bool shouldHidePvmWidget = Setting::pvm_hide_while_ume_active && umeRegistered;
#else
    bool shouldHidePvmWidget = false;
#endif

    if (!shouldHidePvmWidget && Setting::pvm_show && !currentPvm.IsEmpty() && currentPvm.enabled)
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
    OnDestroyedUME();
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

