module insurgent.match.stack;

import insurgent.store.unit : Unit;
import insurgent.match.unit : MatchUnit;

class Stack
{
public:
    int armyID;
    int ownerID;
    int locationID;
    Unit paintedUnitType;
    MatchUnit[] units;
}
