module insurgent.store.building;

import insurgent.store.resource : Resource;
import insurgent.store : Store;
import insurgent.store.tile : TileType;

class Building
{
public:
    static Building[int] registry;

    int buildingID;
    string name;
    string description;
    string imageKey;
    int dayAvailable;
    int tier;
    float minHealth;
    float maxHealth;
    TileType tileType;
    int buildTime;
    float[Resource] costs;
    float[Resource] upkeep;
    float[Resource] production;
    bool destroyOnConquer;
    bool enablesMobilize;
    int dailyVP;
    int bolusVP;
    int moraleMod = 0;
    float constructionMod = 0;
    float populationMod = 0;
    float mobilizationMod = 0;
    float healMod = 0;

    BuildingFamily family;

    Building[] chain()
        => Store.buildingChainFor(this);

package(insurgent.store):
    static Building getOrCreate(int buildingID)
    {
        assert(buildingID != 0, "buildingID must not be zero");
        if (auto p = buildingID in registry)
            return *p;

        Building ret = new Building(buildingID);
        registry[buildingID] = ret;
        return ret;
    }

    this(int buildingID)
    {
        assert(buildingID != 0, "buildingID must not be zero");
        this.buildingID = buildingID;
    }
}

class BuildingFamily
{
public:
    string key;
    string name;
    string description;
    Building[] buildings;
}
