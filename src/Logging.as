namespace Logging
{    
    enum LogLevel
    {
        Error,
        Warn,
        Info,
        Debug,
        Trace
    }

    LogLevel GetLogLevel()
    {
        return Setting::logging_level;
    }

    bool IsDebugLogLevel()
    {
        return Setting::logging_level >= LogLevel::Debug;
    }

    string GetPluginName()
    {
        return Meta::ExecutingPlugin().Name;
    }

    void Error(const string &in msg, bool showNotification = false)
    {
        if (Setting::logging_level >= LogLevel::Error)
        {
            if (showNotification)
            {
                vec4 col = vec4(1.0, 0., 0., 1.0);
                UI::ShowNotification(Icons::Kenney::ButtonTimes + " " + GetPluginName() + " - Error", msg, 10000);
            }

            error("[ERROR] " + msg);
        }
    }

    void Warn(const string &in msg, bool showNotification = false)
    {
        if (Setting::logging_level >= LogLevel::Warn)
        {
            if (showNotification)
            {
                vec4 col = vec4(1.0, 0.7, 0., 1.0);
                UI::ShowNotification(Icons::Kenney::ButtonTimes + " " + GetPluginName() + " - Warning", msg, 5000);
            }

            warn("[WARN] " + msg);
        }
    }

    void Info(const string &in msg)
    {
        if (Setting::logging_level >= LogLevel::Info)
        {
            print("[INFO] " + msg);
        }
    }

    void Debug(const string &in msg)
    {
        if (Setting::logging_level >= LogLevel::Debug)
        {
            print("[DEBUG] " + msg);
        }
    }

    void Trace(const string &in msg)
    {
        if (Setting::logging_level >= LogLevel::Trace)
        {
            print("[TRACE] " + msg);
        }
    }
}