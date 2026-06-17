module insurgent.store.internal.extract;

import insurgent.store.internal.parse;
import insurgent.cache : cache, scriptVersion;

import selenium : Driver;

import std.string : indexOf;

package(insurgent.store):

enum extractionScript = import("extract.js");

void internalLoad(void delegate(bool success, string err) onComplete)
{
    string jsonStr;
    if (checkStaticCache(jsonStr))
    {
        bool success = parseResult(jsonStr);
        if (success)
        {
            onComplete(true, null);
            return;
        }
    }

    onComplete(false, "No cache available. Call Store.refresh(Driver) to load from game.");
}

void internalRefresh(
    Driver driver,
    void delegate(bool success, string err) onComplete
)
{
    if (driver is null)
    {
        onComplete(false, "Driver is null");
        return;
    }

    string uri;
    try
        uri = driver.url();
    catch (Exception e)
    {
        onComplete(false, "Failed to read URL: "~e.msg);
        return;
    }

    if (uri is null
        || uri.indexOf("gameID=-1") != -1
        || uri.indexOf("gameID=") == -1)
    {
        onComplete(false, "Not in a game");
        return;
    }

    bool success = false;
    string err = null;

    try
    {
        string jsonStr = driver.execute("return ("~extractionScript~");");
        if (jsonStr.length == 0)
            err = "JS returned no string.";
        else
        {
            success = parseResult(jsonStr);
            if (success)
                cache.saveStatic(jsonStr, scriptVersion());
            else
                err = "Parse failed.";
        }
    }
    catch (Exception e)
    {
        err = "Error: "~e.msg;
    }

    onComplete(success, err);
}
