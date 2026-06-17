module insurgent.store;

public import insurgent.store.assets;
public import insurgent.store.building;
public import insurgent.store.common;
public import insurgent.store.research;
public import insurgent.store.resource;
public import insurgent.store.tile;
public import insurgent.store.unit;

import insurgent.store.internal;

import selenium : Driver;

import std.conv : to;

class Store
{
public:
    static UnitFamily[] unitFamilies;
    static BuildingFamily[] buildingFamilies;
    static Research[][] research;
    static Building[][] buildings;

    static Unit[] units()
    {
        Unit[] ret;
        foreach (unit; Unit.registry)
            ret ~= unit;
        return ret;
    }

    static Building[] buildingsFlat()
    {
        Building[] ret;
        foreach (chain; buildings)
            ret ~= chain;
        return ret;
    }

    static Unit unitByID(int id)
    {
        if (Unit* u = id in Unit.registry)
            return *u;
        return null;
    }

    static Building buildingByID(int id)
    {
        if (Building* b = id in Building.registry)
            return *b;
        return null;
    }

    static Research researchByID(int id)
    {
        if (Research* r = id in Research.registry)
            return *r;
        return null;
    }

    static UnitFamily unitFamilyByKey(string key)
    {
        foreach (family; unitFamilies)
        {
            if (family.key == key)
                return family;
        }
        return null;
    }

    static BuildingFamily buildingFamilyByKey(string key)
    {
        foreach (family; buildingFamilies)
        {
            if (family.key == key)
                return family;
        }
        return null;
    }

    static Research[] researchChainFor(Research item)
    {
        foreach (chain; research)
        {
            foreach (node; chain)
            {
                if (node is item)
                    return chain;
            }
        }
        return null;
    }

    static Building[] buildingChainFor(Building item)
    {
        foreach (chain; buildings)
        {
            foreach (node; chain)
            {
                if (node is item)
                    return chain;
            }
        }
        return null;
    }

    static string unitKey(string familyKey, Faction faction)
    {
        if (faction == Faction.None)
            return familyKey;
        return familyKey ~ "|" ~ (cast(int)faction).to!string;
    }

    static void delegate(bool success, string err) onUpdate;

    static void load()
    {
        internalLoad((bool success, string err) {
            if (onUpdate !is null)
                onUpdate(success, err);
        });
    }

    static void refresh(Driver driver)
    {
        internalRefresh(driver, (bool success, string err) {
            if (onUpdate !is null)
                onUpdate(success, err);
        });
    }
}
