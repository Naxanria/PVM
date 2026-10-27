class Medal
{
    int id;
    string name;
    string color;
    string icon;

    Medal()
    { }

    Medal(int id, const string &in name, const string &in color, const string &in icon)
    {
        this.id = id;
        this.name = name;
        this.color = "\\$" + color;
        this.icon = icon;
    }

    string GetName()
    {
        return name;
    }

    string GetIcon()
    {
        return color + icon;
    }

    string GetFull(bool resetColour = true)
    {
        return GetIcon() + (resetColour ? "\\$z" : "") + " " + GetName();
    }
}

class TimeGoal
{
    int id;
    string name;
    string color;
    string icon;

    TimeGoal()
    { }

    TimeGoal(int id, const string &in name, const string &in color, const string &in icon)
    {
        this.id = id;
        this.name = name;
        this.color = "\\$" + color;
        this.icon = icon;
    }

    string GetName()
    {
        return name;
    }

    string GetIcon()
    {
        return color + icon;
    }
}

#if DEPENDENCY_ULTIMATEMEDALSEXTENDED
array<string> umeMedalNames = {};
bool umeRegistered = false;
string umeCurrentPvmId = "";

class PvmUmeMedal : UltimateMedalsExtended::IMedal
{
    private string medalName;
    private string medalIcon;
    private int goalId;
    private string currentUid;

    PvmUmeMedal(const string &in medalName, const string &in medalIcon, int goalId)
    {
        this.medalName = medalName;
        this.medalIcon = medalIcon;
        this.goalId = goalId;
        this.currentUid = "";
    }

    UltimateMedalsExtended::Config GetConfig() override
    {
        UltimateMedalsExtended::Config config;
        config.defaultName = medalName;
        config.icon = medalIcon;
        return config;
    }

    void UpdateMedal(const string &in uid) override
    {
        currentUid = uid;
    }

    bool HasMedalTime(const string &in uid) override
    {
        if (uid == "") return false;
        PVM@ pvm = GetPvmByMapUid(uid);
        if (pvm is null || pvm.currentMap is null || pvm.currentMap.Uid != uid) return false;
        return pvm.currentMap.GetMedalTime(goalId) > 0;
    }

    uint GetMedalTime() override
    {
        if (currentUid == "") return 0;
        PVM@ pvm = GetPvmByMapUid(currentUid);
        if (pvm is null || pvm.currentMap is null) return 0;
        return pvm.currentMap.GetMedalTime(goalId);
    }
}

PVM@ GetPvmByMapUid(const string &in uid)
{
    for (uint i = 0; i < pvms.Length; i++)
    {
        if (pvms[i].ContainsMap(uid))
        {
            return pvms[i];
        }
    }
    return null;
}

void OnDestroyedUME()
{
    for (uint i = 0; i < umeMedalNames.Length; i++)
    {
        UltimateMedalsExtended::RemoveMedal(umeMedalNames[i]);
    }

    umeMedalNames.RemoveRange(0, umeMedalNames.Length);
    umeCurrentPvmId = "";
    umeRegistered = false;
}

void RegisterUME()
{
    if (currentPvm.IsEmpty())
    {
        if (umeRegistered)
        {
            OnDestroyedUME();
        }
        return;
    }

    if (umeRegistered && umeCurrentPvmId == currentPvm.Id)
    {
        return;
    }

    OnDestroyedUME();

    for (uint j = 0; j < currentPvm.labels.Length; j++)
    {
        string medalName = currentPvm.Name + " - " + currentPvm.labels[j].GetName();
        UltimateMedalsExtended::AddMedal(PvmUmeMedal(medalName, currentPvm.labels[j].GetIcon(), currentPvm.labels[j].id));
        umeMedalNames.InsertLast(medalName);
    }

    umeCurrentPvmId = currentPvm.Id;
    umeRegistered = true;
}

void SyncUmeState()
{
    if (currentPvm.IsEmpty())
    {
        if (umeRegistered)
        {
            OnDestroyedUME();
        }
        return;
    }

    if (umeRegistered && umeCurrentPvmId == currentPvm.Id)
    {
        return;
    }

    RegisterUME();
}
#else
void RegisterUME() {}
void OnDestroyedUME() {}
#endif

namespace Medals
{
    Medal Unfinished = Medal(-1, "Unfinished", "888", Icons::Kenney::Radio);
    Medal NoMedal = Medal(-1, "Finished", "444", Icons::Circle);
}