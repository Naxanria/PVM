namespace Setting
{
    [Setting name="Show Overview Hotkey" hidden]
    VirtualKey overview_hotkey_show = VirtualKey(0);
    [Setting name="Show PVM Window Hotkey" hidden]
    VirtualKey pvm_window_hotkey_show = VirtualKey(0);

    [SettingsTab name="Hotkeys" icon="Keyboard0"]
    void RenderHotkeySettings()
    {
        if (UI::Button("Reset to default"))
        {
            overview_hotkey_show = VirtualKey(0);
        }

        overview_hotkey_show = RenderHotKey("Show Overview", overview_hotkey_show);
        pvm_window_hotkey_show = RenderHotKey("Show PVM Window", pvm_window_hotkey_show);
    }


    VirtualKey RenderHotKey(string label, VirtualKey key)
    {
        UI::SetNextItemWidth(200);
        if (UI::BeginCombo(label, key == VirtualKey(0) ? "None" : tostring(key)))
        {
            string kString = tostring(key);
            for (int i = 0; i < 254; i++)
            {
                string iString = tostring(VirtualKey(i));
                
                bool currKey = iString == kString;

                if (iString == tostring(i)) continue; // skip numbers

                if (UI::Selectable(iString, currKey))
                {
                    key = VirtualKey(i);
                }
            }
            
            UI::EndCombo();
        }
        
        UI::SameLine();
        if (UI::Button("Reset"))
        {
            key = VirtualKey(0);
        }

        return key;
    }

}