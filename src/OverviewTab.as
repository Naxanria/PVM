namespace Overview
{
    class OverviewTab
    {        
        private PVM@ pvm;
        private bool initialized = false;
        private StatContainer stats;

        private float maxLabelWidth = 10;

        OverviewTab()
        { }

        OverviewTab(PVM@ pvm)
        {
            @this.pvm = pvm;
            stats = StatContainer(pvm);
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

        private void Init()
        {
            Logging::Debug("Initializing pvm tab " + pvm.Name);
            if (initialized) return;

            stats.Reset();
            stats.Update();

            startnew(CoroutineFunc(this.SyncPbs));

            for (int i = 0; i < pvm.labels.Length; i++)
            {
                float x = Draw::MeasureString(pvm.labels[i].GetFull()).x;
                if (x > maxLabelWidth) maxLabelWidth = x;
            }

            initialized = true;
        }

        void Render()
        {
            if (!initialized)
            {
                Init();
                return;
            }

            if(syncDone < pvm.maps.Length && pvm.maps.Length > 0)
            {
                UI::ProgressBar(float(syncDone) / pvm.maps.Length, vec2(800, 8));
            }

            // UI::Text(GetName() + " by " + GetAuthor());
            stats.Render();

            vec2 size = UI::GetWindowSize();
            vec2 pos = UI::GetWindowPos();
            
            string sheet = pvm.SheetUrl;
            string discord = pvm.DiscordUrl;

            float spacer = Draw::MeasureString("a").x;
            int x = size.x;
            bool d = false;
            if (sheet != "")
            {
               x -= Draw::MeasureString(Icons::Kenney::List).x;
               d = true;
            }
            if (discord != "")
            {
                x -= Draw::MeasureString(Icons::Discord).x;
                d = true;
            }
            UI::SameLine();
            int spacerStringLength = int((x - UI::GetCursorPos().x) / spacer);
            UI::Text("   ");
            // UI::Text(spacerStringLength + " " + spacer + " " + x + " " + UI::GetCursorPos().x + " | " + (x - UI::GetCursorPos().x));
            if (d)
            {
                UI::SameLine();
                UI::Text(RepeatString(" ", spacerStringLength - 1));
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

            RenderSearch();

            if (UI::BeginTable("pvm_overview_table_" + GetName(), 6, UI::TableFlags::SizingFixedFit | UI::TableFlags::RowBg))
            {
                UI::TableSetupColumn("name", UI::TableColumnFlags::WidthFixed, widthName);
                UI::TableSetupColumn("author", UI::TableColumnFlags::WidthStretch);
                UI::TableSetupColumn("grade", UI::TableColumnFlags::WidthFixed, widthGrade);
                UI::TableSetupColumn("medal", UI::TableColumnFlags::WidthFixed, widthMedal + widthTime + 1);
                //UI::TableSetupColumn("time", UI::TableColumnFlags::WidthFixed, timeWidth);
                UI::TableSetupColumn("playBtn");
                UI::TableSetupColumn("tmxBtn");
                bool shownTooltip = false;

                UI::TableNextRow();
                UI::TableNextColumn();
                SortLabel("Name", SortMode::NAME, SortMode::NAME_INVERTED);
                UI::TableNextColumn();
                SortLabel("Author", SortMode::AUTHOR, SortMode::AUTHOR_INVERTED);
                UI::TableNextColumn();
                UI::Text("Grade");
                if (UI::IsItemClicked())
                {
                    UpdateSortMode(SortMode::DEFAULT);
                }
                UI::TableNextColumn();
                SortLabel("Time", SortMode::TIME, SortMode::TIME_INVERTED);
                UI::TableNextColumn();
                UI::Text("");
                UI::TableNextColumn();
                UI::Text("");
                
                MapData@[] mapList = pvm.GetSortedList();

                UI::ListClipper clip(mapList.Length);
                while (clip.Step())
                {
                    for (int i = clip.DisplayStart; i < clip.DisplayEnd && i < mapList.Length; i++)
                    {
                        vec4 area = RenderMapInfo(mapList[i]);

                        if (!shownTooltip) shownTooltip = Tooltip(mapList[i], area);
                        //UI::DrawList::AddRect(area, vec4(1, 0, 0, 1));
                    }
                }
                UI::EndTable();
            }
        }

        string RepeatString(string s, int repeat)
        {
            string r = "";
            for (int i = 0; i < repeat; i++)
            {
                r += s;
            }
            return r;
        }

        string search = "";


        private void RenderSearch()
        {
            UI::BeginGroup();
            UI::Text("Search:");
            UI::SameLine();

            string oldsearch = search;

            UI::SetNextItemWidth(128);
            search = UI::InputText("##", oldsearch);

            if (search != oldsearch)
            {
                pvm.UpdateSearch(search);
            }
            UI::EndGroup();
        }

        private void SortLabel(string name, SortMode mode, SortMode inverted)
        {
            UI::Text(name + (pvm.GetSortMode() == mode ? Icons::CaretDown : (pvm.GetSortMode() == inverted ? Icons::CaretUp : "")));
            if (UI::IsItemClicked())
            {
                if (pvm.GetSortMode() == mode)
                {
                    UpdateSortMode(inverted);
                }
                else if (pvm.GetSortMode() == inverted)
                {
                    UpdateSortMode(SortMode::DEFAULT);
                }
                else
                {
                    UpdateSortMode(mode);
                }
            }
        }

        void UpdateSortMode(SortMode newMode)
        {
            if (pvm.GetSortMode() == newMode) return;

            pvm.UpdateSortMode(newMode);
        }

        private vec4 RenderMapInfo(MapData@ map)
        {
            UI::PushID(map.Uid);
            UI::TableNextRow();


            UI::TableNextColumn();
            vec2 startPos = UI::GetCursorScreenPos();
            UI::Text(map.Name);

            UI::TableNextColumn();
            UI::Text("\\$777by\\$z " + map.Author);

            UI::TableNextColumn();
            UI::Text(map.PvmGrade);

            UI::TableNextColumn();
            string timeText = map.pb <= 0 ? "\\$666 no pb\\$z" : Utils::ReadableTime(map.pb);
            UI::Text(GetMedalToShow(map) + "\\$z " + timeText);

            UI::TableNextColumn();
            if (UI::Button("Play"))
            {   
                UI::ShowNotification("Loading map " + map.Name);
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
                if (i >= pvm.labels.Length) continue;
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
                if (map.pb <= map.medalTimes[i])
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
            int max = 10;

            int i = 0;
            Logging::Debug("Syncing pvm " + pvm.Name + " pbs");
            while (i < pvm.maps.Length)
            {
                for (int t = 0; t < syncUpdating.Length; t++)
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