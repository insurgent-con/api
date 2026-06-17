module insurgent.store.research;

import insurgent.store.resource : Resource;
import insurgent.store : Store;

class Research
{
public:
    static Research[int] registry;

    int researchID;
    string name;
    string imageKey;
    int level;
    float[Resource] costs;
    Research[] requires;

    Research[] chain()
        => Store.researchChainFor(this);

package(insurgent.store):
    static Research getOrCreate(int researchID)
    {
        assert(researchID != 0, "researchID must not be zero");
        if (auto p = researchID in registry)
            return *p;

        Research ret = new Research(researchID);
        registry[researchID] = ret;
        return ret;
    }

    this(int researchID)
    {
        assert(researchID != 0, "researchID must not be zero");
        this.researchID = researchID;
    }
}
