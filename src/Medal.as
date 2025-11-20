class MedalLabel
{
    int idx;
    string label;
    string colour;
    string icon;

    MedalLabel()
    { }

    MedalLabel(int idx, string label, string colour, string icon)
    {
        this.idx = idx;
        this.label = label;
        this.colour = "\\$" + colour;
        this.icon = icon;
    }

    string GetLabel()
    {
        return label;
    }

    string GetIcon()
    {
        return colour + icon;
    }

    string GetFull(bool resetColour = true)
    {
        return GetIcon() + (resetColour ? "\\$z" : "") + " " + GetLabel();
    }
}

namespace Medals
{
    MedalLabel Unfinished = MedalLabel(-1, "Unfinished", "888", Icons::Kenney::Radio);
    MedalLabel NoMedal = MedalLabel(-1, "Finished", "444", Icons::Circle);
}