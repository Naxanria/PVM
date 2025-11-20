class StatContainer
{
    private PVM@ pvm;
    private int[] counts;
    private int finished = 0;

    StatContainer()
    { }

    StatContainer(PVM@ pvm)
    {
        @this.pvm = pvm;
    }

    int GetTotal()
    {
        return pvm.maps.Length;
    }

    void Update()
    {
        for (int m = 0; m < pvm.labels.Length; m++)
        {
            counts.InsertLast(0);
        }

        for (int i = 0; i < GetTotal(); i++)
        {
            MapData@ map = pvm.maps[i];

            int bestMedal = GetBestMedal(map);

            if (map.pb > 0) finished++;
            if (bestMedal < 0) continue;

            for (int m = bestMedal; m >= 0; m--)
            {
                counts[m]++;
            }
        }
    }

    void Reset()
    {
        counts = {};
        finished = 0;        
    }

    int GetBestMedal(MapData@ map)
    {
        if (map.pb <= 0)
        {
            return -1;
        }

        for (int i = map.medalTimes.Length - 1; i >= 0; i--)
        {
            if (map.pb <= map.medalTimes[i]) return i;
        }

        return -1;
    }

    void Render()
    {
        UI::BeginGroup();
        UI::Text("");

        RenderStat(GetTotal() - finished, Medals::Unfinished); // unfinished
        RenderStat(finished, Medals::NoMedal);

        for (int i = 0; i < pvm.labels.Length; i++)
        {
            RenderStat(counts[i], pvm.labels[i]);
        }

        UI::EndGroup();
    }

    private void RenderStat(int amount, MedalLabel@ label)
    {
        UI::SameLine();
        UI::Text(label.GetIcon() + "\\$z (" + amount + "/" + GetTotal() + ")");
        if (UI::IsItemHovered())
        {
            UI::BeginTooltip();
            UI::Text(label.GetLabel());
            UI::EndTooltip();
        }
    }
}