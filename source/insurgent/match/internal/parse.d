module insurgent.match.internal.parse;

import insurgent.match;
import insurgent.match.nation;
import insurgent.match.stack;
import insurgent.match.unit;
import insurgent.match.tile;
import insurgent.match.building;
import insurgent.store;

import std.json;

package(insurgent.match):

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

static ulong _lastHash;
static ulong _lastSelectionHash;

static ulong hashOf(string s)
{
    ulong hash = 5381;
    foreach (c; s)
        hash = ((hash << 5) + hash) + c;
    return hash;
}

bool isValidMatchCache(string jsonStr, int expectedGameID)
{
    try
    {
        JSONValue root = parseJSON(jsonStr);
        if (root.type != JSONType.object)
            return false;
        if ("gameID" !in root.object)
            return false;
        if (asInt(root["gameID"]) != expectedGameID)
            return false;
        if ("nations" !in root.object && "stacks" !in root.object && "tiles" !in root.object)
            return false;
        return true;
    }
    catch (Exception)
    {
        return false;
    }
}

bool checkMatchCache(int gameID, out string jsonStr)
{
    import insurgent.cache : cache;

    if (!cache.loadMatch(gameID, jsonStr))
        return false;

    if (!isValidMatchCache(jsonStr, gameID))
    {
        cache.invalidateMatch(gameID);
        return false;
    }

    return true;
}

bool parseResult(string jsonStr, Match match)
{
    try
    {
        ulong hash = hashOf(jsonStr);
        if (hash == _lastHash)
        {
            return true;
        }
        _lastHash = hash;

        JSONValue root = parseJSON(jsonStr);

        if ("error" in root.object)
        {
            return false;
        }

        match.gameID = asInt(root["gameID"]);

        int nationsCount = 0;
        int[] oldNationIDs = match._nationsByID.keys;
        bool[int] seenNation;
        foreach (player; root["nations"].array)
        {
            int playerID = asInt(player["playerID"]);
            seenNation[playerID] = true;

            Nation nation;
            if (playerID in match._nationsByID)
                nation = match._nationsByID[playerID];
            else
            {
                nation = new Nation();
                match._nationsByID[playerID] = nation;
            }

            nation.playerID = playerID;
            nation.sitePlayerId = asInt(player["sitePlayerId"]);
            nation.coalitionId = asInt(player["coalitionId"]);
            nation.name = asString(player["name"]);
            nation.nationName = asString(player["nationName"]);
            nation.vps = asInt(player["vps"]);
            nation.defeated = asBool(player["defeated"]);
            nation.retired = asBool(player["retired"]);
            nationsCount++;
        }
        foreach (id; oldNationIDs)
        {
            if (id !in seenNation)
                match._nationsByID.remove(id);
        }
        int stacksCount = 0;
        int unitsCount = 0;
        int[] oldStackIDs = match._stacksByID.keys;
        bool[int] seenStack;
        foreach (army; root["stacks"].array)
        {
            int armyID = asInt(army["armyID"]);
            seenStack[armyID] = true;

            Stack stack;
            if (armyID in match._stacksByID)
                stack = match._stacksByID[armyID];
            else
            {
                stack = new Stack();
                match._stacksByID[armyID] = stack;
            }

            stack.armyID = armyID;
            stack.ownerID = asInt(army["ownerID"]);
            stack.locationID = asInt(army["locationID"]);
            if ("paintedUnitTypeID" in army.object)
                stack.paintedUnitType = Store.unitByID(asInt(army["paintedUnitTypeID"]));

            stack.units = [];
            foreach (unitVal; army["units"].array)
            {
                MatchUnit unit = new MatchUnit();
                unit.type = Store.unitByID(asInt(unitVal["unitTypeID"]));
                unit.hitPoints = asFloat(unitVal["hitPoints"]);
                unit.size = asInt(unitVal["size"]);
                if (unit.size <= 0)
                    unit.size = 1;
                stack.units ~= unit;
                unitsCount++;
            }
            stacksCount++;
        }
        foreach (id; oldStackIDs)
        {
            if (id !in seenStack)
                match._stacksByID.remove(id);
        }
        int[] oldTileIDs = match._tilesByID.keys;
        bool[int] seenTile;
        foreach (tileVal; root["tiles"].array)
        {
            int tileID = asInt(tileVal["id"]);
            seenTile[tileID] = true;

            Tile tile;
            if (tileID in match._tilesByID)
                tile = match._tilesByID[tileID];
            else
            {
                tile = new Tile();
                match._tilesByID[tileID] = tile;
            }

            tile.id = tileID;
            tile.name = asString(tileVal["name"]);
            tile.ownerID = asInt(tileVal["ownerID"]);
            tile.legalOwnerID = asInt(tileVal["legalOwnerID"]);
            tile.tileType = cast(TileType)asInt(tileVal["tileType"]);
            tile.morale = asInt(tileVal["morale"]);
            tile.population = asInt(tileVal["population"]);
            tile.provinceLevel = asInt(tileVal["provinceLevel"]);
            tile.coastal = asBool(tileVal["coastal"]);
            tile.terrainType = asInt(tileVal["terrainType"]);
            tile.coreIDs = [];
            foreach (coreID; tileVal["coreIDs"].array)
                tile.coreIDs ~= asInt(coreID);
            tile.buildings = [];
            foreach (improvement; tileVal["improvements"].array)
            {
                MatchBuilding matchBuilding = new MatchBuilding();
                matchBuilding.definition = Store.buildingByID(asInt(improvement["itemID"]));
                matchBuilding.condition = asFloat(improvement["condition"]);
                matchBuilding.enabled = asBool(improvement["enabled"]);
                matchBuilding.constructing = asBool(improvement["constructing"]);
                tile.buildings ~= matchBuilding;
            }
        }
        foreach (id; oldTileIDs)
        {
            if (id !in seenTile)
                match._tilesByID.remove(id);
        }
        import insurgent.cache : cache;
        cache.saveMatch(match.gameID, jsonStr);

        return true;
    }
    catch (Exception e)
    {
        return false;
    }
}

bool parseSelection(string jsonStr, Match match)
{
    try
    {
        ulong hash = hashOf(jsonStr);
        if (hash == _lastSelectionHash)
            return true;
        _lastSelectionHash = hash;

        JSONValue root = parseJSON(jsonStr);

        if ("error" in root.object)
            return false;

        if (root["selectedStack"].type != JSONType.null_)
        {
            int armyID = asInt(root["selectedStack"]["armyID"]);
            if (armyID != 0)
                match.selectedStack = match.stackByID(armyID);
            else
                match.selectedStack = null;
        }
        else
        {
            match.selectedStack = null;
        }

        if (root["selectedTile"].type != JSONType.null_)
        {
            int tileID = asInt(root["selectedTile"]["id"]);
            if (tileID != 0)
                match.selectedTile = match.tileByID(tileID);
            else
                match.selectedTile = null;
        }
        else
        {
            match.selectedTile = null;
        }

        return true;
    }
    catch (Exception e)
    {
        return false;
    }
}
