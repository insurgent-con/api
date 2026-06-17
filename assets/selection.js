(function() {
    try {
        var iframe = document.querySelector('iframe');
        if (!iframe) return JSON.stringify({ error: 'iframe not found' });

        var iw = iframe.contentWindow;
        if (!iw) return JSON.stringify({ error: 'iframe contentWindow not available' });

        var gameID = parseInt(new URL(iw.location.href).searchParams.get('gameID')) || 0;

        var selectedStack = null;
        var armySel = iw.hup && iw.hup.armySelection ? iw.hup.armySelection : null;
        if (armySel && armySel.unifiedSelectedArmy) {
            var army = armySel.unifiedSelectedArmy;
            var units = [];
            var unitList = army.units ? (Array.isArray(army.units) ? army.units : Object.values(army.units)) : [];
            for (var i = 0; i < unitList.length; i++) {
                var u = unitList[i];
                if (u && typeof u.unitTypeID === 'number') {
                    units.push({
                        unitTypeID: u.unitTypeID,
                        hitPoints: u.hitPoints || 0,
                        size: u.size || 1
                    });
                }
            }
            var pt = army.paintedUnitType;
            var armyID = army.armyID;
            if (typeof armyID !== 'number' && typeof army._id === 'string') {
                var parsed = parseInt(army._id);
                if (!isNaN(parsed)) armyID = parsed;
            }
            selectedStack = {
                armyID: armyID || 0,
                ownerID: army.ownerID || 0,
                locationID: army.locationID || 0,
                paintedUnitTypeID: pt ? (pt.unitTypeID || pt.itemID || pt.id) : 0,
                units: units
            };
        }

        var selectedTile = null;
        var provSel = iw.hup.provinceSelection;
        if (provSel && provSel.selectedProvinces) {
            var provKeys = Object.keys(provSel.selectedProvinces);
            if (provKeys.length > 0) {
                var prov = provSel.selectedProvinces[provKeys[0]];
                var improvements = [];
                if (prov.improvements) {
                    for (var i = 0; i < prov.improvements.length; i++) {
                        var imp = prov.improvements[i];
                        improvements.push({
                            itemID: imp.itemID || 0,
                            condition: imp.condition || 0,
                            enabled: !!imp.enabled,
                            constructing: !!imp.constructing
                        });
                    }
                }
                selectedTile = {
                    id: prov.provinceID || 0,
                    name: prov.name || "",
                    ownerID: prov.ownerID || 0,
                    legalOwnerID: prov.legalOwnerID || 0,
                    tileType: prov.provinceStateID || 0,
                    morale: prov.morale || 0,
                    population: prov.population || 0,
                    provinceLevel: prov.provinceLevel || 0,
                    coastal: !!prov.coastal,
                    terrainType: prov.terrainType || 0,
                    coreIDs: prov.coreIDs || [],
                    improvements: improvements
                };
            }
        }

        return JSON.stringify({
            gameID: gameID,
            selectedStack: selectedStack,
            selectedTile: selectedTile
        });
    } catch (e) {
        return JSON.stringify({ error: e.message, stack: e.stack });
    }
})()
