const string PVM_JSON_URL = "https://raw.githubusercontent.com/Naxanria/tm_stuff/refs/heads/main/pvm_info.json";

string currentMapUid;
PVM@[] pvms;
PVM@ emptyPvm = PVM();
PVM@ currentPvm = emptyPvm;

bool fullReload = false;

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
            for (int i = 0; i < pvms.Length; i++)
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

                    for (int i = 0; i < pvms.Length; i++)
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

        for (int i = 0; i < pvms.Length; i++)
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
    auto _ = json["PVMS"];
    for (int i = 0; i < _.Length; i++)
    {
        PVM@ pvm = PVM::FromJson(_[i]);
        Logging::Info("Found pvm '" + pvm.Name + "' by '" + pvm.Author + "'" + (Logging::IsDebugLogLevel() ? " [" + pvm.Id + "]" : ""));
        pvms.InsertLast(pvm);
    }
}

void LoadPvmData()
{
    Logging::Info("Fetching pvm meta data from " + PVM_JSON_URL);

    Json::Value@ pvmMetaJson = API::GetJson(PVM_JSON_URL);
    LoadPvms(@pvmMetaJson);
    
    // load (enabled) pvm
    for (int i = 0; i < pvms.Length; i++)
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
}

void RenderMenu()
{
    if (UI::BeginMenu("\\$FC4" + Icons::Circle + "\\$z PVM"))
    {
        if (UI::MenuItem(Icons::ListAlt + " Show Overview"))
        {
            Setting::overview_show = true;
        }
        for (int i = 0; i < pvms.Length; i++)
        {
            PVM@ pvm = pvms[i];
            if (UI::BeginMenu(pvm.Name))
            {
                if (UI::MenuItem(Icons::Eye + " Show " + Utils::CheckIcon(Setting::PvmIsEnabled(pvm.Id))))
                {
                    Setting::PvmToggleEnabled(pvm.Id);
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

