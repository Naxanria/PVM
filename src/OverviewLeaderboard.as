namespace Overview
{
    class LeaderboardOverview
    {
        private PVM@ pvm;
        private string search = "";

        LeaderboardOverview(PVM@ pvm)
        {
            @this.pvm = pvm;
        }

        void Render()
        {
            if (pvm.IsLoadingLeaderboard())
            {
                UI::Text("Loading leaderboard...");
                return;
            }

            UI::BeginGroup();
            UI::AlignTextToFramePadding();
            UI::Text("Search:");
            UI::SameLine();
            string oldSearch = search;
            UI::SetNextItemWidth(180.0f);
            search = UI::InputText("##leaderboard_search", oldSearch, UI::InputTextFlags::EscapeClearsAll);
            if (search != oldSearch)
            {
                pvm.UpdateLeaderboardSearch(search);
            }
            UI::EndGroup();

            LeaderboardEntry@[] entries = pvm.GetSortedLeaderboardEntries();
            string tableId = "pvm_leaderboard_" + pvm.GetId();

            if (entries.Length == 0)
            {
                if (UI::Button("Load leaderboard"))
                {
                    pvm.LoadLeaderboard();
                }
                return;
            }

            LeaderboardSortMode currentLeaderboardSortMode = pvm.GetLeaderboardSortMode();
            UI::TableFlags leaderboardFlags = UI::TableFlags(uint(UI::TableFlags::SizingStretchProp) | uint(UI::TableFlags::RowBg));

            if (UI::BeginTable(tableId, 6, leaderboardFlags))
            {
                UI::TableSetupColumn("Position", UI::TableColumnFlags::WidthFixed, 64.0f);
                UI::TableSetupColumn("Player", UI::TableColumnFlags::WidthStretch, 0.0f);
                UI::TableSetupColumn("Rank", UI::TableColumnFlags::WidthFixed, 110.0f);
                UI::TableSetupColumn("Points", UI::TableColumnFlags::WidthFixed, 110.0f);
                UI::TableSetupColumn("Completed", UI::TableColumnFlags::WidthFixed, 90.0f);
                UI::TableSetupColumn("Best", UI::TableColumnFlags::WidthFixed, 72.0f);

                UI::TableNextRow();
                for (uint i = 0; i < 6; i++)
                {
                    UI::TableNextColumn();
                    string label = "";
                    bool isSortable = false;
                    LeaderboardSortMode ascMode = LeaderboardSortMode::PLAYER_ASC;
                    LeaderboardSortMode descMode = LeaderboardSortMode::PLAYER_DESC;

                    if (i == 0)
                    {
                        label = "Position";
                        isSortable = true;
                        ascMode = LeaderboardSortMode::POSITION_ASC;
                        descMode = LeaderboardSortMode::POSITION_DESC;
                    }
                    else if (i == 1)
                    {
                        label = "Player";
                        isSortable = true;
                        ascMode = LeaderboardSortMode::PLAYER_ASC;
                        descMode = LeaderboardSortMode::PLAYER_DESC;
                    }
                    else if (i == 2)
                    {
                        label = "Rank";
                        isSortable = true;
                        ascMode = LeaderboardSortMode::RANK_ASC;
                        descMode = LeaderboardSortMode::RANK_DESC;
                    }
                    else if (i == 3)
                    {
                        label = "Points";
                        isSortable = true;
                        ascMode = LeaderboardSortMode::POINTS_ASC;
                        descMode = LeaderboardSortMode::POINTS_DESC;
                    }
                    else if (i == 4)
                    {
                        label = "Completed";
                        isSortable = true;
                        ascMode = LeaderboardSortMode::COMPLETED_ASC;
                        descMode = LeaderboardSortMode::COMPLETED_DESC;
                    }
                    else if (i == 5)
                    {
                        label = "Best";
                        isSortable = true;
                        ascMode = LeaderboardSortMode::BEST_ASC;
                        descMode = LeaderboardSortMode::BEST_DESC;
                    }

                    if (isSortable)
                    {
                        DrawLeaderboardSortHeader(label, ascMode, descMode, currentLeaderboardSortMode);
                    }
                    else
                    {
                        UI::Text(label);
                    }
                }

                for (uint i = 0; i < entries.Length; i++)
                {
                    LeaderboardEntry@ entry = entries[i];
                    if (entry is null) continue;

                    UI::TableNextRow();
                    UI::TableSetBgColor(UI::TableBgTarget::RowBg0, GetLeaderboardRowColor(entry.RankColor, i));

                    UI::TableNextColumn();
                    UI::Text(tostring(entry.Position) + ".");

                    UI::TableNextColumn();
                    UI::Text(entry.PlayerName);

                    UI::TableNextColumn();
                    UI::Text(entry.RankName == "" ? "-" : entry.RankName);
                    if (UI::IsItemHovered())
                    {
                        UI::BeginTooltip();
                        string normalizedRankName = Text::StripFormatCodes(entry.RankName).Trim().ToLower();
                        if (normalizedRankName == "" || normalizedRankName == "unranked")
                        {
                            UI::Text("No rank threshold");
                        }
                        else
                        {
                            UI::Text("Minimum points: " + pvm.GetRankPointThreshold(entry.RankName));
                        }
                        UI::EndTooltip();
                    }

                    UI::TableNextColumn();
                    UI::Text(tostring(entry.TotalPoints));

                    UI::TableNextColumn();
                    UI::Text(tostring(entry.AchievementsCount));

                    UI::TableNextColumn();
                    UI::Text(tostring(entry.BestAchievementsCount));
                }

                UI::EndTable();
            }

            if (pvm.HasMoreLeaderboardEntries())
            {
                UI::BeginGroup();
                UI::Dummy(vec2(0, 4));
                if (UI::Button("Load more"))
                {
                    pvm.LoadMoreLeaderboard();
                }
                UI::EndGroup();
            }
        }

        private void DrawLeaderboardSortHeader(const string &in label, LeaderboardSortMode ascMode, LeaderboardSortMode descMode, LeaderboardSortMode currentMode)
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

        private void HandleSortAction(LeaderboardSortMode ascMode, LeaderboardSortMode descMode, LeaderboardSortMode currentMode)
        {
            if (currentMode == ascMode)
            {
                pvm.UpdateLeaderboardSortMode(descMode);
                return;
            }

            if (currentMode == descMode)
            {
                pvm.UpdateLeaderboardSortMode(ascMode);
                return;
            }

            pvm.UpdateLeaderboardSortMode(ascMode);
        }

        private vec4 GetLeaderboardRowColor(const string &in colorValue, uint rowIndex)
        {
            float stripe = rowIndex % 2 == 0 ? 0.68f : 1.12f;
            float alpha = rowIndex % 2 == 0 ? 0.08f : 0.10f;
            vec4 color;
            if(Text::TryParseHexColor(colorValue, color))
            {
                return vec4(color.x * stripe, color.y * stripe, color.z * stripe, alpha);
            }
            else
            {
                return vec4(0.10f, 0.10f, 0.10f, 0.06f);
            }
        }

    }
}
