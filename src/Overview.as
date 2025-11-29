namespace Overview
{
    OverviewTab@[] tabs;
    [Setting name="overview_active_tab" category="misc" hidden]
    int activeTab = 1;

    bool initialized = false;

    bool firstLoad = true;

    float widthName, widthTime, widthMedal, widthGrade, widthTmxId;
    
    void Init()
    {
        widthName = Draw::MeasureString("AAAAAAAAAAAAAAAAAAAAAAAA").x;
        widthTime = Draw::MeasureString("10:59:59.999").x;
        widthMedal = Draw::MeasureString(Icons::Circle).x;
        widthGrade = Draw::MeasureString("AAAAAAAAAAAAAAAA").x;
        widthTmxId = Draw::MeasureString("399999").x;
        
        initialized = true;
    }

    void Reload()
    {
        tabs.RemoveRange(0, tabs.Length);
        Load();
    }

    void Load()
    {
        for (int i = 0; i < pvms.Length; i++)
        {
            tabs.InsertLast(OverviewTab(@pvms[i]));
        }        
    }

    void Render()
    {
        if (!Setting::overview_show) return;
        if (!initialized) Init();

        if (activeTab >= tabs.Length) activeTab = 0;
        if (tabs.Length == 0) return;

        vec2 size = vec2(800, 600);
        vec2 pos = (vec2(Draw::GetWidth(), Draw::GetHeight()) - size) / 2;

        UI::SetNextWindowSize(int(size.x), int(size.y));
        UI::SetNextWindowPos(int(pos.x), int(pos.y));

        if (UI::Begin("PVM Overview", Setting::overview_show))
        {


            UI::BeginTabBar("pvm_tab_bar");
            
            for (int i = 0; i < tabs.Length; i++)
            {                
                OverviewTab@ tab = tabs[i];

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