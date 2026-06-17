module insurgent.match.tile;

import insurgent.store.tile : TileType;
import insurgent.match.building : MatchBuilding;

class Tile
{
public:
    int id;
    string name;
    int ownerID;
    int legalOwnerID;
    TileType tileType;
    int morale;
    int population;
    int provinceLevel;
    bool coastal;
    int terrainType;
    int[] coreIDs;
    MatchBuilding[] buildings;
}
