module insurgent.store.resource;

enum Resource : int
{
    Supplies = 1,
    Components = 2,
    Manpower = 3,
    RareMaterials = 4,
    Fuel = 5,
    Electronics = 6,
    ConventionalWarheads = 7,
    ChemicalWarheads = 8,
    NuclearWarheads = 9,
    Deployables = 10,
    Money = 20,
    CityClaims = 30,
    Pharmaceuticals = 40,
    GroundMunition = 50,
    SeaMunition = 60,
    AirMunition = 70
}

string name(Resource resource)
{
    final switch (resource)
    {
    case Resource.Supplies:             return "Supplies";
    case Resource.Components:           return "Components";
    case Resource.Manpower:             return "Manpower";
    case Resource.RareMaterials:        return "Rare Materials";
    case Resource.Fuel:                 return "Fuel";
    case Resource.Electronics:          return "Electronics";
    case Resource.ConventionalWarheads: return "Conventional Warheads";
    case Resource.ChemicalWarheads:     return "Chemical Warheads";
    case Resource.NuclearWarheads:      return "Nuclear Warheads";
    case Resource.Deployables:          return "Deployables";
    case Resource.Money:                return "Money";
    case Resource.CityClaims:           return "City Claims";
    case Resource.Pharmaceuticals:      return "Pharmaceuticals";
    case Resource.GroundMunition:       return "Ground Munition";
    case Resource.SeaMunition:          return "Sea Munition";
    case Resource.AirMunition:          return "Air Munition";
    }
}
