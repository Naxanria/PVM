namespace Overview
{
    OverviewTab@[] tabs;
    [Setting name="overview_active_tab" category="misc" hidden]
    int activeTab = 1;

    bool initialized = false;

    bool firstLoad = true;
    bool needsRefresh = false;

    float widthName, widthTime, widthMedal, widthGrade, widthTmxId;
    
    void Init()
    {
        widthName = UI::MeasureString("AAAAAAAAAAAAAAAAAAAAAAAA").x;
        widthTime = UI::MeasureString("10:59:59.999").x;
        widthMedal = UI::MeasureString(Icons::Circle).x;
        widthGrade = UI::MeasureString("AAAAAAAAAAAAAAAA").x;
        widthTmxId = UI::MeasureString("399999").x;
        
        initialized = true;
    }

    void Reload()
    {
        if (tabs.Length > 0)
        {
            tabs.RemoveRange(0, tabs.Length);
        }
        Load();
    }

    void Load()
    {
        for (int i = 0; i < pvms.Length; i++)
        {
            if (!Setting::PvmIsEnabled(pvms[i].GetId())) continue;
            tabs.InsertLast(OverviewTab(@pvms[i]));
        }

        if (tabs.Length == 0)
        {
            activeTab = 0;
            return;
        }

        if (activeTab < 0 || activeTab >= tabs.Length)
        {
            activeTab = 0;
        }
        else if (!Setting::PvmIsEnabled(tabs[activeTab].GetPvm().GetId()))
        {
            activeTab = 0;
        }
    }

    void ValidateActiveTab()
    {
        if (tabs.Length == 0)
        {
            activeTab = 0;
            return;
        }

        if (activeTab < 0 || activeTab >= tabs.Length)
        {
            activeTab = 0;
            return;
        }

        if (!Setting::PvmIsEnabled(tabs[activeTab].GetPvm().GetId()))
        {
            activeTab = 0;
        }
    }

    void Render()
    {
        if (!Setting::overview_show) return;
        if (!initialized) Init();

        if (needsRefresh)
        {
            Reload();
            needsRefresh = false;
        }

        if (tabs.Length == 0)
        {
            return;
        }

        ValidateActiveTab();
        if (activeTab < 0 || activeTab >= tabs.Length)
        {
            activeTab = 0;
        }
        if (tabs.Length == 0) return;

        vec2 size = vec2(800, 600);
        vec2 pos = (vec2(Display::GetWidth(), Display::GetHeight()) - size) / 2;

        UI::SetNextWindowSize(int(size.x), int(size.y));
        UI::SetNextWindowPos(int(pos.x), int(pos.y));

        bool open = true;
        if (UI::Begin("PVM Overview", open))
        {
            if (!open)
            {
                Setting::overview_show = false;
                UI::End();
                return;
            }

            UI::BeginTabBar("pvm_tab_bar");
            
            for (int i = 0; i < tabs.Length; i++)
            {                
                OverviewTab@ tab = tabs[i];
                if (!Setting::PvmIsEnabled(tab.GetPvm().GetId()))
                {
                    continue;
                }

                UI::TabItemFlags flags = UI::TabItemFlags::None;
                if (firstLoad && activeTab == i)
                {
                    flags = UI::TabItemFlags::SetSelected;
                }

                if (UI::BeginTabItem(tab.GetName(), flags))
                {
                    if (firstLoad)
                    {
                        if (activeTab != i)
                        {
                            UI::EndTabItem();
                            continue;
                        }

                    }

                    firstLoad = false;
                    activeTab = i;
                    
                    tab.Render();

                    UI::EndTabItem();
                }
            }

            UI::EndTabBar();

            UI::End();
        }
    }
}