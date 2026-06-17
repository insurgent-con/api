# Insurgent (API)

> [!WARNING]
>
> Any maintainers or contributors of this project do not have any affiliation with any use of the library and we are not responsible for any misuse of the library.
>
> We do not condone any use of this library that violates the terms of service of Conflict of Nations / Supremacy WW3 or Twin Harbor.
>
> Proceed at your own risk.

Insurgent API is a D library that parses and exposes Supremacy WW3 (Conflict of Nations) static game data and live match state. It requires the game to be running in Selenium and uses JS scripts to extract data from the game, then normalizes the raw output to D types.

## Features

- **Static data** for units, buildings, research, resources, and terrains, parsed from the live client into strongly typed D objects with full cross-referencing.
- **Match state scraping** via WebDriver, including nations, army stacks, tiles, and province buildings, with live selection polling.
- **Filesystem cache** with version invalidation for static data and configurable policies (memory-only, throttled, or persistent) for match snapshots.
- **Asset resolution** that maps entity image keys to local `assets/` paths, with an optional royalty-free fallback mode.

## Getting Started

This library is not published on DUB and must be consumed as a local path dependency.

Add the package as a local path dependency in your `dub.json`:

```json
"dependencies": {
    "insurgent-api": { "path": "../path/to/api" }
}
```

You will also need `selenium-sdk` in your project to provide a `Driver` instance for refreshing data from the live client. This will require the user to have a web driver installed, ideally for Chrome.

## API

Currently the documentation is quite lacking, but this will change with later versions.

The following modules are the primary way that you will use the API:

| Module | Types |
| --- | --- |
| `insurgent.store.unit` | `Unit`, `UnitFamily` |
| `insurgent.store.building` | `Building`, `BuildingFamily` |
| `insurgent.store.research` | `Research` |
| `insurgent.store.resource` | `Resource` |
| `insurgent.store.tile` | `TileType` |
| `insurgent.store.common` | `DamageType`, `Terrain`, `Perks`, `CombatStats`, `TerrainStats` |
| `insurgent.match.unit` | `MatchUnit` |
| `insurgent.match.stack` | `Stack` |
| `insurgent.match.tile` | `Tile` |
| `insurgent.match.nation` | `Nation` |
| `insurgent.match.building` | `MatchBuilding` |

Load static data from the cache or refresh it from the browser:

```d
import insurgent;

Store.load();                       // from cache
Store.refresh(driver);              // from live client
```

Create a match and refresh its state:

```d
Match match = new Match();
match.refresh(driver);              // full match snapshot
match.refreshSelection(driver);     // selected stack / tile only
```

Static data is cached automatically after the first successful refresh. Match snapshots are throttled by default; change the policy via `cache().setMatchPolicy(...)`.

## LICENSE

Insurgent API (this repository) is licensed under [AGPL-3.0](LICENSE.txt).