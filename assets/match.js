(function() {
    try {
        var iframe = document.querySelector('iframe');
        if (!iframe) return JSON.stringify({ error: 'iframe not found' });

        var iw = iframe.contentWindow;
        if (!iw || !iw.hup || !iw.hup.gameState || !iw.hup.gameState.states)
            return JSON.stringify({ error: 'game state not ready' });

        var gs = iw.hup.gameState.states;
        var gameID = parseInt(new URL(iw.location.href).searchParams.get('gameID')) || 0;

        var players = gs["1"] && gs["1"].players ? gs["1"].players : {};
        var provinces = gs["3"] && gs["3"].provinces ? gs["3"].provinces : {};
        var armies = gs["6"] && gs["6"].armies ? gs["6"].armies : {};

        var nations = Object.values(players).map(function(p) {
            return {
                playerID: p.playerID,
                sitePlayerId: p.siteUserID !== undefined ? p.siteUserID : -1,
                coalitionId: p.teamID !== undefined ? p.teamID : 0,
                name: p.name || "",
                nationName: p.nationName || "",
                vps: p.vps || 0,
                defeated: !!p.defeated,
                retired: !!p.retired
            };
        });

        var allArmies = [];
        Object.keys(armies).forEach(function(key) {
            var a = armies[key];
            if (a && typeof a === 'object' && a.units) {
                allArmies.push({ id: key, obj: a });
            }
        });

        var stacks = allArmies.map(function(entry) {
            var a = entry.obj;
            var unitArr = [];
            var unitList = a.units ? (Array.isArray(a.units) ? a.units : Object.values(a.units)) : [];
            for (var i = 0; i < unitList.length; i++) {
                var u = unitList[i];
                if (u && typeof u.unitTypeID === 'number') {
                    unitArr.push({
                        unitTypeID: u.unitTypeID,
                        hitPoints: u.hitPoints || 0,
                        size: u.size || 1
                    });
                }
            }
            var pt = a.paintedUnitType;
            return {
                armyID: a.armyID || parseInt(entry.id) || 0,
                ownerID: a.ownerID || 0,
                locationID: a.locationID || 0,
                paintedUnitTypeID: pt ? (pt.unitTypeID || pt.itemID || pt.id) : 0,
                units: unitArr
            };
        });

        var tiles = Object.values(provinces).map(function(p) {
            return {
                id: p.provinceID || 0,
                name: p.name || "",
                ownerID: p.ownerID || 0,
                legalOwnerID: p.legalOwnerID || 0,
                tileType: p.provinceStateID || 0,
                morale: p.morale || 0,
                population: p.population || 0,
                provinceLevel: p.provinceLevel || 0,
                coastal: !!p.coastal,
                terrainType: p.terrainType || 0,
                coreIDs: p.coreIDs || [],
                improvements: (p.improvements || []).map(function(imp) {
                    return {
                        itemID: imp.itemID || 0,
                        condition: imp.condition || 0,
                        enabled: !!imp.enabled,
                        constructing: !!imp.constructing
                    };
                })
            };
        });

        return JSON.stringify({ gameID: gameID, nations: nations, stacks: stacks, tiles: tiles });
    } catch(e) {
        return JSON.stringify({ error: e.toString() });
    }
})()
