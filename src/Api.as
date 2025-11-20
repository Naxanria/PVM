namespace API
{
    CNadeoServicesMap@ GetMapFromUid(const string &in mapUid)
    {
        auto app = cast<CGameManiaPlanet>(GetApp());
        auto userId = app.MenuManager.MenuCustom_CurrentManiaApp.UserMgr.Users[0].Id;
        auto resp = app.MenuManager.MenuCustom_CurrentManiaApp.DataFileMgr.Map_NadeoServices_GetFromUid(userId, mapUid);
        WaitAndClearTaskLater(resp, app.MenuManager.MenuCustom_CurrentManiaApp.DataFileMgr);

        if (resp.HasFailed || !resp.HasSucceeded) {
            UI::ShowNotification("Couldn't load map info :(");
            Logging::Warn('GetMapFromUid failed for ' + mapUid + ": " + resp.ErrorCode + ", " + resp.ErrorType + ", " + resp.ErrorDescription, true);
            return null;
        }
        return resp.Map;
    }

    uint Map_GetRecord_v2(const string &in mapUid)
    {
        auto app = cast<CGameManiaPlanet>(GetApp());
        auto mccma = app.MenuManager.MenuCustom_CurrentManiaApp;
        auto userId = mccma.UserMgr.Users[0].Id;
        return mccma.ScoreMgr.Map_GetRecord_v2(userId, mapUid, "PersonalBest", "", "TimeAttack", "");
    }

    CMapRecord@ GetPlayerRecordOnMap(const string &in mapUid)
    {
        auto app = cast<CGameManiaPlanet>(GetApp());
        auto mccma = app.MenuManager.MenuCustom_CurrentManiaApp;
        auto userId = mccma.UserMgr.Users[0].Id;

        MwFastBuffer<wstring> wsids = MwFastBuffer<wstring>();
        wsids.Add(mccma.LocalUser.WebServicesUserId);

        auto task = mccma.ScoreMgr.Map_GetPlayerListRecordList(userId, wsids, mapUid, "PersonalBest", "", "TimeAttack", "");
        
        WaitAndClearTaskLater(task, mccma.ScoreMgr);

        if (task.HasFailed || !task.HasSucceeded)
        {
            Logging::Warn("Failed to get player record on map: " + mapUid + " Error: " + task.ErrorCode + ", " + task.ErrorType + ", " + task.ErrorDescription, true);
        }

        if (task.MapRecordList.Length == 0)
        {
            return null;
        }

        return task.MapRecordList[0];
    }

    void WaitAndClearTaskLater(CWebServicesTaskResult@ task, CMwNod@ owner)
    {
        while (task.IsProcessing)
        {
            yield();
        }

        if (task.HasSucceeded)
        {
           tasksToClear.InsertLast(ClearTask(task, owner));
        }
    }
    class ClearTask
    {
        CWebServicesTaskResult@ task;
        CMwNod@ nod;

        CGameUserManagerScript@ userMgr { get { return cast<CGameUserManagerScript>(nod); } }
        CGameScoreAndLeaderBoardManagerScript@ scoreMgr { get { return cast<CGameScoreAndLeaderBoardManagerScript>(nod); } }
        CGameDataFileManagerScript@ dataFileMgr { get { return cast<CGameDataFileManagerScript>(nod); } }

        ClearTask(CWebServicesTaskResult@ task, CMwNod@ nod)
        {
            @this.task = task;
            @this.nod = nod;
        }

        void Release()
        {
            if (userMgr !is null) 
            {
                userMgr.TaskResult_Release(task.Id);
            }
            else if (scoreMgr !is null)
            {
                scoreMgr.TaskResult_Release(task.Id);
            }
            else if (dataFileMgr !is null)
            {
                dataFileMgr.TaskResult_Release(task.Id);
            }
            else
            {
                throw("Unknown task type! " + Reflection::TypeOf(nod).Name);
            }
        }

    }

    ClearTask@[] tasksToClear;

    void ClearTaskCoroutine()
    {
        while(true)
        {
            yield();
            if (tasksToClear.Length == 0)
            {
                continue;
            }

            int toClear = tasksToClear.Length;
            sleep(50);
            for (int i = 0; i < toClear; i++)
            {
                tasksToClear[i].Release();
            }
            tasksToClear.RemoveRange(0, toClear);
        }
    }

    void LoadMapNow(const string &in uid)
    {
        if (!Permissions::PlayLocalMap())
        {
            Logging::Error("Refusing to load map because you lack necessary permissions. Club access required", true);
            return;
        }
        auto map = GetMapFromUid(uid);
        string url = map.FileUrl;

        auto app = cast<CGameManiaPlanet>(GetApp());
        ReturnToMenu(true);
        app.ManiaTitleControlScriptAPI.PlayMap(url, "", "");
    }

    void ReturnToMenu(bool yieldTillReady = false)
    {
        auto app = cast<CGameManiaPlanet>(GetApp());
        if (app.Network.PlaygroundClientScriptAPI.IsInGameMenuDisplayed)
        {
            app.Network.PlaygroundInterfaceScriptHandler.CloseInGameMenu(CGameScriptHandlerPlaygroundInterface::EInGameMenuResult::Quit);
        }

        app.BackToMainMenu();
        while (yieldTillReady && !app.ManiaTitleControlScriptAPI.IsReady)
        {
            yield();
        }
    }

    Net::HttpRequest@ GetHttp(const string &in url)
    {
        Net::HttpRequest@ ret = Net::HttpRequest();
        ret.Url = url;
        // ret.Method = Net::HttpMethod::Get;
        ret.Start();
        return ret;
    }

    Json::Value@ GetJson(const string &in url)
    {
        auto ret = GetHttp(url);
        while(!ret.Finished())
        {
            yield();
        }
        return ret.Json();
    }
}