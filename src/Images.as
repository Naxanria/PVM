namespace Images
{
    class CachedImage
    {
        string url;
        string fallback = "";
        UI::Texture@ texture;
        int responseCode;
        bool error = false;
        bool notFound = false;
        bool unsupportedFormat = false;

        void DownloadAsync()
        {        
            Logging::Debug("Loading texture " + url);
            auto req = API::GetHttp(url);
            while (!req.Finished())
            {
                yield();
            }
            responseCode = req.ResponseCode();
            if (responseCode == 200) // OK
            {
                string header = req.Buffer().ReadString(4);
                if (header == "RIFF")
                {
                    if (fallback == "")
                    {
                        error = true;
                        unsupportedFormat = true;
                    }
                    else
                    {
                        Logging::Debug("webp format found, falling back");
                        auto req2 = API::GetHttp(fallback);
                        while (!req2.Finished())
                        {
                            yield();
                        }
                        if (req2.ResponseCode() == 200)
                        {
                            LoadFromBuffer(req2.Buffer());
                            if (!CheckTextureOK())
                            {
                                @texture = null;
                                error = true;
                                Logging::Debug("Fallback failed");
                            }
                        }
                        else
                        {
                            error = true;
                            unsupportedFormat = true;
                            Logging::Debug("No image found");
                        }
                    }
                }
                else
                {
                    req.Buffer().Seek(0);
                    LoadFromBuffer(req.Buffer());
                    if (!CheckTextureOK())
                    {
                        @texture = null;
                        error = true;
                        unsupportedFormat = true;
                    }
                    else
                    {
                        Logging::Debug("Loaded texture: " + url);
                    }
                }
            }
            else
            {
                notFound = responseCode == 404;
                error = true;
            }
        }

        private UI::Texture@ LoadFromBuffer(MemoryBuffer@ buffer)
        {
            @texture = UI::LoadTexture(buffer);
            return @texture;
        }

        private bool CheckTextureOK()
        {
            return @texture !is null && texture.GetSize().x > 0;
        }
    }

    dictionary cachedImages;

    CachedImage@ FindExisting(const string &in url)
    {
        if (url == "")
        {
            return null;
        }

        CachedImage@ img = null;
        cachedImages.Get(url, @img);
        return img;
    }

    CachedImage@ GetFromUrl(const string &in url, const string &in fallback = "")
    {
        CachedImage@ existing = FindExisting(url);
        if (existing !is null)
        {
            return existing;
        }

        CachedImage@ img = CachedImage();
        img.url = url;
        img.fallback = fallback;
        cachedImages.Set(url, @img);

        startnew(CoroutineFunc(img.DownloadAsync));
        return img;
    }

    CachedImage@ GetFromTmxId(int tmxId)
    {
        if (!Setting::overview_tooltip_thumbnail_use_tmx)
        {
            return GetFromUrl(GetImageUrlFallback(tmxId));
        }
        return GetFromUrl(GetImageUrl(tmxId), GetImageUrlFallback(tmxId));
    }

    string GetImageUrl(int tmxId)
    {
        return "https://trackmania.exchange/mapimage/" + tmxId + "/1?hq=true";
    }

    string GetImageUrlFallback(int tmxId)
    {
        return "https://trackmania.exchange/mapimage/" + tmxId + "/0?hq=true";
    }
}