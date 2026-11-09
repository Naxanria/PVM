class PVM
{
    string Id;
    string Name = "Empty";
    string Author;
    string JsonUrl;
    string SheetUrl;
    string DiscordUrl;

    bool enabled = true;

    Medal@[] labels;
    MapData@[] maps;
    dictionary uidToMap = {};  

    TierInfo@[] tiers;
    int[] mapTierOrder;
    LeaderboardEntry@[] leaderboardEntries;
    int leaderboardOffset = 0;
    int leaderboardLimit = 50;
    bool leaderboardFetched = false;
    bool leaderboardHasMore = false;
    bool leaderboardLoading = false;

    bool Fetching = false;
    bool ReloadRequested = false;
    MapData@ currentMap = MapData(); 

    // Keep the backend tier sequence as the source of truth; default to highest tier first.
    private MapSortMode sortMode = MapSortMode::TIER_DESC;
    private LeaderboardSortMode leaderboardSortMode = LeaderboardSortMode::POSITION_ASC;
    private MapData@[] sortedList;
    private bool sortedListDirty = true;
    private LeaderboardEntry@[] sortedLeaderboardEntries;

    private string currentSearch = "";
    private string currentLeaderboardSearch = "";

    string GetId()
    {
        return Id + "";
    }

    int GetPB()
    {
        return currentMap.pb;
    }

    bool IsEmpty()
    {
        return Name == "Empty";
    }

    MapSortMode GetMapSortMode()
    {
        return sortMode;
    }

    bool HasLeaderboardData()
    {
        return leaderboardEntries.Length > 0;
    }

    bool IsLoadingLeaderboard()
    {
        return leaderboardLoading;
    }

    bool HasMoreLeaderboardEntries()
    {
        return leaderboardHasMore;
    }

    LeaderboardSortMode GetLeaderboardSortMode()
    {
        return leaderboardSortMode;
    }

    void UpdateLeaderboardSortMode(LeaderboardSortMode mode)
    {
        if (leaderboardSortMode == mode) return;
        Logging::Debug(Utils::GetLogIdentity(Name, GetId()) + " leaderboard sort mode changed from=" + tostring(leaderboardSortMode) + " to=" + tostring(mode) + " entries=" + leaderboardEntries.Length);
        leaderboardSortMode = mode;
        RebuildSortedLeaderboardEntries();
    }

    void UpdateLeaderboardSearch(const string &in search)
    {
        string nextSearch = search.Trim();
        if (currentLeaderboardSearch == nextSearch) return;
        currentLeaderboardSearch = nextSearch;
        RebuildSortedLeaderboardEntries();
    }

    LeaderboardEntry@[] GetLeaderboardEntries()
    {
        return leaderboardEntries;
    }

    LeaderboardEntry@[] GetSortedLeaderboardEntries()
    {
        return sortedLeaderboardEntries;
    }

    private void RebuildSortedLeaderboardEntries()
    {
        string search = currentLeaderboardSearch.Trim().ToLower();

        LeaderboardEntry@[] filtered = {};
        for (uint i = 0; i < leaderboardEntries.Length; i++)
        {
            LeaderboardEntry@ entry = leaderboardEntries[i];
            if (entry is null) continue;
            if (search != "")
            {
                string player = entry.PlayerName.Trim().ToLower();
                if (!player.Contains(search))
                {
                    continue;
                }
            }
            filtered.InsertLast(entry);
        }

        uint[] order = {};
        for (uint i = 0; i < filtered.Length; i++)
        {
            order.InsertLast(i);
        }

        // Stable insertion sort keeps API order for entries equal on every key.
        for (uint i = 1; i < order.Length; i++)
        {
            uint entryIndex = order[i];
            uint insertIndex = i;
            while (insertIndex > 0)
            {
                uint previousIndex = order[insertIndex - 1];
                if (CompareLeaderboardEntries(filtered[entryIndex], filtered[previousIndex], leaderboardSortMode) >= 0) break;
                order[insertIndex] = previousIndex;
                insertIndex--;
            }
            order[insertIndex] = entryIndex;
        }

        LeaderboardEntry@[] sorted = {};
        for (uint i = 0; i < order.Length; i++)
        {
            sorted.InsertLast(filtered[order[i]]);
        }

        sortedLeaderboardEntries = sorted;

        string sortedSample = "";
        for (uint i = 0; i < sortedLeaderboardEntries.Length && i < 5; i++)
        {
            LeaderboardEntry@ entry = sortedLeaderboardEntries[i];
            if (entry is null) continue;
            if (sortedSample != "") sortedSample += " | ";
            sortedSample += i + ":position=" + entry.Position + ",points=" + entry.TotalPoints + ",name=" + NormalizePlayerName(entry.PlayerName) + ",rank=" + entry.RankName;
        }
        Logging::Debug(Utils::GetLogIdentity(Name, GetId()) + " leaderboard sort applied mode=" + tostring(leaderboardSortMode) + " filtered=" + filtered.Length + " sorted=" + sortedLeaderboardEntries.Length + " firstRows=[" + sortedSample + "]");
    }

    private int CompareLeaderboardEntries(LeaderboardEntry@ a, LeaderboardEntry@ b, LeaderboardSortMode mode)
    {
        if (a is null) return b is null ? 0 : -1;
        if (b is null) return 1;

        bool descending = IsLeaderboardSortDescending(mode);
        int comparison = 0;
        switch (mode)
        {
            case LeaderboardSortMode::POSITION_ASC:
                comparison = CompareLeaderboardInteger(a.Position, b.Position, false);
                break;
            case LeaderboardSortMode::POINTS_ASC:
                comparison = CompareLeaderboardInteger(a.TotalPoints, b.TotalPoints, false);
                break;
            case LeaderboardSortMode::POSITION_DESC:
                comparison = CompareLeaderboardInteger(a.Position, b.Position, true);
                break;
            case LeaderboardSortMode::POINTS_DESC:
                comparison = CompareLeaderboardInteger(a.TotalPoints, b.TotalPoints, true);
                break;
            case LeaderboardSortMode::PLAYER_ASC:
            case LeaderboardSortMode::PLAYER_DESC:
                comparison = CompareLeaderboardName(a, b, descending);
                break;
            case LeaderboardSortMode::RANK_ASC:
            case LeaderboardSortMode::RANK_DESC:
                comparison = CompareLeaderboardRank(a, b, descending);
                break;
            case LeaderboardSortMode::COMPLETED_ASC:
                comparison = CompareLeaderboardInteger(a.AchievementsCount, b.AchievementsCount, false);
                break;
            case LeaderboardSortMode::COMPLETED_DESC:
                comparison = CompareLeaderboardInteger(a.AchievementsCount, b.AchievementsCount, true);
                break;
            case LeaderboardSortMode::BEST_ASC:
                comparison = CompareLeaderboardInteger(a.BestAchievementsCount, b.BestAchievementsCount, false);
                break;
            case LeaderboardSortMode::BEST_DESC:
                comparison = CompareLeaderboardInteger(a.BestAchievementsCount, b.BestAchievementsCount, true);
                break;
        }

        if (comparison != 0) return comparison;

        // Resolve equal primary values using position, normalized player name, then API rank order.
        comparison = CompareLeaderboardInteger(a.TotalPoints, b.TotalPoints, descending);
        if (comparison != 0) return comparison;
        comparison = CompareLeaderboardName(a, b, descending);
        if (comparison != 0) return comparison;
        return CompareLeaderboardRank(a, b, descending);
    }

    private bool IsLeaderboardSortDescending(LeaderboardSortMode mode)
    {
        return mode == LeaderboardSortMode::POSITION_DESC || mode == LeaderboardSortMode::POINTS_DESC ||
            mode == LeaderboardSortMode::PLAYER_DESC || mode == LeaderboardSortMode::RANK_DESC ||
            mode == LeaderboardSortMode::COMPLETED_DESC || mode == LeaderboardSortMode::BEST_DESC;
    }

    private int CompareLeaderboardInteger(int a, int b, bool descending)
    {
        if (a < b) return descending ? 1 : -1;
        if (a > b) return descending ? -1 : 1;
        return 0;
    }

    private string NormalizePlayerName(const string &in playerName)
    {
        return Text::StripFormatCodes(playerName).Trim().ToLower();
    }

    private int CompareLeaderboardName(LeaderboardEntry@ a, LeaderboardEntry@ b, bool descending)
    {
        string aName = NormalizePlayerName(a.PlayerName);
        string bName = NormalizePlayerName(b.PlayerName);
        if (aName < bName) return descending ? 1 : -1;
        if (aName > bName) return descending ? -1 : 1;
        return 0;
    }

    private int CompareLeaderboardRank(LeaderboardEntry@ a, LeaderboardEntry@ b, bool descending)
    {
        return CompareLeaderboardInteger(GetRankSortValue(a.RankName), GetRankSortValue(b.RankName), descending);
    }

    private int GetTierOrderIndex(const string &in tierName)
    {
        string name = Text::StripFormatCodes(tierName).Trim();
        if (name == "")
        {
            return -1;
        }

        string normalized = name.ToLower();
        for (uint i = 0; i < tiers.Length; i++)
        {
            string candidateTierName = Text::StripFormatCodes(tiers[i].Name).Trim();
            if (candidateTierName.ToLower() == normalized)
            {
                return int(i);
            }
        }

        return int(tiers.Length);
    }

    private int GetMapTierOrderIndex(int tierId)
    {
        if (tierId <= 0)
        {
            return int(mapTierOrder.Length);
        }

        for (uint i = 0; i < mapTierOrder.Length; i++)
        {
            if (mapTierOrder[i] == tierId)
            {
                return int(i);
            }
        }

        return int(mapTierOrder.Length);
    }

    private int GetRankSortValue(const string &in rankName)
    {
        string name = Text::StripFormatCodes(rankName).Trim();
        string normalized = name.ToLower();
        if (normalized == "" || normalized == "unranked")
        {
            return -1;
        }

        for (uint i = 0; i < tiers.Length; i++)
        {
            string tierName = Text::StripFormatCodes(tiers[i].Name).Trim();
            if (tierName.ToLower() == normalized)
            {
                return tiers[i].PointsNeeded;
            }
        }

        return -1;
    }

    int GetTierPointThreshold(const string &in tierName)
    {
        string name = Text::StripFormatCodes(tierName).Trim();
        if (name == "")
        {
            return 0;
        }

        for (uint i = 0; i < tiers.Length; i++)
        {
            if (Text::StripFormatCodes(tiers[i].Name).Trim().ToLower() == name.ToLower())
            {
                return tiers[i].PointsNeeded;
            }
        }

        return 0;
    }

    int GetRankPointThreshold(const string &in rankName)
    {
        string name = Text::StripFormatCodes(rankName).Trim();
        if (name == "")
        {
            return 0;
        }

        for (uint i = 0; i < tiers.Length; i++)
        {
            if (Text::StripFormatCodes(tiers[i].Name).Trim().ToLower() == name.ToLower())
            {
                return tiers[i].PointsNeeded;
            }
        }

        return 0;
    }

    void LoadLeaderboard()
    {
        if (leaderboardLoading) return;
        if (leaderboardFetched && !leaderboardHasMore) return;

        leaderboardLoading = true;
        startnew(CoroutineFunc(this.FetchLeaderboard));
    }

    void LoadMoreLeaderboard()
    {
        if (leaderboardLoading) return;
        if (!leaderboardHasMore) return;

        LoadLeaderboard();
    }

    private void FetchLeaderboard()
    {
        Json::Value@ json = API::GetJson(JsonUrl + "/leaderboard?offset=" + leaderboardOffset + "&limit=" + leaderboardLimit);

        if (json.GetType() != Json::Type::Array)
        {
            leaderboardLoading = false;
            return;
        }

        if (leaderboardOffset == 0)
        {
            leaderboardEntries.RemoveRange(0, leaderboardEntries.Length);
        }

        for (uint i = 0; i < json.Length; i++)
        {
            Json::Value@ entryJson = json[i];
            if (entryJson is null) continue;

            Json::Value@ playerJson = entryJson["player"];
            if (playerJson is null) continue;

            LeaderboardEntry@ entry = LeaderboardEntry();
            entry.Position = leaderboardOffset + int(i) + 1;
            entry.PlayerId = entryJson["player_id"];
            entry.PlayerName = playerJson["name"];
            entry.TotalPoints = int(entryJson["total_points"]);
            entry.AchievementsCount = int(entryJson["achievements_count"]);
            entry.BestAchievementsCount = int(entryJson["best_achievements_count"]);
            entry.RankName = GetRankNameForPoints(entry.TotalPoints);
            entry.RankColor = GetRankColorForPoints(entry.TotalPoints);
            leaderboardEntries.InsertLast(entry);
        }

        leaderboardFetched = true;
        leaderboardHasMore = json.Length >= uint(leaderboardLimit);
        leaderboardOffset += int(json.Length);
        leaderboardLoading = false;
        RebuildSortedLeaderboardEntries();
        Logging::Debug(Utils::GetLogIdentity(Name, GetId()) + " leaderboard fetch applied received=" + json.Length + " total=" + leaderboardEntries.Length + " hasMore=" + leaderboardHasMore);
    }

    string GetRankNameForPoints(int points)
    {
        int bestNeeded = -1;
        string bestName = "Unranked";

        for (uint i = 0; i < tiers.Length; i++)
        {
            if (points < tiers[i].PointsNeeded || tiers[i].PointsNeeded <= bestNeeded) continue;
            bestNeeded = tiers[i].PointsNeeded;
            bestName = tiers[i].Name;
        }

        return bestName;
    }

    string GetRankColorForPoints(int points)
    {
        int bestNeeded = -1;
        string bestColor = "";

        for (uint i = 0; i < tiers.Length; i++)
        {
            if (points < tiers[i].PointsNeeded || tiers[i].PointsNeeded <= bestNeeded) continue;
            bestNeeded = tiers[i].PointsNeeded;
            bestColor = tiers[i].Color;
        }

        return bestColor;
    }

    private void LoadRanks(Json::Value@ json)
    {
        if (json is null || json.GetType() != Json::Type::Array)
        {
            return;
        }

        tiers.RemoveRange(0, tiers.Length);

        string rankOrderSummary = "";
        for (uint i = 0; i < json.Length; i++)
        {
            Json::Value@ rankJson = json[i];
            if (rankJson is null) continue;

            TierInfo tier = TierInfo();
            tier.Name = rankJson["name"];
            tier.Color = rankJson["color"];
            tier.PointsNeeded = int(rankJson["pointsNeeded"]);
            tiers.InsertLast(tier);

            if (rankOrderSummary != "") rankOrderSummary += " > ";
            rankOrderSummary += tier.Name + "(" + tier.PointsNeeded + ")";
        }

        Logging::Debug(Utils::GetLogIdentity(Name, GetId()) + " loaded API rank thresholds count=" + tiers.Length + " ranks=[" + rankOrderSummary + "]");
    }

    private void ResetSourceData()
    {
        if (maps.Length > 0 || labels.Length > 0 || tiers.Length > 0 || leaderboardEntries.Length > 0)
        {
            Logging::Debug(Utils::GetLogIdentity(Name, GetId()) + " resetting source data: maps=" + maps.Length + " labels=" + labels.Length + " tiers=" + tiers.Length + " leaderboard=" + leaderboardEntries.Length + " sortedList=" + sortedList.Length);
        }
        uidToMap = dictionary();
        maps = {};
        labels = {};
        tiers = {};
        mapTierOrder = {};
        leaderboardEntries = {};
        sortedLeaderboardEntries = {};
        leaderboardOffset = 0;
        leaderboardFetched = false;
        leaderboardHasMore = false;
        leaderboardLoading = false;
        sortedList = {};
        sortedListDirty = true;
        currentSearch = "";
        currentLeaderboardSearch = "";
    }

    void ReloadPvmJson()
    {
        ResetSourceData();
        ReloadRequested = true;
    }

    bool LoadPvmJson()
    {
        bool isReload = ReloadRequested;
        if (Fetching)
        {
            return false;
        }

        ReloadRequested = false;
        Fetching = true;
        Logging::Info((isReload ? "Reloading PVM " : "Loading PVM ") + Name + " by " + Author);

        ResetSourceData();

        Json::Value@ json = API::GetJson(JsonUrl);

        SetupStructure(json);
        LoadMaps(json["MappackTrack"]);

        Fetching = false;        

        return true;
    }

    private array<string> GetMedalFromIndex(int index, int length) {
        if (length > 5) {
            if (index == length - 3) return { Icons::Crosshairs, Color::AUTHOR };
            if (index == length - 2) return { Icons::Kenney::Badge, Color::WARRIOR };
            if (index == length - 1) return { Icons::Kenney::BadgeAlt, Color::CHAMPION };
        }
        if (length > 4) {
            if (index == length - 2) return  { Icons::Crosshairs, Color::AUTHOR };
            if (index == length - 1) return  { Icons::Kenney::BadgeAlt, Color::CHAMPION };
        }
        if (length > 2) {
            if (index == length - 1) return  { Icons::Crosshairs, Color::AUTHOR };
        }
        if (index == 1) return  { Icons::Circle, Color::SILVER };
        if (index == 0) return  { Icons::CircleO, Color::BRONZE };
        return  { Icons::Circle, Color::GOLD };
    }

    private void SetupStructure(Json::Value@ json)
    {
        LoadRanks(json["mappackRanks"]);
        LoadMapTierOrder(json["mappackTiers"]);

        Json::Value@ medals = json["timeGoals"];
        for (uint i = 0; i < medals.Length; i++)
        {
            Json::Value@ medal = medals[i];
            array<string> defaultMedal = GetMedalFromIndex(i, medals.Length);
            TimeGoal timeGoal = TimeGoal(i, medal["name"], defaultMedal[1], defaultMedal[0]);
            Medal ml = Medal(timeGoal.id, timeGoal.name, defaultMedal[1], defaultMedal[0]);
            labels.InsertLast(ml);
        }
    }

    private void LoadMapTierOrder(Json::Value@ json)
    {
        mapTierOrder = {};
        if (json is null || json.GetType() != Json::Type::Array)
        {
            Logging::Debug(Utils::GetLogIdentity(Name, GetId()) + " missing mappackTiers array; tier sorting will use unknown-tier fallback");
            return;
        }

        string tierOrderSummary = "";
        for (uint i = 0; i < json.Length; i++)
        {
            Json::Value@ tierJson = json[i];
            if (tierJson is null) continue;

            int tierId = int(tierJson["id"]);
            if (tierId <= 0) continue;
            string tierName = tierJson["name"];
            mapTierOrder.InsertLast(tierId);

            if (tierOrderSummary != "") tierOrderSummary += " > ";
            tierOrderSummary += tierName + "(" + tierId + ")";
        }

        Logging::Debug(Utils::GetLogIdentity(Name, GetId()) + " loaded ascending backend map tier order count=" + mapTierOrder.Length + " tiers=[" + tierOrderSummary + "]");
    }

    private void LoadMaps(Json::Value@ json)
    {
        Logging::Debug(Utils::GetLogIdentity(Name, GetId()) + " loading maps: incoming=" + json.Length + " existingMaps=" + maps.Length);
        for (uint i = 0; i < json.Length; i++)
        {
            MapData@ map = MapData(json[i]);
            if (map is null || map.Uid == "")
            {
                Logging::Debug(Utils::GetLogIdentity(Name, GetId()) + " skipping empty map at index=" + i);
                continue;
            }

            if (uidToMap.Exists(map.Uid))
            {
                Logging::Debug(Utils::GetLogIdentity(Name, GetId()) + " skipping duplicate map uid=" + map.Uid);
                continue;
            }

            maps.InsertLast(map);
            uidToMap[map.Uid] = @map;
        }
        RebuildSortedList();
        Logging::Debug(Utils::GetLogIdentity(Name, GetId()) + " loaded maps: count=" + maps.Length + " uniqueUidCount=" + uidToMap.GetSize());
    }

    bool ContainsMap(string &in uid)
    {
        return uidToMap.Exists(uid);
    }

    void UpdateMap(string &in uid)
    {
        if (ContainsMap(uid))
            currentMap = cast<MapData@>(uidToMap[uid]);
    }

    void UpdatePb(int pb)
    {
        // todo: check if new medal obtained

        if (currentMap.SetPb(pb))
        {
            for (uint i = 0; i < maps.Length; i++)
            {
                if (maps[i].Uid == currentMap.Uid)
                {
                    maps[i].SetPb(pb);
                    break;
                }
            }

            if (sortMode == MapSortMode::TIME_ASC || sortMode == MapSortMode::TIME_DESC)
            {
                RebuildSortedList();
            }
        }
    }

    void Render()
    {
        if (ReloadRequested || Fetching) return;
        if (currentMap is null) return;
        if (!enabled) return;
        if (Setting::pvm_hide_on_interface_hidden && !UI::IsGameUIVisible()) return;

        int winFlags = UI::WindowFlags::NoDocking | UI::WindowFlags::AlwaysAutoResize | UI::WindowFlags::NoTitleBar;

        if(Setting::window_lock_position) 
        {
            UI::SetNextWindowPos(int(Setting::window_position.x), int(Setting::window_position.y), UI::Cond::Always);
        }
        else
        {
            UI::SetNextWindowPos(int(Setting::window_position.x), int(Setting::window_position.y), UI::Cond::FirstUseEver);            
        }

        UI::Begin("PVM Medals", winFlags);

        if (!Setting::window_lock_position)
        {
            Setting::window_position = UI::GetWindowPos();
        }

        UI::BeginGroup();

        RenderHeader();

        RenderMedals();        

        UI::EndGroup();

        UI::End();
    }

    void RenderHeader()
    {
        if (!Setting::pvm_header_map_name && !Setting::pvm_header_map_author && !Setting::pvm_header_map_tier) return; // noting in the header
        if (UI::BeginTable("pvm_header", 1, UI::TableFlags::SizingFixedFit))
        {
            if (Setting::pvm_header_map_name)
            {   
                UI::TableNextRow();
                UI::TableNextColumn();
                UI::Text(Text::OpenplanetFormatCodes(currentMap.Name));
            }

            if (Setting::pvm_header_map_author)
            {   
                UI::TableNextRow();
                UI::TableNextColumn();

                UI::Text(Color::FORMAT_AUTHOR_COLOUR + currentMap.Author);
            }

            if (Setting::pvm_header_map_tier)
            {   
                UI::TableNextRow();
                UI::TableNextColumn();

                UI::Text(Color::FORMAT_TIER_COLOUR + "Tier: " + currentMap.PvmTier);
            }

            UI::EndTable();
        }
    }

    private void RenderMedals()
    {
        int columns = 2;
        if (Setting::pvm_show_labels) columns++;
        if (Setting::pvm_show_delta) columns++;

        if (UI::BeginTable("pvm_medals", columns, UI::TableFlags::SizingFixedFit))
        {   
            if (!currentMap.HasMedalTimes())
            {
                if (Setting::pvm_show_personal_best)
                {
                    InsertPb(currentMap.pb, Medals::NoMedal, true);
                }

                UI::EndTable();
                return;
            }

            bool shownPb = false;
            for (int i = labels.Length - 1; i >= 0; i--)
            {
                if (Setting::pvm_show_personal_best && !shownPb)
                {
                    shownPb = InsertPb(currentMap.pb, labels[i]);
                }

                if (!Setting::PvmShowMedal(Id, i)) continue;

                RenderMedal(labels[i]);
            }

            if (!shownPb && Setting::pvm_show_personal_best)
            {
                InsertPb(currentMap.pb, Medals::NoMedal, true);
            }

            UI::EndTable();
        }
    }

    private bool InsertPb(int pb, Medal@ label, bool force = false)
    {
        if (force)
        {
            MedalEntry(label, pb < 0 ? 0 : pb, true);
        }

        if (pb <= 0) return false;

        int medalTime = currentMap.GetMedalTime(label.id);
        if (pb > medalTime) return false; // slower pb, or if no such medal (medalTime will be 0 then)

        MedalEntry(label, pb, true);
        return true;
    }

    private void RenderMedal(Medal@ label)
    {
        // todo: check if medal is enabled to show
        int medalTime = currentMap.GetMedalTime(label.id);
        if (medalTime <= 0) return;
        MedalEntry(label, medalTime);
    }

    private void MedalEntry(Medal@ label, int medalTime, bool isPb = false)
    {
        UI::TableNextRow();
        UI::TableNextColumn();
        UI::Text(label.GetIcon());

        if (Setting::pvm_show_labels)
        {
            UI::TableNextColumn();
            if (isPb) UI::Text(Color::TIME_PERSONAL_BEST + "PB");
            else UI::Text(label.GetName());
        }

        UI::TableNextColumn();
        UI::Text((isPb ? Color::TIME_PERSONAL_BEST : "") + Utils::ReadableTime(medalTime));
        
        if (Setting::pvm_show_delta)
        {
            UI::TableNextColumn();
            
            if (isPb)
            {
                UI::Text("");
            }
            else
            {
                int personalBest = currentMap.pb;

                if (personalBest == -1)
                {
                    UI::Text("");
                }
                else
                {
                    int delta = personalBest - medalTime;
                    string sign = Setting::pvm_show_delta_sign ? (delta < 0 ? "-" : "+") : "";
                    if (delta < 0)
                    {
                        UI::Text(Color::TIME_DELTA_AHEAD + sign + Utils::ReadableTime(delta * -1));
                    }
                    else
                    {
                        UI::Text(Color::TIME_DELTA_BEHIND + sign + Utils::ReadableTime(delta));
                    }
                }
            }
        }

        if (isPb)
        {
            UI::SameLine();
            UI::TextDisabled(Icons::Clipboard);

            if (UI::IsItemClicked())
            {
                Utils::TimeToClipboard(currentMap.pb);
            }
        }
    }

    void UpdateSearch(const string &in search)
    {
        string nextSearch = search.Trim();
        if (nextSearch == currentSearch) return;
        currentSearch = nextSearch;
        RebuildSortedList();
    }

    void UpdateMapSortMode(MapSortMode mode)
    {
        if (sortMode == mode) return;
        Logging::Debug(Utils::GetLogIdentity(Name, GetId()) + " map sort mode changed from=" + tostring(sortMode) + " to=" + tostring(mode) + " maps=" + maps.Length);
        sortMode = mode;
        RebuildSortedList();
    }

    private void RebuildSortedList()
    {
        if (maps is null)
        {
            Logging::Debug(Utils::GetLogIdentity(Name, GetId()) + " cannot rebuild sorted list because maps is null");
            sortedList = {};
            sortedListDirty = false;
            return;
        }

        MapData@[] filtered = FilteredList();
        MapData@[] rebuilt = {};
        dictionary seenUids = {};

        for (uint i = 0; i < filtered.Length; i++)
        {
            MapData@ map = filtered[i];
            if (map is null || map.Uid == "")
            {
                continue;
            }

            if (seenUids.Exists(map.Uid))
            {
                Logging::Debug(Utils::GetLogIdentity(Name, GetId()) + " dropping duplicate map uid=" + map.Uid + " in sort rebuild");
                continue;
            }

            seenUids[map.Uid] = true;
            rebuilt.InsertLast(map);
        }

        Logging::Debug(Utils::GetLogIdentity(Name, GetId()) + " rebuilding sorted map list: sourceCount=" + maps.Length + " filtered=" + rebuilt.Length + " mode=" + tostring(sortMode) + " tierOrderCount=" + mapTierOrder.Length + " search='" + currentSearch + "'");

        uint[] order = {};
        for (uint i = 0; i < rebuilt.Length; i++)
        {
            order.InsertLast(i);
        }

        // Stable insertion sort preserves backend order when all requested keys are equal.
        for (uint i = 1; i < order.Length; i++)
        {
            uint mapIndex = order[i];
            uint insertIndex = i;
            while (insertIndex > 0)
            {
                uint previousIndex = order[insertIndex - 1];
                if (CompareMaps(rebuilt[mapIndex], rebuilt[previousIndex], sortMode) >= 0) break;
                order[insertIndex] = previousIndex;
                insertIndex--;
            }
            order[insertIndex] = mapIndex;
        }

        MapData@[] sorted = {};
        for (uint i = 0; i < order.Length; i++)
        {
            sorted.InsertLast(rebuilt[order[i]]);
        }

        sortedList = sorted;
        sortedListDirty = false;
        string sortedSample = "";
        for (uint i = 0; i < sortedList.Length && i < 5; i++)
        {
            MapData@ map = sortedList[i];
            if (map is null) continue;
            if (sortedSample != "") sortedSample += " | ";
            sortedSample += i + ":tier=" + map.PvmTier + "#" + map.PvmTierId + ",name=" + Text::StripFormatCodes(map.Name).Trim().ToLower() + ",pb=" + map.pb;
        }
        Logging::Debug(Utils::GetLogIdentity(Name, GetId()) + " sorted map list applied mode=" + tostring(sortMode) + " count=" + sortedList.Length + " firstRows=[" + sortedSample + "]");
    }

    private MapData@[] FilteredList()
    {
        if (maps is null)
        {
            return {};
        }

        MapData@[] list = {};
        for (uint i = 0; i < maps.Length; i++)
        {
            if (Filtered(maps[i]))
            {
                list.InsertLast(maps[i]);
            }
        }
        return list;
    }

    private bool Filtered(MapData@ map)
    {
        if (currentSearch == "") return true;
        string s = currentSearch.Trim().ToLower();
        return map.Author.Trim().ToLower().Contains(s) || 
            Text::StripFormatCodes(map.Name).Trim().ToLower().Contains(s);
    }

    int GetTierPriority(int tierId)
    {
        return GetMapTierOrderIndex(tierId);
    }

    int CompareMaps(MapData@ a, MapData@ b, MapSortMode mode)
    {
        if (a is null) return b is null ? 0 : -1;
        if (b is null) return 1;

        bool descending = IsMapSortDescending(mode);
        int comparison = 0;
        switch (mode)
        {
            case MapSortMode::AUTHOR_ASC:
            case MapSortMode::AUTHOR_DESC:
                comparison = CompareNormalizedAuthor(a, b, descending);
                break;
            case MapSortMode::NAME_ASC:
            case MapSortMode::NAME_DESC:
                comparison = CompareNormalizedName(a, b, descending);
                break;
            case MapSortMode::TIER_ASC:
            case MapSortMode::TIER_DESC:
                comparison = CompareMapTier(a, b, descending);
                break;
            case MapSortMode::TIME_ASC:
            case MapSortMode::TIME_DESC:
                comparison = CompareBestTime(a, b, descending);
                break;
        }

        if (comparison != 0) return comparison;

        // Every primary sort uses the same deterministic tie hierarchy.
        comparison = CompareMapTier(a, b, descending);
        if (comparison != 0) return comparison;
        comparison = CompareNormalizedName(a, b, descending);
        if (comparison != 0) return comparison;
        return CompareBestTime(a, b, descending);
    }

    private bool IsMapSortDescending(MapSortMode mode)
    {
        return mode == MapSortMode::AUTHOR_DESC || mode == MapSortMode::NAME_DESC ||
            mode == MapSortMode::TIER_DESC || mode == MapSortMode::TIME_DESC;
    }

    private int CompareMapTier(MapData@ a, MapData@ b, bool descending)
    {
        int aOrder = GetMapTierOrderIndex(a.PvmTierId);
        int bOrder = GetMapTierOrderIndex(b.PvmTierId);
        int tierCount = int(mapTierOrder.Length);
        bool aUnknown = aOrder >= tierCount;
        bool bUnknown = bOrder >= tierCount;

        if (aUnknown != bUnknown) return aUnknown ? 1 : -1;
        if (aUnknown) return 0;

        if (aOrder < bOrder) return descending ? 1 : -1;
        if (aOrder > bOrder) return descending ? -1 : 1;
        return 0;
    }

    private int CompareNormalizedName(MapData@ a, MapData@ b, bool descending)
    {
        string aName = Text::StripFormatCodes(a.Name).Trim().ToLower();
        string bName = Text::StripFormatCodes(b.Name).Trim().ToLower();
        if (aName < bName) return descending ? 1 : -1;
        if (aName > bName) return descending ? -1 : 1;
        return 0;
    }

    private int CompareNormalizedAuthor(MapData@ a, MapData@ b, bool descending)
    {
        string aAuthor = Text::StripFormatCodes(a.Author).Trim().ToLower();
        string bAuthor = Text::StripFormatCodes(b.Author).Trim().ToLower();
        if (aAuthor < bAuthor) return descending ? 1 : -1;
        if (aAuthor > bAuthor) return descending ? -1 : 1;
        return 0;
    }

    private int CompareBestTime(MapData@ a, MapData@ b, bool descending)
    {
        bool aHasTime = a.pb > 0;
        bool bHasTime = b.pb > 0;
        if (aHasTime != bHasTime) return aHasTime ? -1 : 1;
        if (!aHasTime) return 0;

        if (a.pb < b.pb) return descending ? 1 : -1;
        if (a.pb > b.pb) return descending ? -1 : 1;
        return 0;
    }

    MapData@[] GetSortedList()
    {
        if (maps is null)
        {
            return {};
        }

        if (sortedList is null || sortedListDirty)
        {
            RebuildSortedList();
        }

        return sortedList;
    }
}

namespace PVM
{
    PVM@ FromJson(Json::Value@ json)
    {
        PVM pvm = PVM();
        string pvm_id = json["id"];
        pvm.Id = pvm_id;
        pvm.Name = json["name"];
        pvm.Author = json["organization"];
        pvm.JsonUrl = PVM_MAPPACK_URL + "/" + pvm_id;
        pvm.SheetUrl = json["sheeturl"];
        pvm.DiscordUrl = json["discordurl"];

        return @pvm;
    }

    int Sort(MapData@ a, MapData@ b)
    {
        if (Overview::activeTab >= 0 && Overview::activeTab < int(pvms.Length))
        {
            PVM@ active = pvms[Overview::activeTab];
            if (active !is null)
            {
                int result = active.CompareMaps(a, b, active.GetMapSortMode());
                if (result != 0) return result;
            }
        }

        if (a is null) return b is null ? 0 : -1;
        if (b is null) return 1;
        if (a.Uid < b.Uid) return -1;
        if (a.Uid > b.Uid) return 1;
        return 0;
    }
}

class TierInfo
{
    string Name;
    string Color;
    int PointsNeeded;
}

class LeaderboardEntry
{
    int Position;
    string PlayerId;
    string PlayerName;
    int TotalPoints;
    int AchievementsCount;
    int BestAchievementsCount;
    string RankName;
    string RankColor;
}

enum MapSortMode
{
    AUTHOR_ASC,
    AUTHOR_DESC,
    NAME_ASC,
    NAME_DESC,
    TIER_ASC,
    TIER_DESC,
    TIME_ASC,
    TIME_DESC
}

enum LeaderboardSortMode
{
    POSITION_DESC,
    POSITION_ASC,
    POINTS_ASC,
    POINTS_DESC,
    PLAYER_ASC,
    PLAYER_DESC,
    RANK_ASC,
    RANK_DESC,
    COMPLETED_ASC,
    COMPLETED_DESC,
    BEST_ASC,
    BEST_DESC
}
