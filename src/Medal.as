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

namespace Medals
{
    Medal Unfinished = Medal(-1, "Unfinished", "888", Icons::Kenney::Radio);
    Medal NoMedal = Medal(-1, "Finished", "444", Icons::Circle);
}