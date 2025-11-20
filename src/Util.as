namespace Utils
{   
    int Clamp(int val, int min, int max)
    {
        if (val < min) return min;
        if (val > max) return max;
        return val;
    }


    string FormatForSheet(int time)
    {
        if (time <= 0)
        {
            return "00:00:00.000";
        }

        int min = time / 60000;
        time -= min * 60000;
        
        int sec = time / 1000;
        time -= sec * 1000;

        int ms = time;

        return LeadZeroes(2, min) + ":" + LeadZeroes(2, sec) + "." + LeadZeroes(3, ms);
    }

    string LeadZeroes(int length, int n)
    {
        string s = "";
        for (int i = 1; i < length; i++)
        {
            if (n < Math::Pow(10, i))
            {
                s += "0";
            }
        }

        return s + n;
    }

    void TimeToClipboard(int time)
    {
        string pbString = Utils::FormatForSheet(time); 
        IO::SetClipboard(pbString);
        UI::ShowNotification(Icons::Clipboard + " Personal best time copied to clipboard " + pbString);
    }

    string GetHourGlass()
    {
        int t = Time::Stamp % 3;
        return t == 0 ? Icons::HourglassStart : (t == 1) ? Icons::HourglassHalf : Icons::HourglassEnd;
    }

    vec2 GetResized(vec2 size, float max, bool keepAspect = true)
    {
        if (!keepAspect)
        {
            return vec2(Math::Min(size.x, max), Math::Min(size.y, max));
        }

        float x = (size.x > size.y) ? max : size.x / size.y * max;
        float y = (size.y > size.x) ? max : size.y / size.x * max;

        return vec2(x, y);
    }

    bool IsInside(vec2 pos, vec4 bounds)
    {
        return bounds.x <= pos.x && bounds.z >= pos.x 
            && bounds.y <= pos.y && bounds.w >= pos.y;
    }

    string CheckIcon(bool test)
    {
        if (test)
        {
            return "\\$0e0" + Icons::Check + "\\$z";
        }

        return "\\$e00" + Icons::Times + "\\$z";
    }

    string ReadableTime(int time)
    {
        if (time <= 0)
        {
            return "-:--.---";
        }

        return Time::Format(time);
    }

}
