module insurgent.store.unit;

import insurgent.store.common;
import insurgent.store.building : Building;
import insurgent.store.research : Research;
import insurgent.store.resource : Resource;

class Unit
{
public:
    static Unit[int] registry;

    int unitID;
    string name;
    string imageKey;
    int tier;
    int level;

    int buildTimeSeconds;
    float[Resource] costs;
    float[Resource] upkeep;

    Perks perks;
    ArmyBonus[DamageType] armyBonus;
    CombatStats combatStats;
    int[DamageType] carries;
    TerrainStats[Terrain] terrainStats;

    float maxFlightTime;
    float friendlySpeedFactor;
    float foreignSpeedFactor;
    Missiles[MissileType] missiles;

    Unit rotaryTransport;
    Unit airTransport;
    Unit seaTransport;

    Stealth stealth;
    Stealth revealStealth;
    SignatureType signatureType;
    SignatureSize signature;
    Radar radar;
    Patrol patrol;
    AntiAir antiAir;

    Building[] requiredBuildings;
    Research[] requiredResearches;
    Terrain[] restrictedTerrains;

    UnitFamily family;

    this(
        DamageType damageType,
        float[int] rawAttack,
        float[int] rawDefense,
        float[int] rawSpeeds,
        float[int] rawHitPoints,
        float[int] rawRanges,
        float[int] rawViewWidths,
        float[int] unitFeatures,
        int[int] damageWeights
    )
    {
        _damageType = damageType;
        buildTerrainStats(rawSpeeds, rawHitPoints, rawRanges, rawViewWidths, rawAttack, rawDefense, damageWeights);
        buildCombatStats(rawAttack, rawDefense, unitFeatures, rawRanges);
    }

    bool isProducible()
        => (perks & Perks.Unproducible) == 0;
    bool isControllable()
        => (perks & Perks.Uncontrollable) == 0;
    bool canConquer()
        => (perks & Perks.ConquerTerritory) != 0;
    bool canAirlift()
        => airTransport !is null;
    bool isAirmobile()
        => rotaryTransport !is null;
    bool isAmphibious()
        => (perks & Perks.Amphibious) != 0;
    bool canStormPosition()
        => (perks & Perks.StormPosition) != 0;
    bool isScout()
        => (perks & Perks.Scout) != 0;
    bool hasArmyBoost()
        => (perks & Perks.ArmyBoost) != 0;
    bool hasSpecialProduction()
        => (perks & Perks.SpecialProduction) != 0;
    bool isKamikaze()
        => (perks & Perks.Kamikaze) != 0;

    bool hasRadar()
        => radar.radius > 0;
    bool hasAntiAir()
        => antiAir.radius > 0;
    bool hasPatrol()
        => patrol.radius > 0;
    bool hasCarrierSlots()
        => carries.length > 0;
    bool hasMissileSlots()
        => missiles.length > 0;
    bool isFlightLimited()
        => maxFlightTime > 0;
    bool isTerrainRestricted()
        => restrictedTerrains.length > 0;

    bool isStealthed()
        => stealth != Stealth.None;
    bool canReveal(Stealth targetStealth)
        => targetStealth != Stealth.None && (revealStealth & targetStealth) == targetStealth;

    bool canDetect(Unit other)
    {
        if (other is null) return false;
        if (radar.radius == 0) return false;
        if (other.signature == SignatureSize.None) return false;

        if (other.stealth != Stealth.None
            && (revealStealth & other.stealth) == 0)
            return false;

        foreach (ref e; radar.entries)
        {
            if (e.type == other.signatureType
                && cast(int)other.signature >= cast(int)e.resolution)
                return true;
        }
        return false;
    }

    bool canEngage(DamageType damageType)
    {
        if (patrol.radius > 0)
        {
            foreach (t; patrol.targets)
            {
                if (t == damageType) return true;
            }
        }

        if (antiAir.radius > 0)
        {
            bool airClass = (damageType == DamageType.Air
                || damageType == DamageType.Rotary
                || damageType == DamageType.Missile);
            if (airClass && combatStats.attack.get(damageType, 0) > 0)
                return true;
        }
        return false;
    }

    bool canEngage(Unit other)
    {
        if (other is null || other.family is null) return false;
        if (other.stealth != Stealth.None
            && (revealStealth & other.stealth) == 0)
            return false;
        return canEngage(other.family.damageType);
    }

    float maxSpeed()
    {
        float ret = 0;
        foreach (ref stat; terrainStats)
        {
            if (stat.speed > ret)
                ret = stat.speed;
        }
        return ret;
    }

    float totalHealth()
    {
        float ret = 0;
        foreach (ref stat; terrainStats)
            ret += stat.hitPoints;
        return ret;
    }

    float baseSightRange()
    {
        if (TerrainStats* stat = Terrain.Air in terrainStats)
            return stat.sight;
        foreach (ref stat; terrainStats)
            return stat.sight;
        return 0;
    }

    float attackVs(DamageType damageType)
        => combatStats.attack.get(damageType, 0);

    float defenseVs(DamageType damageType)
        => combatStats.defense.get(damageType, 0);

    float getRangeFor(DamageType damageType)
        => combatStats.attackRange;

    float baseStrength()
    {
        foreach (damageType; [DamageType.Normal, DamageType.Air, DamageType.Sea])
            if (float* value = damageType in combatStats.attack)
                return *value;
        return 0;
    }

    float baseDefense()
    {
        foreach (damageType; [DamageType.Normal, DamageType.Air, DamageType.Sea])
            if (float* value = damageType in combatStats.defense)
                return *value;
        return 0;
    }

    int nativeWeight()
    {
        if (family !is null)
        {
            Terrain terrain;
            final switch (domain(family.damageType))
            {
            case Domain.Ground: terrain = Terrain.Ground; break;
            case Domain.Air: terrain = Terrain.Air; break;
            case Domain.Sea: terrain = Terrain.HighSea; break;
            }
            if (TerrainStats* stat = terrain in terrainStats)
                return stat.weight;
        }
        foreach (ref stat; terrainStats)
            return stat.weight;
        return 0;
    }

package(insurgent.store):
    static Unit getOrCreate(int unitID)
    {
        assert(unitID != 0, "unitID must not be zero");
        if (auto p = unitID in registry)
            return *p;

        Unit ret = new Unit(unitID);
        registry[unitID] = ret;
        return ret;
    }

    this(int unitID)
    {
        assert(unitID != 0, "unitID must not be zero");
        this.unitID = unitID;
    }

    void buildTerrainStats(
        float[int] speeds,
        float[int] hitPoints,
        float[int] ranges,
        float[int] viewWidths,
        float[int] rawAttack,
        float[int] rawDefense,
        int[int] damageWeights
    )
    {
        Domain domain = domain(_damageType);
        bool[int] seen;
        foreach (id, _; speeds) seen[id] = true;
        foreach (id, _; hitPoints) seen[id] = true;
        foreach (id, _; ranges) seen[id] = true;
        foreach (id, _; viewWidths) seen[id] = true;
        foreach (id, _; rawAttack) seen[id] = true;
        foreach (id, _; rawDefense) seen[id] = true;

        if (domain == Domain.Ground)
        {
            seen[0] = true;
            seen[17] = true;
        }
        else if (domain == Domain.Air)
            seen[3] = true;
        else if (domain == Domain.Sea)
        {
            seen[19] = true;
            seen[20] = true;
            seen[22] = true;
        }

        int baseId = cast(int)domain;

        foreach (id; seen.byKey)
        {
            Terrain terrain = cast(Terrain)id;
            if (terrain == Terrain.Sea)
                continue;

            if (domain == Domain.Ground)
            {
                if ((id != 0 && id < 10) || id == 19)
                    continue;
            }
            else if (domain == Domain.Air)
            {
                if (id != 1 && id != 3)
                    continue;
            }
            else if (domain == Domain.Sea)
            {
                if (id != 2 && id != 19 && id != 20 && id != 22)
                    continue;
            }

            TerrainStats stat;
            stat.terrain = terrain;
            stat.weight = damageWeights.get(domainID(terrain), 0);

            float baseSpeed = speeds.get(baseId, 0);
            float baseHP = hitPoints.get(baseId, 0);
            float baseSight = viewWidths.get(baseId, 0);

            if (terrain == Terrain.Road && domain == Domain.Air)
            {
                stat.speed = 0.01;
                stat.hitPoints = 15;
                stat.sight = 25;
                stat.attackMod = 0;
                stat.defenseMod = 0;
            }
            else
            {
                float speedMod = speeds.get(id, 1.0);
                float hpMod = hitPoints.get(id, 1.0);
                float sightMod = viewWidths.get(id, 1.0);
                stat.speed = (baseSpeed > 0 && id != baseId) ? baseSpeed * speedMod : speedMod;
                stat.hitPoints = (baseHP > 0 && id != baseId) ? baseHP * hpMod : hpMod;
                stat.sight = (baseSight > 0 && id != baseId) ? baseSight * sightMod : sightMod;
            }

            if (terrain != Terrain.Ground && terrain != Terrain.Air)
            {
                stat.attackMod = rawAttack.get(id, 0);
                stat.defenseMod = rawDefense.get(id, 0);
            }

            terrainStats[terrain] = stat;
        }
    }

    void buildCombatStats(
        float[int] rawAttack,
        float[int] rawDefense,
        float[int] unitFeatures,
        float[int] rawRanges
    )
    {
        foreach (id, value; rawAttack)
            combatStats.attack[cast(DamageType)id] = value;
        foreach (id, value; rawDefense)
            combatStats.defense[cast(DamageType)id] = value;

        foreach (id, value; rawRanges)
        {
            if (value > combatStats.attackRange)
                combatStats.attackRange = value;
        }

        foreach (id, value; unitFeatures)
        {
            if (id == 3)
                combatStats.attackRange = value;
        }
    }

private:
    DamageType _damageType;
}

class UnitFamily
{
public:
    string key;
    string name;
    string description;
    Faction faction;
    DamageType damageType;
    int productionLimit;
    Unit[] units;
}
