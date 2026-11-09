namespace Overview
{
    class MappackOverview : OverviewTabContent
    {
        private PVM@ pvm;

        MappackOverview(PVM@ pvm)
        {
            @this.pvm = pvm;
        }

        void Render()
        {
            if (RenderSearch("mappack_search_" + pvm.GetId()))
            {
                pvm.UpdateSearch(GetSearch());
            }

            MapData@[] mapList = pvm.GetSortedList();
            RenderSearchResultCount(mapList.Length);
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
                        if (DrawSortHeader(label, currentMapSortMode == ascMode, currentMapSortMode == descMode))
                        {
                            HandleSortAction(ascMode, descMode, currentMapSortMode);
                        }
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
                    UI::TableSetBgColor(UI::TableBgTarget::RowBg0, GetRowColor(map.TierColor.Trim(), i));

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

    }
}
