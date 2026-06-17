/// Filesystem-backed cache for extracted static and match JSON, plus
/// resolution of the per-user cache directory and the extraction script
/// version key used to invalidate stale static data.
module insurgent.cache;

import std.algorithm : sort;
import std.conv : to;
import std.datetime : Clock, Duration, SysTime;
import std.digest.md : md5Of, toHexString;
import std.file : dirEntries, exists, mkdirRecurse, readText, remove, rename, SpanMode, timeLastModified, write;
import std.json : parseJSON, JSONValue;
import std.path : buildPath, expandTilde;

/// Controls how aggressively match snapshots are persisted to disk.
enum CachePolicy
{
    /// Match snapshots are never written to disk.
    MemoryOnly,
    /// Match snapshots are written at most once per throttle window.
    Throttled,
    /// Every match snapshot is written immediately.
    Persistent
}

/// Storage backend for the extracted static dataset and per-match snapshots.
interface DataCache
{
    /// Reads the cached static dataset and its version key.
    bool loadStatic(out string data, out string version_);
    /// Persists the static dataset under the given version key.
    void saveStatic(string data, string version_);
    /// Drops the cached static dataset.
    void invalidateStatic();

    /// Reads the cached snapshot for a match.
    bool loadMatch(int gameID, out string data);
    /// Persists a match snapshot subject to the active policy.
    void saveMatch(int gameID, string data);
    /// Drops the cached snapshot for a match.
    void invalidateMatch(int gameID);

    /// Sets the policy governing match snapshot persistence.
    void setMatchPolicy(CachePolicy policy);
    /// Prunes stale and surplus match snapshots.
    void cleanup();
}

/// Absolute path to the per-user cache directory for this application.
string cacheDir()
{
    version (Windows)
    {
        import std.process : environment;

        string base = environment.get("LOCALAPPDATA");
        if (base is null)
            base = environment.get("USERPROFILE");

        if (base is null)
            throw new Exception("Cannot determine cache directory");

        return buildPath(base, "insurgent");
    }
    else version (OSX)
        return expandTilde("~/Library/Caches/insurgent");
    else
        return expandTilde("~/.cache/insurgent");
}

/// Lazily constructed process-wide cache instance.
DataCache cache()
{
    static DataCache ret;
    if (ret is null)
        ret = new FsDataCache();

    return ret;
}

/// Stable version key derived from the bundled extraction script, used to
/// detect when cached static data was produced by an older script.
string scriptVersion()
{
    static string ret;
    if (ret !is null)
        return ret;

    ubyte[16] hash = md5Of(import("extract.js"));
    ret = hash.toHexString.idup;
    return ret;
}

/// Filesystem implementation of `DataCache` rooted at `cacheDir`.
class FsDataCache : DataCache
{
private:
    enum staticFile = "static.json";
    enum matchSubdir = "match";
    enum maxMatchFiles = 20;
    enum maxMatchDays = 7;
    enum throttleSeconds = 30;

    string root;
    string matchRoot;
    CachePolicy _policy = CachePolicy.Throttled;
    SysTime[int] lastWrite;

    string staticPath()
        => buildPath(root, staticFile);

    string matchPath(int gameID)
        => buildPath(matchRoot, gameID.to!string~".json");

    void atomicWrite(string path, string content)
    {
        string temp = path~".tmp";
        write(temp, content);
        rename(temp, path);
    }

    void enforceMaxFiles()
    {
        string[] files;
        foreach (entry; dirEntries(matchRoot, "*.json", SpanMode.shallow))
            files ~= entry.name;

        if (files.length <= maxMatchFiles)
            return;

        files.sort!((a, b) => timeLastModified(a) < timeLastModified(b));

        size_t surplus = files.length - maxMatchFiles;
        foreach (path; files[0..surplus])
            tryRemove(path);
    }

    static void tryRemove(string path)
    {
        try
            remove(path);
        catch (Exception)
        {
        }
    }

public:
    this()
    {
        root = cacheDir();
        matchRoot = buildPath(root, matchSubdir);
        if (!exists(root))
            mkdirRecurse(root);

        if (!exists(matchRoot))
            mkdirRecurse(matchRoot);
    }

    bool loadStatic(out string data, out string version_)
    {
        string path = staticPath();
        if (!exists(path))
            return false;

        data = readText(path);
        if (data.length == 0)
            return false;

        try
        {
            JSONValue doc = parseJSON(data);
            if ("_meta" in doc.object && "version" in doc["_meta"].object)
                version_ = doc["_meta"]["version"].str;
        }
        catch (Exception)
        {
        }

        return true;
    }

    void saveStatic(string data, string version_)
    {
        JSONValue doc;
        try
            doc = parseJSON(data);
        catch (Exception)
            return;

        if ("_meta" !in doc.object)
            doc.object["_meta"] = JSONValue.init;

        doc["_meta"]["version"] = JSONValue(version_);
        doc["_meta"]["cachedAt"] = JSONValue(Clock.currTime.toISOExtString);
        atomicWrite(staticPath(), doc.toString);
    }

    void invalidateStatic()
    {
        string path = staticPath();
        if (exists(path))
            remove(path);
    }

    bool loadMatch(int gameID, out string data)
    {
        string path = matchPath(gameID);
        if (!exists(path))
            return false;

        data = readText(path);
        return data.length > 0;
    }

    void saveMatch(int gameID, string data)
    {
        if (_policy == CachePolicy.MemoryOnly)
            return;

        if (_policy == CachePolicy.Throttled)
        {
            SysTime now = Clock.currTime;
            if (SysTime* last = gameID in lastWrite)
            {
                if ((now - *last).total!"seconds" < throttleSeconds)
                    return;
            }

            lastWrite[gameID] = now;
        }

        enforceMaxFiles();
        atomicWrite(matchPath(gameID), data);
    }

    void invalidateMatch(int gameID)
    {
        string path = matchPath(gameID);
        if (exists(path))
            remove(path);

        lastWrite.remove(gameID);
    }

    void setMatchPolicy(CachePolicy policy)
    {
        _policy = policy;
    }

    void cleanup()
    {
        if (!exists(matchRoot))
            return;

        SysTime now = Clock.currTime;
        foreach (entry; dirEntries(matchRoot, "*.json", SpanMode.shallow))
        {
            if ((now - timeLastModified(entry.name)).total!"days" > maxMatchDays)
                tryRemove(entry.name);
        }

        enforceMaxFiles();
    }
}
