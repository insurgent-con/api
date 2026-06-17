(function () {
    try {
        const iframe = document.querySelector('iframe');
        const iw = iframe?.contentWindow;
        if (!iw)
            return JSON.stringify({ error: 'Game iframe not found yet.' });

        const gs = iw.hup?.gameState?.states;
        if (!gs)
            return JSON.stringify({ error: 'Game state is not ready yet.' });

        const state11 = gs["11"];
        if (!state11)
            return JSON.stringify({ error: 'Static game data is not ready yet.' });

        const upgrades     = state11.upgrades       || {};
        const allUnits     = state11.allUnitTypes   || {};
        const researches   = state11.researchTypes  || {};
        const damageTypes  = state11.damageTypes    || {};

        // ---- Helpers -------------------------------------------------------

        const num = (v) => {
            if (v === null || v === undefined || v === '') return 0;
            const n = Number(v);
            return Number.isFinite(n) ? n : 0;
        };

        const str = (v) => typeof v === 'string' ? v : '';

        const entries = (v) =>
            v && typeof v === 'object' ? Object.entries(v) : [];

        const toArr = (v) =>
            Array.isArray(v) ? v
            : (v && typeof v === 'object') ? Object.values(v)
            : [];

        const idOf = (v, keys) => {
            for (const k of keys) {
                const n = num(v?.[k]);
                if (n) return n;
            }
            return 0;
        };

        const familyKey = (ident) => str(ident).replace(/_[abc]$/, '');

        // damageType name (e.g. "DAMAGE_HARD") -> damageTypeID
        const dtNameToID = {};
        for (const [id, v] of entries(damageTypes)) {
            const name = typeof v === 'string' ? v : str(v?.damageTypeName || v?.name);
            if (name) dtNameToID[name] = num(id);
        }

        // ---- Encoding helpers (ID-keyed maps into sorted arrays) -----------

        const costMap = (m) => entries(m)
            .map(([id, amt]) => ({ resourceID: num(id), amount: num(amt) }))
            .filter(c => c.resourceID)
            .sort((a, b) => a.resourceID - b.resourceID);

        const terrainMap = (m) => entries(m)
            .map(([id, v]) => ({ terrainTypeID: num(id), value: num(v) }))
            .sort((a, b) => a.terrainTypeID - b.terrainTypeID);

        const dmgMap = (m) => entries(m)
            .map(([id, v]) => ({ damageTypeID: num(id), value: num(v) }))
            .sort((a, b) => a.damageTypeID - b.damageTypeID);

        // Flatten legacy patrol target DamageType IDs to canonical values
        const flattenDT = (id) => {
            if (id === 1001) return 0;   // classSoft -> normal
            if (id === 1002) return 4;   // classHard -> hard
            if (id === 1003) return 13;  // classMissile -> missile
            if (id === 1004) return 14;  // classDrone -> drone
            return id;
        };

        // ---- Missile slots -------------------------------------------------

        const MISSILE_CRUISE = 1, MISSILE_BALLISTIC = 2;

        const missileTypeForSlot = (slotID) => {
            if (slotID === 1) return MISSILE_CRUISE;
            if (slotID === 2 || slotID === 3) return MISSILE_BALLISTIC;
            return 0;
        };

        const missileEntries = (cfg) => {
            const byType = {};
            for (const [slotID, s] of entries(cfg)) {
                const mt = missileTypeForSlot(num(slotID));
                if (!mt) continue;
                const e = byType[mt] || { missileTypeID: mt, capacity: 0, resupplyTime: 0, initialInventory: 0 };
                e.capacity          += num(s?.capacity);
                e.initialInventory  += num(s?.initialInventory);
                e.resupplyTime = Math.max(e.resupplyTime, num(s?.resupplyTime));
                byType[mt] = e;
            }
            return Object.values(byType).sort((a, b) => a.missileTypeID - b.missileTypeID);
        };

        // ---- Army boost bonuses -------------------------------------------

        const armyBonusEntries = (bonuses) => {
            const byDT = {};
            for (const b of toArr(bonuses)) {
                const stat  = str(typeof b?.getStat       === 'function' ? b.getStat()       : b?.stat);
                const rawDT = str(typeof b?.getDamageType === 'function' ? b.getDamageType() : b?.damageType);
                const bonus = num(typeof b?.getBonus      === 'function' ? b.getBonus()      : b?.bonus);
                const dtID  = dtNameToID[rawDT];
                if (dtID === undefined) continue;
                const e = byDT[dtID] || { damageTypeID: dtID, attackFactor: 0, defenseFactor: 0, speedFactor: 0 };
                if      (stat === 'ATTACK')  e.attackFactor  = bonus;
                else if (stat === 'DEFENSE') e.defenseFactor = bonus;
                else if (stat === 'SPEED')   e.speedFactor   = bonus;
                else continue;
                byDT[dtID] = e;
            }
            return Object.values(byDT).sort((a, b) => a.damageTypeID - b.damageTypeID);
        };

        // ---- Stealth bitmask (must match features.d Stealth flags) --------

        const STEALTH_LAND      = 1 << 0;
        const STEALTH_AIR       = 1 << 1;
        const STEALTH_SUBMARINE = 1 << 2;

        // Game stealth class IDs: 10 = land, 11 = air, 12 = submarine.
        const classToStealthFlag = (c) => {
            if (c === 10) return STEALTH_LAND;
            if (c === 11) return STEALTH_AIR;
            if (c === 12) return STEALTH_SUBMARINE;
            return 0;
        };

        const stealthMask = (classes) => {
            let m = 0;
            for (const c of toArr(classes)) m |= classToStealthFlag(num(c));
            return m;
        };

        // ---- Perks bitmask (must match perks.d) ---------------------------

        const PERK_SPECIAL_PROD      = 1 << 0;
        const PERK_ARMY_BOOST        = 1 << 2;
        const PERK_SCOUT             = 1 << 3;
        const PERK_STORM_POSITION    = 1 << 4;
        const PERK_AMPHIBIOUS        = 1 << 7;
        const PERK_CONQUER           = 1 << 8;
        const PERK_UNCONTROLLABLE    = 1 << 9;
        const PERK_UNPRODUCIBLE      = 1 << 10;
        const PERK_KAMIKAZE          = 1 << 11;

        const call = (u, fn) => { try { return u?.[fn] ? u[fn]() : undefined; } catch (e) { return undefined; } };

        const perkMask = (u) => {
            let p = 0;
            if (str(u?.productionRequirementConfig?.expression)) p |= PERK_SPECIAL_PROD;
            if ((u?.armyBoostConfig?.bonuses || []).length > 0)  p |= PERK_ARMY_BOOST;
            if ((u?.scoutConfig?.camouflageClasses || []).length > 0) p |= PERK_SCOUT;
            if (call(u, 'isStorm')              === true)        p |= PERK_STORM_POSITION;
            if (call(u, 'isShipTransportable')  === true)        p |= PERK_AMPHIBIOUS;
            if (num(u?.unitFeatures?.[43]) === 1)                p |= PERK_CONQUER;
            if (!Boolean(u?.controllableConfig?.controllable))   p |= PERK_UNCONTROLLABLE;
            if (!Boolean(u?.producible))                         p |= PERK_UNPRODUCIBLE;
            if (call(u, 'isKamikaze')           === true)        p |= PERK_KAMIKAZE;
            return p;
        };

        // slot key "1" = rotary/helicopter capacity → DamageType.Rotary (8)
        // slot key "2" = fixed-wing capacity → DamageType.Air (1)
        const carrierSlots = (cfg) => {
            const slotConfig = cfg?.slotConfig;
            if (!slotConfig) return [];
            const ret = [];
            if (num(slotConfig['1']) > 0)
                ret.push({ damageTypeID: 8, capacity: num(slotConfig['1']) });
            if (num(slotConfig['2']) > 0)
                ret.push({ damageTypeID: 1, capacity: num(slotConfig['2']) });
            return ret.sort((a, b) => a.damageTypeID - b.damageTypeID);
        };

        // ---- Researches ---------------------------------------------------

        // Research icons live in assets/research/perks/<key>.png (trait icons)
        // or assets/research/upgrades/<key>.png for numeric modifiers
        // (incr_/decr_/red_). We embed the subfolder in the image key so
        // the D-side asset resolver does not need to know about the split.
        const isUpgradeIcon = (k) => /^(incr|decr|red)_/.test(k);
        const researchIconKey = (v) => {
            try {
                const ic = v?.getIcon ? v.getIcon() : null;
                if (typeof ic === 'string' && ic.startsWith('research-')) {
                    const key = ic.slice('research-'.length);
                    return (isUpgradeIcon(key) ? 'upgrades/' : 'perks/') + key;
                }
            } catch (e) {}
            return '';
        };

        const normResearches = entries(researches)
            .map(([id, v]) => ({
                researchID: idOf(v, ['researchID','itemID','id']) || num(id),
                name: str(v?.researchName || v?.name) || 'Research '+id,
                image: researchIconKey(v),
                costs: costMap(v?.costs),
                replacedResearch: num(v?.replacedResearch),
                requiredResearches: entries(v?.requiredResearches)
                    .map(([rid, lvl]) => ({ researchID: num(rid), level: num(lvl) }))
                    .filter(r => r.researchID)
                    .sort((a, b) => a.researchID - b.researchID)
            }))
            .filter(r => r.researchID)
            .sort((a, b) => a.researchID - b.researchID);

        // ---- Buildings ----------------------------------------------------

        // Buildings live at assets/building/<articlePrefix>/<tier>.png
        // so the image key embeds both parts.
        const buildingImageKey = (v) => {
            try {
                const ap = v?.getArticlePrefix ? v.getArticlePrefix() : '';
                const tier = v?.getTier ? v.getTier() : 0;
                if (ap && ap !== '0' && tier)
                    return ap + '/' + tier;
            } catch (e) {}
            return '';
        };

        const normBuildings = entries(upgrades)
            .map(([id, v]) => ({
                buildingID: idOf(v, ['itemID','upgradeID','id']) || num(id),
                name: str(v?.upgrName || v?.name) || 'Building '+id,
                description: str(v?.upgrDesc) || '',
                image: buildingImageKey(v),
                dayAvailable: num(v?.dayOfAvailability),
                tier: num(v?.tier),
                minHealth: num(v?.buildCondition),
                maxHealth: num(v?.maxCondition),
                possibleProvinceStates: entries(v?.possibleProvinceStates || {})
                    .map(([stateId, _]) => num(stateId))
                    .filter(sid => sid > 0),
                buildTime: num(v?.buildTime),
                costs: costMap(v?.costs),
                upkeep: costMap(v?.dailyCosts),
                production: costMap(v?.dailyProductions),
                features: entries(v?.features || {})
                    .map(([fid, value]) => ({ featureID: num(fid), value: num(value) }))
                    .filter(f => f.featureID > 0),
                enableable: Boolean(v?.enableable),
                victoryPointsGenerationConfig: {
                    dailyVictoryPoints: num(v?.victoryPointsGenerationConfig?.dailyVictoryPoints)
                },
                constructionSpeedupConfig: {
                    factor: num(v?.constructionSpeedupConfig?.factor),
                    constructionClass: num(v?.constructionSpeedupConfig?.constructionClass)
                },
                healArmiesConfig: {
                    healingRateByArmorClass: entries(v?.healArmiesConfig?.healingRateByArmorClass || {})
                        .map(([armorClass, rate]) => ({ armorClass: num(armorClass), rate: num(rate) }))
                        .filter(h => h.armorClass > 0)
                },
                replacedUpgrade: num(v?.replacedUpgrade)
            }))
            .filter(b => b.buildingID)
            .sort((a, b) => a.buildingID - b.buildingID);

        // ---- Default transport units ---------------------------------------

        let defaultShipID = 0, defaultPlaneID = 0, defaultHeliID = 0;
        for (const [id, v] of entries(allUnits)) {
            const name = str(v?.unitName || v?.name);
            if (!defaultShipID  && name === 'Transport Ship')      defaultShipID  = num(v?.itemID) || num(id);
            if (!defaultPlaneID && name === 'Transport Plane')     defaultPlaneID = num(v?.itemID) || num(id);
            if (!defaultHeliID  && name === 'Transport Helicopter') defaultHeliID  = num(v?.itemID) || num(id);
        }

        // ---- Units --------------------------------------------------------

        const normUnits = entries(allUnits)
            .map(([id, v]) => {
                // damageType: first entry of the unit's damageTypes map
                let damageTypeID = 15; // default Special
                let isGround = false;
                for (const [domain, typeID] of entries(v?.damageTypes)) {
                    damageTypeID = flattenDT(num(typeID));
                    if (num(domain) === 0) isGround = true;
                    break;
                }

                // Exclude warheads (feature 40 = 7/8/9) and deployable gear (feature 40 = 10)
                const f40 = num(v?.unitFeatures?.['40']);
                if (f40 === 7 || f40 === 8 || f40 === 9 || f40 === 10) return null;

                let tier = 0, faction = 0;
                try { tier = v.getTier(); } catch (e) {}
                try { const f = v.getFactions() || []; faction = f.length ? f[0] : 0; } catch (e) {}

                const reveal  = stealthMask(v?.scoutConfig?.stealthClasses);
                const stealth = classToStealthFlag(num(v?.unitFeatures?.[13]));

                const ident = str(v?.identifier);
                // Units live at assets/unit/<family>/<identifier>_<doctrine>.png
                // The doctrine is the faction (1 Western, 2 Eastern, 3 European).
                // For units without a specific faction we emit a blank key so
                // the UI falls back to text-only.
                const fkey    = ident ? ident.replace(/_[abc]$/, '') : '';
                // Universal units (getFactions() === []) still have
                // {ident}_1_big.png on the server; default doctrine to 1
                // so they still resolve to an image.
                const dctrn   = faction || 1;
                const imageKey = (ident && fkey)
                    ? fkey + '/' + ident + '_' + dctrn
                    : '';

                let rotaryID = num(call(v, 'getAirMobileReplacementUnit')?.itemID);
                let airID    = num(call(v, 'getAirTransportReplacementUnit')?.itemID);
                let seaID    = num(call(v, 'getShipTransportReplacementUnit')?.itemID);

                if (!rotaryID && call(v, 'isAirMobile')          === true) rotaryID = defaultHeliID;
                if (!airID    && call(v, 'isAirTransportable')   === true) airID    = defaultPlaneID;
                if (!seaID    && isGround)                                    seaID    = defaultShipID;

                return {
                    unitTypeID:              idOf(v, ['itemID','unitTypeID','id']) || num(id),
                    familyKey:               familyKey(ident),
                    familyName:              str(v?.unitName) || 'Unit '+id,
                    name:                    (faction === 1 && str(v?.nameFaction1)) || (faction === 2 && str(v?.nameFaction2)) || (faction === 3 && str(v?.nameFaction3)) || str(v?.nameFaction1) || str(v?.unitName) || 'Unit '+id,
                    image:                   imageKey,
                    description:             str(v?.unitDesc),
                    tier, faction,
                    damageType:              damageTypeID,
                    buildTimeSeconds:        num(v?.buildTime),
                    maxFlightTime:           num(v?.airplaneConfig?.maxFlightTime),
                    friendlySpeedFactor:     num(v?.friendlySpeedFactor) || 1,
                    foreignSpeedFactor:      num(v?.foreignSpeedFactor)  || 1,
                    rotaryTransportUnitID:   rotaryID,
                    airTransportUnitID:      airID,
                    seaTransportUnitID:      seaID,
                    missiles:              missileEntries(v?.missileCarrierConfig?.missileSlotConfig || {}),
                    carrierSlots:          carrierSlots(v?.carrierConfig),
                    productionLimit:       num(v?.limitedMobilizationConfig?.limit),
                    stealth,
                    revealStealth:         reveal,
                    signatureType:         num(v?.radarSignatureConfig?.type),
                    signature:             num(v?.radarSignatureConfig?.size),
                    radarRange:            num(v?.radarConfig?.maxRange),
                    radarEntries: (v?.radarConfig?.signatureTypes || []).map(s => ({
                        type:       num(s.type),
                        range:      num(s.range),
                        resolution: num(s.resolution)
                    })),
                    antiAirRange:          num(v?.antiAirConfig?.range),
                    patrolRadius:          num(v?.airplaneConfig?.patrolRadius),
                    patrolTargets: (v?.airplaneConfig?.patrolTargetDamageTypes || []).map(flattenDT),
                    damageWeights:         terrainMap(v?.damageArea),
                    perks:                 perkMask(v),
                    armyBonus:             armyBonusEntries(v?.armyBoostConfig?.bonuses || []),
                    costs:                 costMap(v?.costs),
                    dailyCosts:            costMap(v?.dailyCosts),
                    attack:                dmgMap(v?.strength),
                    defense:               dmgMap(v?.defence),
                    speeds:                terrainMap(v?.speeds),
                    hitPoints:             terrainMap(v?.hitPoints),
                    ranges:                terrainMap(v?.ranges),
                    viewWidths:            terrainMap(v?.viewWidths),
                    unitFeatures: entries(v?.unitFeatures)
                        .map(([fid, val]) => ({ featureID: num(fid), value: num(val) }))
                        .filter(f => f.featureID !== null && f.featureID !== undefined),
                    requiredBuildings: entries(v?.requiredUpgrades)
                        .map(([bid, lvl]) => ({ buildingID: num(bid), level: num(lvl) }))
                        .filter(b => b.buildingID)
                        .sort((a, b) => a.buildingID - b.buildingID),
                    requiredResearches: entries(v?.requiredResearches)
                        .map(([rid, lvl]) => ({ researchID: num(rid), level: num(lvl) }))
                        .filter(r => r.researchID)
                        .sort((a, b) => a.researchID - b.researchID),
                    restrictedTerrains: (v?.terrainRestrictionConfig?.restrictedTerrains || [])
                        .map(num).filter(t => t)
                };
            })
            .filter(u => u !== null)
            .filter(u => u.unitTypeID)
            .sort((a, b) => a.unitTypeID - b.unitTypeID);

        return JSON.stringify({
            staticData: {
                researches: normResearches,
                buildings:  normBuildings,
                units:      normUnits
            }
        });
    } catch (err) {
        return JSON.stringify({ error: err?.message || String(err) });
    }
})()
