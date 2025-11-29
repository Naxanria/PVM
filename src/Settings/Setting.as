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
}