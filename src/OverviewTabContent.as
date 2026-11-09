namespace Overview
{
    class OverviewTabContent
    {
        private string search = "";

        bool RenderSearch(const string &in inputId)
        {
            UI::BeginGroup();
            UI::AlignTextToFramePadding();
            UI::Text("Search:");
            UI::SameLine();
            string oldSearch = search;
            UI::SetNextItemWidth(180.0f);
            search = UI::InputText("##" + inputId, oldSearch, UI::InputTextFlags::EscapeClearsAll);
            UI::EndGroup();
            return search != oldSearch;
        }

        void RenderSearchResultCount(uint resultCount)
        {
            if (search == "") return;

            UI::SameLine();
            string resultLabel = resultCount == 1 ? "result" : "results";
            UI::Text(resultCount + " " + resultLabel);
        }

        string GetSearch()
        {
            return search;
        }

        bool DrawSortHeader(const string &in label, bool isAscending, bool isDescending)
        {
            string display = label;
            if (isAscending)
            {
                display += Icons::CaretUp;
            }
            else if (isDescending)
            {
                display += Icons::CaretDown;
            }

            UI::Text(display);
            return UI::IsItemClicked();
        }

        vec4 GetRowColor(const string &in colorValue, uint rowIndex)
        {
            float stripe = rowIndex % 2 == 0 ? 0.68f : 1.12f;
            float alpha = rowIndex % 2 == 0 ? 0.08f : 0.10f;
            vec4 color;
            if (Text::TryParseHexColor(colorValue, color))
            {
                return vec4(color.x * stripe, color.y * stripe, color.z * stripe, alpha);
            }

            return vec4(0.10f, 0.10f, 0.10f, 0.06f);
        }
    }
}