module insurgent.store.internal.parse;

import insurgent.store.unit;
import insurgent.store.building;
import insurgent.store.research;
import insurgent.store.common;
import insurgent.store.resource;
import insurgent.store.tile;

import std.json;
import std.conv : to;
import std.algorithm : sort;

package(insurgent.store):

JSONValue[] asArray(JSONValue value)
{
    if (value.type == JSONType.array)
        return value.array;
    return null;
}

int asInt(JSONValue value)
{
    switch (value.type)
    {
    case JSONType.integer:
        return cast(int)value.integer;
    case JSONType.uinteger:
        return cast(int)value.uinteger;
    case JSONType.float_:
        return cast(int)value.floating;
    default:
        return 0;
    }
}

float asFloat(JSONValue value)
{
    switch (value.type)
    {
    case JSONType.integer:
        return cast(float)value.integer;
    case JSONType.uinteger:
        return cast(float)value.uinteger;
    case JSONType.float_:
        return cast(float)value.floating;
    default:
        return 0;
    }
}

string asString(JSONValue value)
    => value.type == JSONType.string ? value.str : "";

bool asBool(JSONValue value)
    => value.type == JSONType.true_;

bool isValidStaticCache(string jsonStr)
{
    try
    {
        JSONValue root = parseJSON(jsonStr);
        if (root.type != JSONType.object)
            return false;
        if ("staticData" !in root.object)
            return false;
        if ("buildings" !in root["staticData"].object)
            return false;
        if ("researches" !in root["staticData"].object)
            return false;
        if ("units" !in root["staticData"].object)
            return false;
        return true;
    }
    catch (Exception)
    {
        return false;
    }
}

bool checkStaticCache(out string jsonStr)
{
    import insurgent.cache : cache, scriptVersion;

    string version_;
    if (!cache.loadStatic(jsonStr, version_))
        return false;

    if (version_ != scriptVersion())
    {
        cache.invalidateStatic();
        return false;
    }

    if (!isValidStaticCache(jsonStr))
    {
        cache.invalidateStatic();
        return false;
    }

    return true;
}

float[Resource] parseResourceMap(JSONValue value)
{
    float[Resource] ret;
    foreach (item; asArray(value))
    {
        Resource resource = cast(Resource)asInt(item["resourceID"]);
        ret[resource] = asFloat(item["amount"]);
    }
    return ret;
}

float[int] parseTerrainMap(JSONValue value)
{
    float[int] ret;
    foreach (item; asArray(value))
    {
        int terrainID = asInt(item["terrainTypeID"]);
        ret[terrainID] = asFloat(item["value"]);
    }
    return ret;
}

float[int] parseDamageStats(JSONValue value)
{
    float[int] ret;
    foreach (item; asArray(value))
    {
        int damageTypeID = asInt(item["damageTypeID"]);
        ret[damageTypeID] = asFloat(item["value"]);
    }
    return ret;
}

float[int] parseUnitFeatures(JSONValue value)
{
    float[int] ret;
    foreach (item; asArray(value))
    {
        int fid = asInt(item["featureID"]);
        ret[fid] = asFloat(item["value"]);
    }
    return ret;
}

int[int] parseDamageWeights(JSONValue value)
{
    int[int] ret;
    foreach (item; asArray(value))
    {
        int terrainID = asInt(item["terrainTypeID"]);
        ret[terrainID] = asInt(item["value"]);
    }
    return ret;
}

Missiles[MissileType] parseMissiles(JSONValue value)
{
    Missiles[MissileType] ret;
    foreach (item; asArray(value))
    {
        MissileType missileType = cast(MissileType)asInt(item["missileTypeID"]);
        Missiles missiles;
        missiles.capacity = asInt(item["capacity"]);
        missiles.resupplyTime = asInt(item["resupplyTime"]);
        missiles.initialInventory = asInt(item["initialInventory"]);
        ret[missileType] = missiles;
    }
    return ret;
}

ArmyBonus[DamageType] parseArmyBonus(JSONValue value)
{
    ArmyBonus[DamageType] ret;
    foreach (item; asArray(value))
    {
        DamageType damageType = cast(DamageType)asInt(item["damageTypeID"]);
        ArmyBonus bonus;
        bonus.attackFactor = asFloat(item["attackFactor"]);
        bonus.defenseFactor = asFloat(item["defenseFactor"]);
        bonus.speedFactor = asFloat(item["speedFactor"]);
        ret[damageType] = bonus;
    }
    return ret;
}

void parseBuildings(JSONValue value)
{
    Building[int] byID;
    int[int] replacedBy;

    foreach (item; asArray(value))
    {
        Building building = Building.getOrCreate(asInt(item["buildingID"]));
        building.name = asString(item["name"]);
        building.description = asString(item["description"]);
        building.imageKey = asString(item["image"]);
        building.dayAvailable = asInt(item["dayAvailable"]);
        building.tier = asInt(item["tier"]);
        building.minHealth = asFloat(item["minHealth"]);
        building.maxHealth = asFloat(item["maxHealth"]);
        building.buildTime = asInt(item["buildTime"]);
        building.costs = parseResourceMap(item["costs"]);
        building.upkeep = parseResourceMap(item["upkeep"]);
        building.production = parseResourceMap(item["production"]);

        int buildingId = asInt(item["buildingID"]);
        int replaced = asInt(item["replacedUpgrade"]);
        byID[buildingId] = building;
        if (replaced != 0)
            replacedBy[replaced] = buildingId;

        foreach (f; asArray(item["features"]))
        {
            int featureID = asInt(f["featureID"]);
            if (featureID == 5)
                building.moraleMod = cast(int)asFloat(f["value"]);
            else if (featureID == 10)
                building.destroyOnConquer = asFloat(f["value"]) == 1;
            else if (featureID == 19)
                building.bolusVP = asInt(f["value"]);
            else if (featureID == 3)
                building.mobilizationMod = 1 + asFloat(f["value"]);
            else if (featureID == 26)
                building.enablesMobilize = asInt(f["value"]) == 1;
        }

        int[] possibleStates;
        foreach (state; asArray(item["possibleProvinceStates"]))
            possibleStates ~= asInt(state);
        if (possibleStates.length > 0)
            building.tileType = cast(TileType)possibleStates[0];

        JSONValue vpConfig = item["victoryPointsGenerationConfig"];
        if (vpConfig.type == JSONType.object)
            building.dailyVP = asInt(vpConfig["dailyVictoryPoints"]);

        JSONValue speedConfig = item["constructionSpeedupConfig"];
        if (speedConfig.type == JSONType.object)
        {
            int constructionClass = asInt(speedConfig["constructionClass"]);
            float factor = asFloat(speedConfig["factor"]);
            if (constructionClass == 1)
                building.populationMod = factor;
            else if (constructionClass == -1)
                building.constructionMod = factor;
        }

        JSONValue healConfig = item["healArmiesConfig"];
        if (healConfig.type == JSONType.object)
        {
            float maxHeal = 0;
            foreach (h; asArray(healConfig["healingRateByArmorClass"]))
            {
                float rate = asFloat(h["rate"]);
                float healPerDay = rate * 24.0f;
                if (healPerDay > maxHeal)
                    maxHeal = healPerDay;
            }
            building.healMod = maxHeal;
        }
    }

    import insurgent.store : Store;
    Store.buildings = assembleChains!Building(byID, replacedBy);
}

void parseResearches(JSONValue value)
{
    Research[int] byID;
    int[int] replacedBy;
    int[int][int] rawRequires;

    foreach (item; asArray(value))
    {
        Research node = Research.getOrCreate(asInt(item["researchID"]));
        node.name = asString(item["name"]);
        node.imageKey = asString(item["image"]);
        node.costs = parseResourceMap(item["costs"]);

        int researchId = asInt(item["researchID"]);
        int replaced = asInt(item["replacedResearch"]);
        byID[researchId] = node;
        if (replaced != 0)
            replacedBy[replaced] = researchId;

        foreach (req; asArray(item["requiredResearches"]))
        {
            int rid = asInt(req["researchID"]);
            int level = asInt(req["level"]);
            rawRequires[researchId][rid] = level;
        }
    }

    import insurgent.store : Store;
    Store.research = assembleChains!Research(byID, replacedBy);

    foreach (chain; Store.research)
    {
        foreach (i, node; chain)
        {
            int myID = findID(byID, node);
            if (myID == 0 || myID !in rawRequires)
                continue;
            int predecessorID = (i > 0) ? findID(byID, chain[i - 1]) : 0;
            foreach (rid, level; rawRequires[myID])
            {
                if (rid == predecessorID)
                    continue;
                if (Research* dep = rid in byID)
                    node.requires ~= *dep;
            }
        }
    }
}

void parseUnits(JSONValue value)
{
    struct FamilyMeta
    {
        string key;
        string name;
        string description;
        Faction faction;
        DamageType damageType;
        int productionLimit;
    }

    Unit[][string] byKey;
    FamilyMeta[string] metaByKey;
    int[int][Unit] transportIDs;

    JSONValue[] unitsArray = asArray(value);

    foreach (item; unitsArray)
    {
        try
        {
            DamageType damageType = cast(DamageType)asInt(item["damageType"]);
            float[int] rawAttack = parseDamageStats(item["attack"]);
            float[int] rawDefense = parseDamageStats(item["defense"]);
            float[int] rawSpeeds = parseTerrainMap(item["speeds"]);
            float[int] rawHitPoints = parseTerrainMap(item["hitPoints"]);
            float[int] rawRanges = parseTerrainMap(item["ranges"]);
            float[int] rawViewWidths = parseTerrainMap(item["viewWidths"]);
            float[int] unitFeatures = parseUnitFeatures(item["unitFeatures"]);
            int[int] damageWeights = parseDamageWeights(item["damageWeights"]);

            Unit unit = new Unit(
                damageType,
                rawAttack,
                rawDefense,
                rawSpeeds,
                rawHitPoints,
                rawRanges,
                rawViewWidths,
                unitFeatures,
                damageWeights);

            string familyKey = asString(item["familyKey"]);
            Faction faction = cast(Faction)asInt(item["faction"]);

            import insurgent.store : Store;
            string key = Store.unitKey(familyKey, faction);

            unit.unitID = asInt(item["unitTypeID"]);
            unit.name = asString(item["name"]);
            unit.tier = asInt(item["tier"]);
            unit.imageKey = asString(item["image"]);
            unit.buildTimeSeconds = asInt(item["buildTimeSeconds"]);
            unit.maxFlightTime = asFloat(item["maxFlightTime"]);
            unit.friendlySpeedFactor = asFloat(item["friendlySpeedFactor"]);
            unit.foreignSpeedFactor = asFloat(item["foreignSpeedFactor"]);
            unit.missiles = parseMissiles(item["missiles"]);
            unit.costs = parseResourceMap(item["costs"]);

            unit.stealth = cast(Stealth)asInt(item["stealth"]);
            unit.revealStealth = cast(Stealth)asInt(item["revealStealth"]);
            unit.signatureType = cast(SignatureType)asInt(item["signatureType"]);
            unit.signature = cast(SignatureSize)asInt(item["signature"]);

            unit.radar.radius = cast(int)asFloat(item["radarRange"]);
            foreach (entry; asArray(item["radarEntries"]))
            {
                RadarEntry radarEntry;
                radarEntry.type = cast(SignatureType)asInt(entry["type"]);
                radarEntry.range = cast(int)asFloat(entry["range"]);
                radarEntry.resolution = cast(SignatureSize)asInt(entry["resolution"]);
                unit.radar.entries ~= radarEntry;
            }

            unit.antiAir.radius = cast(int)asFloat(item["antiAirRange"]);

            unit.patrol.radius = cast(int)asFloat(item["patrolRadius"]);
            foreach (target; asArray(item["patrolTargets"]))
                unit.patrol.targets ~= cast(DamageType)asInt(target);

            unit.perks = cast(Perks)asInt(item["perks"]);
            if (damageType != DamageType.Normal)
                unit.perks = cast(Perks)(cast(int)unit.perks & ~cast(int)Perks.ConquerTerritory);
            foreach (slot; asArray(item["carrierSlots"]))
                unit.carries[cast(DamageType)asInt(slot["damageTypeID"])] = asInt(slot["capacity"]);
            unit.armyBonus = parseArmyBonus(item["armyBonus"]);
            unit.upkeep = parseResourceMap(item["dailyCosts"]);

            foreach (req; asArray(item["requiredBuildings"]))
            {
                int bid = asInt(req["buildingID"]);
                if (Building* b = bid in Building.registry)
                    unit.requiredBuildings ~= *b;
            }

            foreach (req; asArray(item["requiredResearches"]))
            {
                int rid = asInt(req["researchID"]);
                if (Research* r = rid in Research.registry)
                    unit.requiredResearches ~= *r;
            }

            Terrain[] restricted;
            foreach (terrainVal; asArray(item["restrictedTerrains"]))
                restricted ~= cast(Terrain)asInt(terrainVal);
            unit.restrictedTerrains = restricted;

            int[int] transportIDMap;
            transportIDMap[0] = asInt(item["rotaryTransportUnitID"]);
            transportIDMap[1] = asInt(item["airTransportUnitID"]);
            transportIDMap[2] = asInt(item["seaTransportUnitID"]);
            transportIDs[unit] = transportIDMap;

            byKey[key] ~= unit;
            if (key !in metaByKey)
                metaByKey[key] = FamilyMeta(
                    familyKey,
                    asString(item["familyName"]),
                    asString(item["description"]),
                    faction,
                    damageType,
                    asInt(item["productionLimit"]));
        }
        catch (Exception e)
        {
        }
    }

    foreach (ref chain; byKey)
    {
        foreach (unit; chain)
            Unit.registry[unit.unitID] = unit;
    }

    import insurgent.store : Store;
    Store.unitFamilies = null;

    foreach (key, ref chain; byKey)
    {
        sort!((a, b) => a.tier < b.tier)(chain);

        Unit[] deduped;
        bool[int] seenTier;
        foreach (unit; chain)
        {
            if (unit.tier in seenTier)
                continue;
            seenTier[unit.tier] = true;
            deduped ~= unit;
        }

        UnitFamily family = new UnitFamily();
        FamilyMeta meta = metaByKey[key];
        family.key = meta.key;
        family.name = meta.name;
        family.description = meta.description;
        family.faction = meta.faction;
        family.damageType = meta.damageType;
        family.productionLimit = meta.productionLimit;
        foreach (unit; chain)
            unit.family = family;
        foreach (i, unit; deduped)
            unit.level = cast(int)i;
        family.units = deduped;
        Store.unitFamilies ~= family;
    }

    foreach (unit, ref transportIDMap; transportIDs)
    {
        if (int* tid = 0 in transportIDMap)
        {
            if (Unit* transport = *tid in Unit.registry)
                unit.rotaryTransport = *transport;
        }
        if (int* tid = 1 in transportIDMap)
        {
            if (Unit* transport = *tid in Unit.registry)
                unit.airTransport = *transport;
        }
        if (int* tid = 2 in transportIDMap)
        {
            if (Unit* transport = *tid in Unit.registry)
                unit.seaTransport = *transport;
        }
    }
}

bool loadStaticData(JSONValue value)
{
    if (value.type != JSONType.object)
        return false;

    if (Unit.registry.length != 0)
        return true;

    try
    {
        parseBuildings(value["buildings"]);
    }
    catch (Exception e)
    {
    }

    try
    {
        parseResearches(value["researches"]);
    }
    catch (Exception e)
    {
    }

    try
    {
        parseUnits(value["units"]);
    }
    catch (Exception e)
    {
    }

    return true;
}

bool parseResult(string jsonStr)
{
    if (jsonStr is null || jsonStr.length == 0)
        return false;

    JSONValue root = parseJSON(jsonStr);
    if (root.type != JSONType.object)
        return false;

    if ("error" in root.object)
        return false;

    return loadStaticData(root["staticData"]);
}

T[][] assembleChains(T)(T[int] byID, int[int] replacedBy)
{
    T[][] result;
    foreach (id, node; byID)
    {
        bool isRoot = true;
        foreach (predecessor, successor; replacedBy)
        {
            if (successor == id)
            {
                isRoot = false;
                break;
            }
        }
        if (!isRoot)
            continue;

        T[] chain;
        int current = id;
        while (current != 0)
        {
            T* _node = current in byID;
            if (_node is null)
                break;
            chain ~= *_node;
            current = replacedBy.get(current, 0);
        }
        result ~= chain;
    }
    return result;
}

int findID(T)(T[int] byID, T node)
{
    foreach (id, currentNode; byID)
    {
        if (currentNode is node)
            return id;
    }
    return 0;
}
