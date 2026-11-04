namespace TableBuilder
{
    UI::TableFlags CombineFlags(UI::TableFlags left, UI::TableFlags right)
    {
        return UI::TableFlags(uint(left) | uint(right));
    }
}
