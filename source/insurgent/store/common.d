module insurgent.store.common;

import std.array : join;
import std.format : format;
import std.string : stripRight;

enum DamageType : int
{
    Normal = 0,
    Air = 1,
    Sea = 2,
    Building = 3,
    Hard = 4,
    Submarine = 5,
    Population = 7,
    Rotary = 8,
    SoftNBC = 11,
    HardNBC = 12,
    Missile = 13,
    Drone = 14,
    Special = 15,
}

enum Terrain : int
{
    Ground = 0,
    Air = 1,
    Sea = 2,
    Road = 3,
    Plains = 10,
    Mountain = 12,
    Forest = 13,
    Urban = 14,
    Jungle = 15,
    Tundra = 16,
    Desert = 17,
    HighSea = 19,
    Coastal = 20,
    Suburban = 21,
    River = 22
}

enum Faction : int
{
    None = 0,
    Western = 1,
    Eastern = 2,
    European = 3,
}

enum Domain { Ground, Air, Sea }

enum Perks : uint
{
    None = 0,
    SpecialProduction = 1 << 0,
    ArmyBoost = 1 << 2,
    Scout = 1 << 3,
    StormPosition = 1 << 4,
    Amphibious = 1 << 7,
    ConquerTerritory = 1 << 8,
    Uncontrollable = 1 << 9,
    Unproducible = 1 << 10,
    Kamikaze = 1 << 11,
}

enum Stealth : uint
{
    None = 0,
    Land = 1 << 0,
    Air = 1 << 1,
    Submarine = 1 << 2,
}

enum SignatureType : int
{
    None = 0,
    Ground = 1,
    Air = 2,
    Surface = 3,
    Submarine = 4,
    Rotary = 5,
}

enum SignatureSize : int
{
    None = 0,
    Low = 10,
    High = 30,
}

enum MissileType : int
{
    Cruise = 1,
    Ballistic = 2,
}

struct CombatStats
{
    float attackRange;
    float[DamageType] attack;
    float[DamageType] defense;
}

struct TerrainStats
{
    Terrain terrain;
    int weight;
    float speed;
    float hitPoints;
    float sight;
    float attackMod;
    float defenseMod;
}

struct ArmyBonus
{
    float attackFactor;
    float defenseFactor;
    float speedFactor;
}

struct RadarEntry
{
    SignatureType type;
    int range;
    SignatureSize resolution;
}

struct Radar
{
    int radius;
    RadarEntry[] entries;
}

struct Patrol
{
    int radius;
    DamageType[] targets;
}

struct AntiAir
{
    int radius;
}

struct Missiles
{
    int capacity;
    int resupplyTime;
    int initialInventory;
}

string name(DamageType damageType)
{
    final switch (damageType)
    {
    case DamageType.Normal:     return "Soft";
    case DamageType.Air:        return "Fixed-Wing";
    case DamageType.Sea:        return "Surface Ship";
    case DamageType.Building:   return "Buildings";
    case DamageType.Hard:       return "Hard";
    case DamageType.Submarine:  return "Submarine";
    case DamageType.Population: return "Population";
    case DamageType.Rotary:     return "Rotary";
    case DamageType.SoftNBC:    return "Soft NBC";
    case DamageType.HardNBC:    return "Hard NBC";
    case DamageType.Missile:    return "Missile";
    case DamageType.Drone:      return "Drone";
    case DamageType.Special:    return "Special";
    }
}

string name(Terrain terrain)
{
    final switch (terrain)
    {
    case Terrain.Ground:   return "Plains";
    case Terrain.Air:      return "Air";
    case Terrain.Sea:      return "Sea";
    case Terrain.Road:     return "Road";
    case Terrain.Plains:   return "Plains";
    case Terrain.Mountain: return "Mountain";
    case Terrain.Forest:   return "Forest";
    case Terrain.Urban:    return "Urban";
    case Terrain.Jungle:   return "Jungle";
    case Terrain.Tundra:   return "Tundra";
    case Terrain.Desert:   return "Desert";
    case Terrain.HighSea:  return "High Sea";
    case Terrain.Coastal:  return "Coastal";
    case Terrain.Suburban: return "Suburban";
    case Terrain.River:    return "River";
    }
}

Domain domain(DamageType damageType)
{
    switch (damageType)
    {
    case DamageType.Air, DamageType.Rotary, DamageType.Drone:
        return Domain.Air;
    case DamageType.Sea, DamageType.Submarine:
        return Domain.Sea;
    default:
        return Domain.Ground;
    }
}

bool isCombatDomain(Terrain terrain)
    => terrain >= Terrain.Ground && terrain <= Terrain.Sea;

bool isTerrainModifier(Terrain terrain)
    => terrain >= Terrain.Plains;

bool isAirDomain(Terrain terrain)
    => terrain == Terrain.Air || terrain == Terrain.Road;

int domainID(Terrain terrain)
{
    if (terrain == Terrain.Air)
        return 1;
    if (terrain == Terrain.Sea || terrain == Terrain.HighSea
        || terrain == Terrain.Coastal || terrain == Terrain.River)
    {
        return 2;
    }
    return 0;
}

string compactNumber(float value)
{
    string ret = format("%.2f", value);

    ret = stripRight(ret, "0");
    if (ret.length != 0 && ret[$ - 1] == '.')
        ret = ret[0 .. $ - 1];

    return ret.length != 0 ? ret : "0";
}

string joinOrDash(string[] parts)
    => parts.length == 0 ? "-" : parts.join(", ");
