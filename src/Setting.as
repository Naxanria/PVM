namespace Setting
{
    [Setting name="Show pvm" category="PVM"]
    bool pvm_show = true;
    [Setting name="Hide when Interface is hidden" category="PVM"]
    bool pvm_hide_on_interface_hidden = true;
    [Setting name="Show map name" category="PVM"]
    bool pvm_header_map_name = true;
    [Setting name="Show author name" category="PVM"]
    bool pvm_header_map_author = true;
    [Setting name="Show grade" category="PVM"]
    bool pvm_header_map_grade = true;
    

    [Setting name="Lock PVM Window Position" category="PVM"]
    bool window_lock_position = false;
    [Setting name="Window Position" category="PVM"]
    vec2 window_position = vec2(200, 200);

    [Setting name="Show Labels" category="PVM"]
    bool pvm_show_labels = true;
    [Setting name="Show personal best" category="PVM"]
    bool pvm_show_personal_best = true;
    [Setting name="Show delta" category="PVM"]
    bool pvm_show_delta = true;
    [Setting name="Show delta sign" category="PVM"]
    bool pvm_show_delta_sign = true;

    // [Setting name="pvm_extra_settings" category="PVM" hidden]
    // string pvm_extra_settings = "{}";

    [Setting name="show_overview" hidden category="Overview"]
    bool overview_show = true;
    [Setting name="Close overview when loading map" category="Overview"]
    bool overview_close_on_play = true;
    [Setting name="Show tooltip" category="Overview"]
    bool overview_tooltip_show = true;
    [Setting name="Show map thumbnail in tooltip" category="Overview"]
    bool overview_tooltip_thumbnail_show = true;
    [Setting name="Use tmx thumbnail, if available" category="Overview" if="Setting::overview_tooltip_thumbnail_show"]
    bool overview_tooltip_thumbnail_use_tmx = true;
    [Setting name="Map thumbnail size" category="Overview" min="128" max="512" if="Setting::overview_tooltip_thumbnail_show"]
    int overview_tooltip_thumbnail_size = 278;
    [Setting name="Show medal labels in thumbnail" category="Overview"]
    bool overview_tooltip_medals_show_label = true;
    [Setting name="Show map tmx id in overview" category="Overview"]
    bool overview_table_show_tmx_id = true;

    [Setting name="Logging Level" category="Debug"]
    Logging::LogLevel logging_level = Logging::LogLevel::Info;

    bool initialized = false;

    class PerPvmSettings
    {
        bool[] medalsEnabled;       
        private bool enabled = true;
        private PVM@ pvm;

        bool empty = true;

        PerPvmSettings()
        { }

        PerPvmSettings(PVM@ pvm)
        {
            @this.pvm = pvm;
            for (int i = 0; i < pvm.labels.Length; i++)
            {
                medalsEnabled.InsertLast(true);
            }
            empty = false;
        }

        PVM@ GetPvm()
        {
            return @pvm;
        }

        string GetName()
        {
            return pvm.Name;
        }

        int GetId()
        {
            return pvm.Id;
        }

        bool IsEnabled()
        {
            return enabled;
        }

        void SetEnabled(bool enabled)
        {
            this.enabled = enabled;
            pvm.enabled = enabled;
        }

        bool IsMedalEnabled(int idx)
        {
            return (idx >=0 && idx < medalsEnabled.Length) ? medalsEnabled[idx] : false;
        }

        void LoadFromJson(Json::Value@ json)
        {
            Logging::Info("Loading " + pvm.Id);
            if (!json.HasKey("m")) 
            {
                for (int i = 0; i < medalsEnabled.Length; i++)
                {
                    medalsEnabled[i] = true;
                }
                enabled = true;
                pvm.enabled = true;
                return;
            }
            Json::Value list = json["m"];
            enabled = json["e"];
            pvm.enabled = enabled;

            for (int i = 0; i < list.Length && i < medalsEnabled.Length; i++)
            {
                medalsEnabled[i] = list[i];
            }
        }

        Json::Value@ ToJson()
        {
            Json::Value obj = Json::Object();
            Json::Value list = Json::Array();
            for (int i = 0; i < medalsEnabled.Length; i++)
            {
                list.Add(Json::Value(medalsEnabled[i]));
            }
            obj["m"] = list;
            obj["e"] = enabled;
            return obj;
        }
    }

    dictionary perPvmSettings = {};
    string _pvmSettingsJson = "";

    void Init()
    {
        perPvmSettings = dictionary();
        for (int i = 0; i < pvms.Length; i++)
        {
            perPvmSettings[pvms[i].GetId()] = PerPvmSettings(pvms[i]);
        }
        initialized = true;
    }

    bool PvmShowMedal(int pvmId, int medalIndex)
    {
        return PvmShowMedal(pvmId + "", medalIndex);
    }

    bool PvmShowMedal(string pvmId, int medalIndex)
    {
        if (!perPvmSettings.Exists(pvmId)) return true; // show medal as default

        PerPvmSettings@ setting = GetPvmSettings(pvmId);
        return setting.IsMedalEnabled(medalIndex);
    }

    void OnSettingsSave(Settings::Section& section)
    {
        Json::Value obj = Json::Object();
        for (int i = 0; i < pvms.Length; i++)
        {
            int id = pvms[i].Id;
            PerPvmSettings@ setting = GetPvmSettings(id);
            obj[id + ""] = setting.ToJson();
        }
        section.SetString("pvm_extra_settings", Json::Write(obj));
    }

    void OnSettingsLoad(Settings::Section& section)
    {
        _pvmSettingsJson = section.GetString("pvm_extra_settings", "{}");        
    }

    void FinalizeLoadingPvmSettings()
    {
        if (_pvmSettingsJson == "{}")
        {
            Json::Value obj = Json::Object();

            // first load
            for (int i = 0; i < pvms.Length; i++)
            {
                int id = pvms[i].Id;
                PerPvmSettings@ setting = GetPvmSettings(id);
                obj[id + ""] = setting.ToJson();
            }
            _pvmSettingsJson = Json::Write(obj);
        }
        else
        {
            Json::Value obj = Json::Parse(_pvmSettingsJson);
            for (int i = 0; i < pvms.Length; i++)
            {
                int id = pvms[i].Id;
                PerPvmSettings@ setting = GetPvmSettings(id);
                setting.LoadFromJson(obj[id + ""]);
            }
        }
    }

    PerPvmSettings@ GetPvmSettings(int id)
    {
        return GetPvmSettings(id + "");
    }

    PerPvmSettings@ GetPvmSettings(string id)
    {
        if (!perPvmSettings.Exists(id)) return @PerPvmSettings();
        return cast<PerPvmSettings@>(perPvmSettings[id]);
    }

    bool PvmIsEnabled(int id)
    {
        auto s = GetPvmSettings(id);
        if (s.empty) return true;
        return s.IsEnabled();
    }

    void PvmSetEnabled(int id, bool enabled)
    {
        GetPvmSettings(id).SetEnabled(enabled);
    }

    void PvmToggleEnabled(int id)
    {
        PerPvmSettings@ settings = GetPvmSettings(id);
        settings.SetEnabled(!settings.IsEnabled());
    }


    //////////////////////////////////////////////


    [SettingsTab name="Per pvm settings" icon=""]
    void RenderPerPvmExtraSettings()
    {
        if (!initialized) return;
        
        UI::BeginTabBar("pvm_settings_tab_bar");

        for (int i = 0; i < pvms.Length; i++)
        {
            PerPvmSettings@ setting = GetPvmSettings(pvms[i].GetId());
            PVM@ pvm = setting.GetPvm();
            if (pvm is null) continue;

            if (UI::BeginTabItem(pvm.Name))
            {
                bool enabled = setting.IsEnabled();
                bool newEnabled = UI::Checkbox("Enabled", enabled);
                if (newEnabled != enabled)
                {
                    setting.SetEnabled(newEnabled);
                }

                UI::Text("Show medals: ");

                for (int m = pvm.labels.Length - 1; m >= 0; m--)
                {
                    if (m >= setting.medalsEnabled.Length) continue;
                    setting.medalsEnabled[m] = UI::Checkbox(pvm.labels[m].GetFull(), setting.medalsEnabled[m]);
                }      

                UI::EndTabItem();          
            }
        }

        UI::EndTabBar();        
    }
}