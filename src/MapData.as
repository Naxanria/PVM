class MapData
{
    string Uid;
    uint TmxId;

    string Name;
    string Author;
    string PvmGrade;

    uint[] medalTimes;

    int pb = -1;
    bool loadingPb = false;
    
    MapData()
    { }

    MapData(Json::Value@ json)
    {
        Uid = json["uid"];
        TmxId = json["tmx_id"];
        Name = json["name"];
        Author = json["author"];

        Json::Value@ pvm = json["pvm"];
        PvmGrade = pvm["grade"];
        Json::Value@ times = pvm["times"];
        for (int i = 0; i < times.Length; i++)
        {
            medalTimes.InsertLast(times[i]);
        }
    }

    uint GetMedalTime(int medal)
    {
        if (medal < 0 || medal >= medalTimes.Length)
        {
            return 0;
        }

        return medalTimes[medal];
    }

    bool HasMedalTime(int medal)
    {
        return GetMedalTime(medal) != 0;
    }

    void LoadPb()
    {
        if (loadingPb)
        {
            return;
        }

        loadingPb = true;

        //pb = API::Map_GetRecord_v2(Uid);
        auto rec = API::GetPlayerRecordOnMap(Uid);

        if (rec !is null)
        {
            bool better = pb > 0 && rec.Time < pb;
            if (pb < 0 && rec.Time > 0 && !better) better = true;
            if (better) pb = rec.Time;
        }

        loadingPb = false;
    }

    bool SetPb(int time)
    {
        if (pb <= 0 || time < pb)
        {
            pb = time;
            return true;
        }
        
        return false;
    }

    void LoadMap()
    {
        startnew(API::LoadMapNow, Uid);
    }

    int opCmp(MapData@ other)
    {
        return PVM::Sort(this, other);
    }
}