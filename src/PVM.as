class PVM
{
    int Id;
    string Name = "Empty";
    string Author;
    string JsonUrl;
    string SheetUrl;
    string DiscordUrl;

    bool enabled = true;

    MedalLabel@[] labels;
    MapData@[] maps;
    dictionary uidToMap = {};  

    bool Fetching = false;
    bool ReloadRequested = false;
    MapData@ currentMap = MapData(); 

    private SortMode sortMode;
    private MapData@[] sortedList;

    private string currentSearch = "";

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

    SortMode GetSortMode()
    {
        return sortMode;
    }

    void ReloadPvmJson()
    {
        uidToMap = dictionary();
        maps.RemoveRange(0, maps.Length);
        labels.RemoveRange(0, labels.Length);
        ReloadRequested = true;
    }

    bool LoadPvmJson()
    {
        ReloadRequested = false;
        if (Fetching)
        {
            return false;
        }

        Fetching = true;
        Logging::Info("Fetching " + Name + " pvm data from " + JsonUrl);

        Json::Value@ json = API::GetJson(JsonUrl);

        SetupStructure(json["structure"]);
        LoadMaps(json["maps"]);

        Fetching = false;        

        return true;
    }

    private void SetupStructure(Json::Value@ json)
    {
        Json::Value@ medals = json["medals"];
        for (int i = 0; i < medals.Length; i++)
        {
            Json::Value@ medal = medals[i];
            MedalLabel ml = MedalLabel(i, medal["name"], medal["colour"], medal["icon"]);
            labels.InsertLast(ml);
        }
    }

    private void LoadMaps(Json::Value@ json)
    {
        for (int i = 0; i < json.Length; i++)
        {
            MapData@ map = MapData(json[i]);
            maps.InsertLast(map);
            uidToMap[map.Uid] = @map;
        }
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
            for (int i = 0; i < maps.Length; i++)
            {
                if (maps[i].Uid == currentMap.Uid)
                {
                    maps[i].SetPb(pb);
                    break;
                }
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
        if (!Setting::pvm_header_map_name && !Setting::pvm_header_map_author && !Setting::pvm_header_map_grade) return; // noting in the header
        if (UI::BeginTable("pvm_header", 1, UI::TableFlags::SizingFixedFit))
        {
            if (Setting::pvm_header_map_name)
            {   
                UI::TableNextRow();
                UI::TableNextColumn();
                UI::Text(currentMap.Name);
            }

            if (Setting::pvm_header_map_author)
            {   
                UI::TableNextRow();
                UI::TableNextColumn();

                UI::Text(Colour::FORMAT_AUTHOR_COLOUR + currentMap.Author);
            }

            if (Setting::pvm_header_map_grade)
            {   
                UI::TableNextRow();
                UI::TableNextColumn();

                UI::Text(Colour::FORMAT_GRADE_COLOUR + "Grade: " + currentMap.PvmGrade);
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

    private bool InsertPb(int pb, MedalLabel@ label, bool force = false)
    {
        if (force)
        {
            MedalEntry(label, pb < 0 ? 0 : pb, true);
        }

        if (pb <= 0) return false;

        int medalTime = currentMap.GetMedalTime(label.idx);
        if (pb > medalTime) return false; // slower pb, or if no such medal (medalTime will be 0 then)

        MedalEntry(label, pb, true);
        return true;
    }

    private void RenderMedal(MedalLabel@ label)
    {
        // todo: check if medal is enabled to show
        int medalTime = currentMap.GetMedalTime(label.idx);
        if (medalTime <= 0) return;
        MedalEntry(label, medalTime);
    }

    private void MedalEntry(MedalLabel@ label, int medalTime, bool isPb = false) 
    {
        UI::TableNextRow();
        UI::TableNextColumn();
        UI::Text(label.GetIcon());

        if (Setting::pvm_show_labels)
        {
            UI::TableNextColumn();
            if (isPb) UI::Text(Colour::TIME_PERSONAL_BEST + "PB");
            else UI::Text(label.GetLabel());
        }

        UI::TableNextColumn();
        UI::Text((isPb ? Colour::TIME_PERSONAL_BEST : "") + Utils::ReadableTime(medalTime));
        
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
                        UI::Text(Colour::TIME_DELTA_AHEAD + sign + Utils::ReadableTime(delta * -1));
                    }
                    else
                    {
                        UI::Text(Colour::TIME_DELTA_BEHIND + sign + Utils::ReadableTime(delta));
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

    void UpdateSearch(string search)
    {
        if (search == currentSearch) return;
        currentSearch = search.Trim();
        DoSort();
    }

    void UpdateSortMode(SortMode mode)
    {
        if (sortMode == mode) return;
        sortMode = mode;
        if (sortMode == SortMode::DEFAULT) return;
        DoSort();
    }

    private void DoSort()
    {
        sortedList = FilteredList();
        if (sortMode != SortMode::DEFAULT)
        {
            sortedList.SortAsc();
        }
    }

    private MapData@[] FilteredList()
    {
        MapData@[] list = {};
        for (int i = 0; i < maps.Length; i++)
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
            map.Name.Trim().ToLower().Contains(s);
    }

    MapData@[] GetSortedList()
    {
        if (sortMode == SortMode::DEFAULT && currentSearch == "")
        {
            return maps;
        }

        return sortedList;
    }
}

namespace PVM
{
    PVM@ FromJson(Json::Value@ json)
    {
        PVM pvm = PVM();
        pvm.Id = json["id"];
        pvm.Name = json["name"];
        pvm.Author = json["author"];
        pvm.JsonUrl = json["json"];
        pvm.SheetUrl = json["sheet"];
        pvm.DiscordUrl = json["discord"];

        return @pvm;
    }

    int Sort(MapData@ a, MapData@ b)
    {
        if (Overview::activeTab >= 0 && Overview::activeTab < pvms.Length)
        {
            SortMode mode = pvms[Overview::activeTab].GetSortMode();

            switch (mode)
            {
                case SortMode::DEFAULT:
                    break;
                case SortMode::AUTHOR:
                    return AuthorSort(a, b);
                case SortMode::AUTHOR_INVERTED:
                    return Reverse(AuthorSort(a, b));
                case SortMode::NAME:
                    return NameSort(a, b);
                case SortMode::NAME_INVERTED:
                    return Reverse(NameSort(a, b));
                case SortMode::TIME:
                    return TimeSort(a, b);
                case SortMode::TIME_INVERTED:
                    return Reverse(TimeSort(a, b));
            }
        }
        
        if (a.Uid < b.Uid) return -1;
        if (a.Uid > b.Uid) return 1;
        return 0;        
    }

    int Reverse(int res)
    {
        if (res == -1) return 1;
        if (res == 1) return -1;
        return 0;
    }

    int NameSort(MapData@ a, MapData@ b)
    {
        if (a.Name.ToLower() < b.Name.ToLower()) return -1;
        if (a.Name.ToLower() > b.Name.ToLower()) return 1;
        return 0;
    }

    int AuthorSort(MapData@ a, MapData@ b)
    {
        if (a.Author.ToLower() < b.Author.ToLower()) return -1;
        if (a.Author.ToLower() > b.Author.ToLower()) return 1;
        return 0;
    }

    int TimeSort(MapData@ a, MapData@ b)
    {
        int aLow = 2000000000;
        int bLow = 2000000000;
        int start = a.medalTimes.Length < b.medalTimes.Length ? a.medalTimes.Length : b.medalTimes.Length;
        for (int i = start; i > -1; i--)
        {
            int aTime = a.GetMedalTime(i);
            int bTime = b.GetMedalTime(i);
            if (aTime > 0 && bTime > 0)
            {
                if (aTime < bTime) return -1;
                if (aTime > bTime) return 1;
                return 0;
            }
            if (aTime > 0 && aTime < aLow)
            {                    
                aLow = aTime;                    
            }
            if (bTime > 0 && bTime < bLow)
            {
                bLow = bTime;
            }
        }

        if (aLow < bLow) return -1;
        if (aLow > bLow) return 1;
        return 0;
    }
}

enum SortMode
{
    DEFAULT,
    AUTHOR,
    AUTHOR_INVERTED,
    NAME,
    NAME_INVERTED,
    TIME,
    TIME_INVERTED
}
