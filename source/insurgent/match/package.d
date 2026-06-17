module insurgent.match;

public import insurgent.match.nation;
public import insurgent.match.stack;
public import insurgent.match.unit;
public import insurgent.match.tile;
public import insurgent.match.building;

import insurgent.match.internal;

import selenium : Driver;

class Match
{
public:
    int gameID;
    Stack selectedStack;
    Tile selectedTile;

    Nation[] nations()
    {
        Nation[] ret;
        foreach (nation; _nationsByID)
            ret ~= nation;
        return ret;
    }

    Stack[] stacks()
    {
        Stack[] ret;
        foreach (stack; _stacksByID)
            ret ~= stack;
        return ret;
    }

    Tile[] tiles()
    {
        Tile[] ret;
        foreach (tile; _tilesByID)
            ret ~= tile;
        return ret;
    }

    Nation nationByID(int id)
    {
        if (Nation* n = id in _nationsByID)
            return *n;
        return null;
    }

    Stack stackByID(int id)
    {
        if (Stack* s = id in _stacksByID)
            return *s;
        return null;
    }

    Tile tileByID(int id)
    {
        if (Tile* t = id in _tilesByID)
            return *t;
        return null;
    }

    void delegate(bool success, string err) onUpdate;
    void delegate() onSelectionUpdate;

    void refresh(Driver driver)
    {
        internalRefresh(driver, this, (bool success, string err) {
            if (onUpdate !is null)
                onUpdate(success, err);
        });
    }

    void refreshSelection(Driver driver)
    {
        internalRefreshSelection(driver, this, () {
            if (onSelectionUpdate !is null)
                onSelectionUpdate();
        });
    }

    void loadFromCache(int gameID)
    {
        internalLoadMatchFromCache(gameID, this);
    }

package(insurgent.match):
    Nation[int] _nationsByID;
    Stack[int] _stacksByID;
    Tile[int] _tilesByID;
}
