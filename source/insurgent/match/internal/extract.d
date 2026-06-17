module insurgent.match.internal.extract;

import insurgent.match.internal.parse;
import insurgent.match;

import selenium : Driver;

package(insurgent.match):

enum matchScript = import("match.js");
enum selectionScript = import("selection.js");

void internalRefresh(
    Driver driver,
    Match match,
    void delegate(bool success, string err) onComplete
)
{
    if (driver is null)
    {
        if (onComplete !is null)
            onComplete(false, "Driver is null");
        return;
    }

    bool success = false;
    string err = null;
    try
    {
        string jsonStr = driver.execute("return ("~matchScript~");");
        if (jsonStr.length == 0)
            err = "JS returned no string.";
        else
        {
            success = parseResult(jsonStr, match);
            if (!success)
                err = "Parse failed.";
        }
    }
    catch (Exception e)
    {
        err = e.msg;
    }

    if (onComplete !is null)
        onComplete(success, err);
}

void internalRefreshSelection(
    Driver driver,
    Match match,
    void delegate() onComplete
)
{
    if (driver is null)
    {
        if (onComplete !is null)
            onComplete();
        return;
    }

    try
    {
        string jsonStr = driver.execute("return ("~selectionScript~");");
        if (jsonStr.length > 0)
            parseSelection(jsonStr, match);
    }
    catch (Exception)
    {
    }

    if (onComplete !is null)
        onComplete();
}

void internalLoadMatchFromCache(int gameID, Match match)
{
    string jsonStr;
    if (!checkMatchCache(gameID, jsonStr))
        return;

    parseResult(jsonStr, match);
}
