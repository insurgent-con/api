/// Filesystem access to the `assets/` tree shipped alongside the binary.
///
/// Assets are laid out as `assets/ip/<category>/<basename>.png` for
/// intellectual-property assets and `assets/rf/<category>/<basename>.png`
/// for replacement (royalty-free) assets. The `noIP` toggle switches
/// between the two roots. All lookups happen at runtime: the repo-root
/// layout places `assets/` next to the executable, and installed layouts
/// are expected to do the same.
///
/// Use the `Assets.imagePath()` static method to resolve the `imageKey`
/// field to an actual filesystem path for rendering icons.
module insurgent.store.assets;

import std.file : exists, thisExePath;
import std.path : buildPath, dirName;
import std.string : lastIndexOf;

import insurgent.store.building : Building;
import insurgent.store.research : Research;
import insurgent.store.unit : Unit;
import insurgent.store.common : DamageType, Perks, Terrain;
import insurgent.store.resource : Resource;

static class Assets
{
    /// When `true`, lookups target `assets/rf/` instead of `assets/ip/`.
    static bool noIP;

    /// Absolute path to the `assets/` directory shipped with this binary.
    static string assetsDir()
    {
        static string cached;
        if (cached.length == 0)
        {
            cached = buildPath(dirName(thisExePath), "assets");
        }
        return cached;
    }

    /// Absolute path to `assets/ip/<category>/<basename>.png` (or the `rf`
    /// equivalent when `noIP` is `true`), or `null` if the file does not exist
    /// (or either argument is empty).
    static string assetPath(string category, string basename)
    {
        if (category.length == 0 || basename.length == 0)
            return null;
        string prefix = noIP ? "rf" : "ip";
        string path = buildPath(assetsDir, prefix, category, basename~".png");
        return exists(path) ? path : null;
    }

    /// Image path lookups for each kind of entity. Returns `null` when the
    /// entity has no associated key or the underlying PNG is missing.
    static string imagePath(Unit unit)
    {
        if (unit is null)
            return null;
        string path = assetPath("unit", unit.imageKey);
        if (path.length)
            return path;

        ptrdiff_t searchIndex = unit.imageKey.lastIndexOf("_");
        if (searchIndex < 0)
            return null;

        string stem = unit.imageKey[0..searchIndex + 1];
        foreach (doctrine; ["1", "2", "3"])
        {
            path = assetPath("unit", stem~doctrine);
            if (path.length)
                return path;
        }
        return null;
    }

    static string imagePath(Research research)
        => research is null ? null : assetPath("research", research.imageKey);

    static string imagePath(Building building)
        => building is null ? null : assetPath("building", building.imageKey);

    static string imagePath(Perks perk)
    {
        string ret;
        switch (perk)
        {
        case Perks.SpecialProduction: ret = "specials_deployable"; break;
        case Perks.ArmyBoost:         ret = "specials_army_boost"; break;
        case Perks.Scout:             ret = "specials_scout"; break;
        case Perks.StormPosition:     ret = "specials_storm_unit"; break;
        case Perks.Amphibious:        ret = "specials_naval"; break;
        case Perks.ConquerTerritory:  ret = "specials_can_conquer"; break;
        case Perks.Uncontrollable:    ret = "specials_controllable"; break;
        case Perks.Unproducible:      ret = "specials_production"; break;
        case Perks.Kamikaze:          ret = "specials_kamikaze"; break;
        default: return null;
        }
        return ret.length ? assetPath("research/perks", ret) : null;
    }

    static string imagePath(DamageType damageType)
    {
        string ret;
        switch (damageType)
        {
        case DamageType.Normal:     ret = "0"; break;
        case DamageType.Air:        ret = "1"; break;
        case DamageType.Sea:        ret = "2"; break;
        case DamageType.Building:   ret = "3"; break;
        case DamageType.Hard:       ret = "4"; break;
        case DamageType.Submarine:  ret = "5"; break;
        case DamageType.Population: ret = "7"; break;
        case DamageType.Rotary:     ret = "8"; break;
        case DamageType.Missile:    ret = "13"; break;
        case DamageType.Drone:      ret = "14"; break;
        case DamageType.Special:    ret = "special"; break;
        default: return null;
        }
        return ret.length ? assetPath("damage", ret) : null;
    }

    static string imagePath(Resource resource)
    {
        string ret;
        final switch (resource)
        {
        case Resource.Supplies:             ret = "1"; break;
        case Resource.Components:           ret = "2"; break;
        case Resource.Manpower:             ret = "3"; break;
        case Resource.RareMaterials:        ret = "4"; break;
        case Resource.Fuel:                 ret = "5"; break;
        case Resource.Electronics:          ret = "6"; break;
        case Resource.ConventionalWarheads: ret = "7"; break;
        case Resource.ChemicalWarheads:     ret = "8"; break;
        case Resource.NuclearWarheads:      ret = "9"; break;
        case Resource.Deployables:          ret = "10"; break;
        case Resource.Money:                ret = "20"; break;
        case Resource.CityClaims:           ret = "30"; break;
        case Resource.Pharmaceuticals:      ret = "40"; break;
        case Resource.GroundMunition:       ret = "50"; break;
        case Resource.SeaMunition:          ret = "60"; break;
        case Resource.AirMunition:          ret = "70"; break;
        }
        return ret.length ? assetPath("resource", ret) : null;
    }

    static string imagePath(Terrain terrain)
    {
        string ret;
        final switch (terrain)
        {
        case Terrain.Ground:   ret = "0"; break;
        case Terrain.Air:      ret = "1"; break;
        case Terrain.Sea:      ret = "2"; break;
        case Terrain.Road:     ret = "3"; break;
        case Terrain.Plains:   ret = "10"; break;
        case Terrain.Mountain: ret = "12"; break;
        case Terrain.Forest:   ret = "13"; break;
        case Terrain.Urban:    ret = "14"; break;
        case Terrain.Jungle:   ret = "15"; break;
        case Terrain.Tundra:   ret = "16"; break;
        case Terrain.Desert:   ret = "17"; break;
        case Terrain.HighSea:  ret = "19"; break;
        case Terrain.Coastal:  ret = "20"; break;
        case Terrain.Suburban: ret = "21"; break;
        case Terrain.River:    ret = "22"; break;
        }
        return ret.length ? assetPath("terrain", ret) : null;
    }

    static string flagEmoji(string nationName)
    {
        string code;
        switch (nationName)
        {
        case "Afghanistan":          code = "AF"; break;
        case "Albania":              code = "AL"; break;
        case "Algeria":              code = "DZ"; break;
        case "Angola":               code = "AO"; break;
        case "Argentina":            code = "AR"; break;
        case "Armenia":              code = "AM"; break;
        case "Australia":            code = "AU"; break;
        case "Austria":              code = "AT"; break;
        case "Azerbaijan":           code = "AZ"; break;
        case "Bangladesh":           code = "BD"; break;
        case "Belarus":              code = "BY"; break;
        case "Belgium":              code = "BE"; break;
        case "Bermuda":              code = "BM"; break;
        case "Bolivia":              code = "BO"; break;
        case "Bosnia":               code = "BA"; break;
        case "Botswana":             code = "BW"; break;
        case "Brazil":               code = "BR"; break;
        case "Brunei":               code = "BN"; break;
        case "Bulgaria":             code = "BG"; break;
        case "Cabinda":              code = "AO"; break; // Angolan exclave
        case "Cambodia":             code = "KH"; break;
        case "Cameroon":             code = "CM"; break;
        case "Canada":               code = "CA"; break;
        case "Caribbean States":     return null;
        case "Catalonia":            return null;
        case "Chad":                 code = "TD"; break;
        case "Chile":                code = "CL"; break;
        case "China":                code = "CN"; break;
        case "Colombia":             code = "CO"; break;
        case "Costa Rica":           code = "CR"; break;
        case "Crimea":               return null;
        case "Croatia":              code = "HR"; break;
        case "Cuba":                 code = "CU"; break;
        case "Czechia":              code = "CZ"; break;
        case "DR Congo":             code = "CD"; break;
        case "Denmark":              code = "DK"; break;
        case "Diego Garcia":         code = "IO"; break;
        case "Dominican Republic":   code = "DO"; break;
        case "Ecuador":              code = "EC"; break;
        case "Egypt":                code = "EG"; break;
        case "El Salvador":          code = "SV"; break;
        case "Estonia":              code = "EE"; break;
        case "Ethiopia":             code = "ET"; break;
        case "Falkland Islands":     code = "FK"; break;
        case "Faroe Islands":        code = "FO"; break;
        case "Fiji":                 code = "FJ"; break;
        case "Finland":              code = "FI"; break;
        case "France":               code = "FR"; break;
        case "French Guiana":        code = "GF"; break;
        case "Georgia":              code = "GE"; break;
        case "Germany":              code = "DE"; break;
        case "Ghana":                code = "GH"; break;
        case "Gibraltar":            code = "GI"; break;
        case "Greece":               code = "GR"; break;
        case "Greenland":            code = "GL"; break;
        case "Guam":                 code = "GU"; break;
        case "Guatemala":            code = "GT"; break;
        case "Guyana":               code = "GY"; break;
        case "Haiti":                code = "HT"; break;
        case "Honduras":             code = "HN"; break;
        case "Hungary":              code = "HU"; break;
        case "Iceland":              code = "IS"; break;
        case "India":                code = "IN"; break;
        case "Indonesia":            code = "ID"; break;
        case "Insurgencies":         return null;
        case "Iran":                 code = "IR"; break;
        case "Iraq":                 code = "IQ"; break;
        case "Ireland":              code = "IE"; break;
        case "Israel":               code = "IL"; break;
        case "Italy":                code = "IT"; break;
        case "Jamaica":              code = "JM"; break;
        case "Japan":                code = "JP"; break;
        case "Jordan":               code = "JO"; break;
        case "Kashmir":              return null;
        case "Kazakhstan":           code = "KZ"; break;
        case "Kenya":                code = "KE"; break;
        case "Kerguelen Islands":    code = "TF"; break;
        case "Kuwait":               code = "KW"; break;
        case "KwaZulu-Natal":        return null;
        case "Kyrgyzstan":           code = "KG"; break;
        case "Latvia":               code = "LV"; break;
        case "Lebanon":              code = "LB"; break;
        case "Libya":                code = "LY"; break;
        case "Lithuania":            code = "LT"; break;
        case "Madagascar":           code = "MG"; break;
        case "Malaysia":             code = "MY"; break;
        case "Mali":                 code = "ML"; break;
        case "Malta":                code = "MT"; break;
        case "Mauritania":           code = "MR"; break;
        case "Mexico":               code = "MX"; break;
        case "Moldova":              code = "MD"; break;
        case "Mongolia":             code = "MN"; break;
        case "Morocco":              code = "MA"; break;
        case "Mozambique":           code = "MZ"; break;
        case "Myanmar":              code = "MM"; break;
        case "Namibia":              code = "NA"; break;
        case "Nepal":                code = "NP"; break;
        case "Netherlands":          code = "NL"; break;
        case "New Caledonia":        code = "NC"; break;
        case "New Zealand":          code = "NZ"; break;
        case "Nicaragua":            code = "NI"; break;
        case "Niger":                code = "NE"; break;
        case "Nigeria":              code = "NG"; break;
        case "North Korea":          code = "KP"; break;
        case "North Macedonia":      code = "MK"; break;
        case "Norway":               code = "NO"; break;
        case "Oman":                 code = "OM"; break;
        case "Pakistan":             code = "PK"; break;
        case "Panama":               code = "PA"; break;
        case "Papua New Guinea":     code = "PG"; break;
        case "Paracel Islands":      return null;
        case "Paraguay":             code = "PY"; break;
        case "Patagonia":            return null;
        case "Peru":                 code = "PE"; break;
        case "Philippines":          code = "PH"; break;
        case "Poland":               code = "PL"; break;
        case "Portugal":             code = "PT"; break;
        case "Puerto Rico":          code = "PR"; break;
        case "Quebec":               return null;
        case "Romania":              code = "RO"; break;
        case "Russia":               code = "RU"; break;
        case "Sao Tome and Principe":code = "ST"; break;
        case "Saudi Arabia":         code = "SA"; break;
        case "Serbia":               code = "RS"; break;
        case "Shadow Exchange":      return null;
        case "Singapore":            code = "SG"; break;
        case "Slovakia":             code = "SK"; break;
        case "Slovenia":             code = "SI"; break;
        case "Solomon Islands":      code = "SB"; break;
        case "Somalia":              code = "SO"; break;
        case "South Africa":         code = "ZA"; break;
        case "South Korea":          code = "KR"; break;
        case "South Sudan":          code = "SS"; break;
        case "Spain":                code = "ES"; break;
        case "Sri Lanka":            code = "LK"; break;
        case "Sudan":                code = "SD"; break;
        case "Suriname":             code = "SR"; break;
        case "Sweden":               code = "SE"; break;
        case "Switzerland":            code = "CH"; break;
        case "Syria":                code = "SY"; break;
        case "Taiwan":               code = "TW"; break;
        case "Tajikistan":           code = "TJ"; break;
        case "Thailand":             code = "TH"; break;
        case "Tsushima Island":      return null;
        case "Tunisia":              code = "TN"; break;
        case "Turkey":               code = "TR"; break;
        case "Turkmenistan":         code = "TM"; break;
        case "Ukraine":              code = "UA"; break;
        case "Ulleungdo":            return null;
        case "United Kingdom":       code = "GB"; break;
        case "United States":        code = "US"; break;
        case "Uruguay":              code = "UY"; break;
        case "Uyghur":               return null;
        case "Uzbekistan":           code = "UZ"; break;
        case "Venezuela":            code = "VE"; break;
        case "Vietnam":              code = "VN"; break;
        case "Yemen":                code = "YE"; break;
        case "Zambia":               code = "ZM"; break;
        default:                     return null;
        }
        return isoToFlagEmoji(code);
    }

private:

    static string isoToFlagEmoji(string code)
    {
        if (code.length != 2)
            return null;
        char a = code[0];
        char b = code[1];
        if (a < 'A' || a > 'Z' || b < 'A' || b > 'Z')
            return null;
        dchar symA = cast(dchar)(0x1F1E6 + (a - 'A'));
        dchar symB = cast(dchar)(0x1F1E6 + (b - 'A'));
        import std.utf : toUTF8;
        return toUTF8([symA, symB]);
    }
}
