namespace Overview
{
    void PlayMapAction(MapData@ map)
    {
        if (map is null) return;
        UI::ShowNotification("Loading map " + Text::OpenplanetFormatCodes(map.Name));
        map.LoadMap();
        if (Setting::overview_close_on_play)
        {
            Setting::overview_show = false;
        }
    }

    void OpenMapTmxAction(MapData@ map)
    {
        if (map is null) return;
        OpenBrowserURL("https://trackmania.exchange/mapshow/" + map.TmxId);
    }

    void HandleTableAction(const string &in actionId, MapData@ map)
    {
        if (map is null) return;

        if (actionId == "play")
        {
            PlayMapAction(map);
            return;
        }

        if (actionId == "tmx")
        {
            OpenMapTmxAction(map);
            return;
        }
    }

    void RenderMapTooltip(MapData@ map, PVM@ pvm)
    {
        if (map is null || pvm is null || !Setting::overview_tooltip_show)
        {
            return;
        }

        if (UI::IsItemHovered())
        {
            UI::BeginTooltip();

            if (Setting::overview_tooltip_thumbnail_show)
            {
                Images::CachedImage img = Images::GetFromTmxId(map.TmxId);
                if (img.texture !is null)
                {
                    UI::Image(img.texture, Utils::GetResized(img.texture.GetSize(), Setting::overview_tooltip_thumbnail_size));
                }
                else
                {
                    if (img.error)
                    {
                        if (img.unsupportedFormat)
                        {
                            UI::Text("\\$f00??");
                            UI::SameLine();
                        }
                        else if (img.notFound)
                        {
                            UI::Text("\\$f00404");
                            UI::SameLine();
                        }
                    }
                    string hg = Utils::GetHourGlass();
                    UI::Text(hg);
                }
            }

            float maxLabelWidth = 0.0f;
            for (uint i = 0; i < pvm.labels.Length; i++)
            {
                float width = UI::MeasureString(pvm.labels[i].GetFull()).x;
                if (width > maxLabelWidth)
                {
                    maxLabelWidth = width;
                }
            }

            float x = UI::GetCursorPos().x;
            for (int i = map.medalTimes.Length - 1; i >= -1; i--)
            {
                if (i >= int(pvm.labels.Length)) continue;
                if (!map.HasMedalTime(i)) continue;

                UI::SetCursorPosX(x);
                if (Setting::overview_tooltip_medals_show_label)
                {
                    UI::Text(pvm.labels[i].GetFull());
                }
                else
                {
                    UI::Text(pvm.labels[i].GetIcon());
                }
                UI::SameLine();
                if (Setting::overview_tooltip_medals_show_label)
                {
                    UI::SetCursorPosX(x + 10.0f + maxLabelWidth);
                }
                UI::Text(Utils::ReadableTime(map.GetMedalTime(i)));
            }

            UI::EndTooltip();
        }
    }

    enum DetailTab
    {
        Maps,
        Leaderboard
    }

    class OverviewTab
    {        
        private PVM@ pvm;
        private bool initialized = false;
        private StatContainer stats;
        private MappackOverview@ mapPackView;
        private LeaderboardOverview@ leaderboardView;

        private float maxLabelWidth = 10;
        private DetailTab detailTab = DetailTab::Maps;
        private bool detailTabSelectionPending = false;

        OverviewTab()
        { }

        OverviewTab(PVM@ pvm)
        {
            @this.pvm = pvm;
            stats = StatContainer(pvm);
            @mapPackView = MappackOverview(@pvm);
            @leaderboardView = LeaderboardOverview(@pvm);
        }

        string GetName()
        {
            return pvm.Name;
        }

        string GetAuthor()
        {
            return pvm.Author;
        }

        PVM@ GetPvm()
        {
            return @pvm;
        }

        void SelectDetailTab(bool leaderboard)
        {
            detailTab = leaderboard ? DetailTab::Leaderboard : DetailTab::Maps;
            detailTabSelectionPending = true;
        }

        private void Init()
        {
            Logging::Debug("Initializing pvm tab " + pvm.Name);
            if (initialized) return;

            stats.Reset();
            stats.Update();

            startnew(CoroutineFunc(this.SyncPbs));

            for (uint i = 0; i < pvm.labels.Length; i++)
            {
                float x = UI::MeasureString(pvm.labels[i].GetFull()).x;
                if (x > maxLabelWidth) maxLabelWidth = x;
            }

            initialized = true;
        }

        void Render()
        {
            if (!Setting::PvmIsEnabled(pvm.GetId())) return;

            if (!initialized)
            {
                Init();
                return;
            }

            if (uint(syncDone) < pvm.maps.Length && pvm.maps.Length > 0)
            {
                UI::ProgressBar(float(syncDone) / pvm.maps.Length, vec2(-1, 8));
            }

            // UI::Text(GetName() + " by " + GetAuthor());
            stats.Render();

            vec2 size = UI::GetWindowSize();
            vec2 pos = UI::GetWindowPos();
            
            string sheet = pvm.SheetUrl;
            string discord = pvm.DiscordUrl;

            float spacer = UI::MeasureString("a").x;
            int x = int(size.x);
            bool d = false;
            if (sheet != "")
            {
               x -= int(UI::MeasureString(Icons::Kenney::List).x);
               d = true;
            }
            if (discord != "")
            {
                x -= int(UI::MeasureString(Icons::Discord).x);
                d = true;
            }
            UI::SameLine();
            int spacerStringLength = int((x - UI::GetCursorPos().x) / spacer);
            UI::Text("   ");
            // UI::Text(spacerStringLength + " " + spacer + " " + x + " " + UI::GetCursorPos().x + " | " + (x - UI::GetCursorPos().x));
            if (d)
            {
                UI::SameLine();
                UI::Text(Text::Repeat(" ", spacerStringLength - 1));
                if (discord != "")
                {
                    UI::SameLine();
                    UI::Text(Icons::Discord);
                    UI::SetItemTooltip("Join the discord");
                    if (UI::IsItemClicked())
                    {
                        OpenBrowserURL(discord);
                    }
                }
                if (sheet != "")
                {
                    UI::SameLine();
                    UI::Text(Icons::Kenney::List);
                    UI::SetItemTooltip("Open the sheet");
                    if (UI::IsItemClicked())
                    {
                        OpenBrowserURL(sheet);
                    }
                }                
            }

            UI::BeginTabBar("pvm_detail_tab_bar_" + pvm.GetId());

            int mapsFlags = detailTabSelectionPending && detailTab == DetailTab::Maps
                ? int(UI::TabItemFlags::SetSelected)
                : int(UI::TabItemFlags::None);
            if (UI::BeginTabItem("Maps", mapsFlags))
            {
                detailTab = DetailTab::Maps;
                mapPackView.Render();
                UI::EndTabItem();
            }

            int leaderboardFlags = detailTabSelectionPending && detailTab == DetailTab::Leaderboard
                ? int(UI::TabItemFlags::SetSelected)
                : int(UI::TabItemFlags::None);
            if (UI::BeginTabItem("Leaderboard", leaderboardFlags))
            {
                detailTab = DetailTab::Leaderboard;
                if (!pvm.HasLeaderboardData() && !pvm.IsLoadingLeaderboard())
                {
                    pvm.LoadLeaderboard();
                }

                leaderboardView.Render();
                UI::EndTabItem();
            }

            UI::EndTabBar();
            detailTabSelectionPending = false;
        }


        private vec4 RenderMapInfo(MapData@ map)
        {
            UI::PushID(map.Uid);
            UI::TableNextRow();

            UI::TableNextColumn();
            vec2 startPos = UI::GetCursorScreenPos();
            UI::AlignTextToFramePadding();
            UI::Text(Text::OpenplanetFormatCodes(map.Name));

            UI::TableNextColumn();
            UI::Text("\\$777by\\$z " + map.Author);

            UI::TableNextColumn();
            UI::Text(map.PvmTier);

            UI::TableNextColumn();
            string timeText = map.pb <= 0 ? "\\$666 no pb\\$z" : Utils::ReadableTime(map.pb);
            UI::Text(GetMedalToShow(map) + "\\$z " + timeText);

            if (Setting::overview_table_show_tmx_id)
            {
                UI::TableNextColumn();
                UI::Text(map.TmxId);

                if (UI::IsItemClicked())
                {
                    IO::SetClipboard(map.TmxId);
                    UI::ShowNotification("Tmx Id for " + Text::OpenplanetFormatCodes(map.Name) + " [" + map.TmxId + "] copied to clipboard");
                }
            }

            UI::TableNextColumn();
            if (UI::Button("Play"))
            {   
                UI::ShowNotification("Loading map " + Text::OpenplanetFormatCodes(map.Name));
                map.LoadMap();
                if (Setting::overview_close_on_play)
                {
                    Setting::overview_show = false; 
                }
            }

            UI::TableNextColumn();
            if (UI::Button("TMX"))
            {
                OpenBrowserURL("https://trackmania.exchange/mapshow/" + map.TmxId);
            }
            vec2 endPos = UI::GetCursorScreenPos();
            endPos.x = endPos.x + UI::GetItemRect().z;
            UI::PopID();
            return vec4(startPos, endPos);
        }

        private bool Tooltip(MapData@ map, vec4 rowSize)
        {
            if (!Setting::overview_tooltip_show) return true;

            if (!Utils::IsInside(UI::GetMousePos(), rowSize)) return false;

            UI::BeginTooltip();

            vec2 cursorPos = UI::GetCursorPos();
            float x = cursorPos.x;
            
            if (Setting::overview_tooltip_thumbnail_show)
            {
                ShowThumbnail(map);
            }

            for (int i = map.medalTimes.Length - 1; i >= -1; i--)
            {
                if (i >= int(pvm.labels.Length)) continue;
                if (!map.HasMedalTime(i)) continue;
                
                UI::SetCursorPosX(x);
                if (Setting::overview_tooltip_medals_show_label)
                {
                    UI::Text(pvm.labels[i].GetFull());
                }
                else
                {
                    UI::Text(pvm.labels[i].GetIcon());
                }
                UI::SameLine();
                if (Setting::overview_tooltip_medals_show_label)
                {
                    UI::SetCursorPosX(x + 10 + maxLabelWidth);
                }
                UI::Text(Utils::ReadableTime(map.GetMedalTime(i)));
            }

            UI::EndTooltip();  

            return true;
        }

        private void ShowThumbnail(MapData@ map)
        {
            Images::CachedImage img = Images::GetFromTmxId(map.TmxId);
            if (img.texture !is null)
            {
                UI::Image(img.texture, Utils::GetResized(img.texture.GetSize(), Setting::overview_tooltip_thumbnail_size));
            }
            else
            {
                if (img.error)
                {
                    if (img.unsupportedFormat)
                    {   UI::Text("\\$f00??");
                        UI::SameLine();
                    }
                    else if (img.notFound)
                    {
                        UI::Text("\\$f00404");
                        UI::SameLine();
                    }
                }
                string hg = Utils::GetHourGlass();
                UI::Text(hg);
            }
        }

        private string GetMedalToShow(MapData@ map)
        {
            if (map.pb <= 0)
            {
                return Medals::Unfinished.GetIcon();
            }

            for (int i = map.medalTimes.Length - 1; i > -1; i--)
            {
                if (map.pb <= int(map.medalTimes[i]))
                {
                    return pvm.labels[i].GetIcon();
                }
            }

            return Medals::NoMedal.GetIcon();
        }

        private int syncDone = 0;
        private MapData@[] syncUpdating;

        void SyncPbs()
        {
            syncDone = 1;
            const uint max = 10;

            int i = 0;
            Logging::Debug("Syncing pvm " + pvm.Name + " pbs");
            while (i < int(pvm.maps.Length))
            {
                for (uint t = 0; t < syncUpdating.Length; t++)
                {
                    if (!syncUpdating[t].loadingPb)
                    {
                        syncUpdating.RemoveAt(t--);
                        syncDone++;
                        stats.Reset();
                        stats.Update();
                    }
                }

                if (syncUpdating.Length <= max)
                {
                    MapData@ map = pvm.maps[i++];
                    map.LoadPb();
                    syncUpdating.InsertLast(@map);
                }

                yield();
            }

            stats.Reset();
            stats.Update();
        }
    }
}