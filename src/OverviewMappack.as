namespace Overview
{
    class MappackOverview
    {
        private PVM@ pvm;
        private string search = "";
        private int foundCount = 0;

        MappackOverview(PVM@ pvm)
        {
            @this.pvm = pvm;
        }

        void Render()
        {
            RenderSearch();

            MapData@[] mapList = pvm.GetSortedList();
            string tableId = "pvm_overview_table_" + pvm.GetId();

            UI::TableFlags mapFlags = UI::TableFlags(uint(UI::TableFlags::SizingFixedFit) | uint(UI::TableFlags::RowBg));
            MapSortMode currentMapSortMode = pvm.GetMapSortMode();

            if (UI::BeginTable(tableId, 7 + (Setting::overview_table_show_tmx_id ? 1 : 0), mapFlags))
            {
                UI::TableSetupColumn("Name", UI::TableColumnFlags::WidthFixed, Overview::widthName);
                UI::TableSetupColumn("Author", UI::TableColumnFlags::WidthStretch, 0.0f);
                UI::TableSetupColumn("Tier", UI::TableColumnFlags::WidthFixed, Overview::widthTier);
                UI::TableSetupColumn("Time", UI::TableColumnFlags::WidthFixed, Overview::widthMedal + Overview::widthTime + 1);
                if (Setting::overview_table_show_tmx_id)
                {
                    UI::TableSetupColumn("Tmx Id", UI::TableColumnFlags::WidthFixed, Overview::widthTmxId);
                }
                UI::TableSetupColumn("", UI::TableColumnFlags::WidthFixed, 56.0f);
                UI::TableSetupColumn("", UI::TableColumnFlags::WidthFixed, 56.0f);

                UI::TableNextRow();
                uint columnCount = 7 + (Setting::overview_table_show_tmx_id ? 1 : 0);
                for (uint i = 0; i < columnCount; i++)
                {
                    UI::TableNextColumn();
                    string label = "";
                    bool isSortable = false;
                    MapSortMode ascMode = MapSortMode::NAME_ASC;
                    MapSortMode descMode = MapSortMode::NAME_DESC;

                    if (i == 0)
                    {
                        label = "Name";
                        isSortable = true;
                        ascMode = MapSortMode::NAME_ASC;
                        descMode = MapSortMode::NAME_DESC;
                    }
                    else if (i == 1)
                    {
                        label = "Author";
                        isSortable = true;
                        ascMode = MapSortMode::AUTHOR_ASC;
                        descMode = MapSortMode::AUTHOR_DESC;
                    }
                    else if (i == 2)
                    {
                        label = "Tier";
                        isSortable = true;
                        ascMode = MapSortMode::TIER_ASC;
                        descMode = MapSortMode::TIER_DESC;
                    }
                    else if (i == 3)
                    {
                        label = "Time";
                        isSortable = true;
                        ascMode = MapSortMode::TIME_ASC;
                        descMode = MapSortMode::TIME_DESC;
                    }
                    else if (i == 4 && Setting::overview_table_show_tmx_id)
                    {
                        label = "Tmx Id";
                    }

                    if (isSortable)
                    {
                        DrawMapSortHeader(label, ascMode, descMode, currentMapSortMode);
                    }
                    else
                    {
                        UI::Text(label);
                    }
                }

                for (uint i = 0; i < mapList.Length; i++)
                {
                    MapData@ map = mapList[i];
                    if (map is null) continue;

                    UI::TableNextRow();
                    UI::TableSetBgColor(UI::TableBgTarget::RowBg0, GetMapRowColor(map, i));

                    UI::TableNextColumn();
                    UI::Text(Text::OpenplanetFormatCodes(map.Name));
                    if (UI::IsItemHovered()) Overview::RenderMapTooltip(map, pvm);

                    UI::TableNextColumn();
                    UI::Text("\\$777by\\$z " + map.Author);

                    UI::TableNextColumn();
                    UI::Text(map.PvmTier);
                    if (UI::IsItemHovered())
                    {
                        UI::BeginTooltip();
                        UI::Text("Points reward: " + map.TierPoints);
                        UI::EndTooltip();
                    }

                    UI::TableNextColumn();
                    string timeText = map.pb <= 0 ? "\\$666 no pb\\$z" : Utils::ReadableTime(map.pb);
                    UI::Text(GetMedalToShow(map) + "\\$z " + timeText);

                    if (Setting::overview_table_show_tmx_id)
                    {
                        UI::TableNextColumn();
                        UI::Text(map.TmxId);
                    }

                    UI::TableNextColumn();
                    UI::PushID(map.Uid + "_play");
                    if (UI::Button("Play"))
                    {
                        Overview::HandleTableAction("play", map);
                    }
                    UI::PopID();

                    UI::TableNextColumn();
                    UI::PushID(map.Uid + "_tmx");
                    if (UI::Button("TMX"))
                    {
                        Overview::HandleTableAction("tmx", map);
                    }
                    UI::PopID();
                }

                UI::EndTable();
            }
        }

        private void RenderSearch()
        {
            UI::BeginGroup();
            UI::AlignTextToFramePadding();
            UI::Text("Search:");
            UI::SameLine();

            string oldsearch = search;
            UI::SetNextItemWidth(128);
            search = UI::InputText("##", oldsearch, UI::InputTextFlags::EscapeClearsAll);

            if (search != oldsearch)
            {
                pvm.UpdateSearch(search);
                if (search != "")
                {
                    foundCount = pvm.GetSortedList().Length;
                }
            }

            if (search != "")
            {
                UI::SameLine();
                string res = "result";
                if (foundCount != 1) res = "results";
                UI::Text(foundCount + " " + res);
            }

            UI::EndGroup();
        }

        private void DrawMapSortHeader(const string &in label, MapSortMode ascMode, MapSortMode descMode, MapSortMode currentMode)
        {
            string display = label;
            if (currentMode == ascMode)
            {
                display += Icons::CaretUp;
            }
            else if (currentMode == descMode)
            {
                display += Icons::CaretDown;
            }

            UI::Text(display);
            if (UI::IsItemClicked())
            {
                HandleSortAction(ascMode, descMode, currentMode);
            }
        }

        private void HandleSortAction(MapSortMode ascMode, MapSortMode descMode, MapSortMode currentMode)
        {
            if (currentMode == ascMode)
            {
                pvm.UpdateMapSortMode(descMode);
                return;
            }

            if (currentMode == descMode)
            {
                pvm.UpdateMapSortMode(ascMode);
                return;
            }

            pvm.UpdateMapSortMode(ascMode);
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

        private vec4 GetMapRowColor(MapData@ map, uint rowIndex)
        {
            vec4 base = vec4(0.10f, 0.10f, 0.10f, 0.06f);
            string color = map is null ? "" : map.TierColor.Trim();

            if (color != "")
            {
                if (color.Length > 0 && color.SubStr(0, 1) == "#")
                {
                    color = color.SubStr(1, color.Length - 1);
                }

                if (color.Length > 0 && color.SubStr(0, 1) == "$")
                {
                    color = color.SubStr(1, color.Length - 1);
                }

                if (color.Length == 3)
                {
                    color = color.SubStr(0, 1) + color.SubStr(0, 1) +
                        color.SubStr(1, 1) + color.SubStr(1, 1) +
                        color.SubStr(2, 1) + color.SubStr(2, 1);
                }

                if (color.Length == 6)
                {
                    int r = ParseHexByte(color.SubStr(0, 2));
                    int g = ParseHexByte(color.SubStr(2, 2));
                    int b = ParseHexByte(color.SubStr(4, 2));
                    base = vec4(float(r) / 255.0f, float(g) / 255.0f, float(b) / 255.0f, 0.12f);
                }
            }

            float stripe = rowIndex % 2 == 0 ? 0.68f : 1.12f;
            float r = base.x * stripe;
            float g = base.y * stripe;
            float b = base.z * stripe;
            float a = rowIndex % 2 == 0 ? 0.08f : 0.10f;

            if (r > 1.0f) r = 1.0f;
            if (g > 1.0f) g = 1.0f;
            if (b > 1.0f) b = 1.0f;
            if (a > 0.12f) a = 0.12f;

            return vec4(r, g, b, a);
        }

        private int ParseHexByte(const string &in hex)
        {
            int value = 0;
            for (int i = 0; i < hex.Length; i++)
            {
                string c = hex.SubStr(i, 1).ToUpper();
                if (c == "0") value = value * 16 + 0;
                else if (c == "1") value = value * 16 + 1;
                else if (c == "2") value = value * 16 + 2;
                else if (c == "3") value = value * 16 + 3;
                else if (c == "4") value = value * 16 + 4;
                else if (c == "5") value = value * 16 + 5;
                else if (c == "6") value = value * 16 + 6;
                else if (c == "7") value = value * 16 + 7;
                else if (c == "8") value = value * 16 + 8;
                else if (c == "9") value = value * 16 + 9;
                else if (c == "A") value = value * 16 + 10;
                else if (c == "B") value = value * 16 + 11;
                else if (c == "C") value = value * 16 + 12;
                else if (c == "D") value = value * 16 + 13;
                else if (c == "E") value = value * 16 + 14;
                else if (c == "F") value = value * 16 + 15;
            }
            return value;
        }

    }
}
