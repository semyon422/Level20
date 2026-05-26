# Level20 Agent Notes

- Blizzard UI source code is available locally at `../../../BlizzardInterfaceCode`.
- Prefer inspecting that local source before using web requests for Blizzard UI internals.
- `../../../BlizzardInterfaceCode/Interface/AddOns/Blizzard_APIDocumentationGenerated` is the main local source for Blizzard's shipped generated API docs and powers the in-game `/api` browser.
- Prefer using `./tools/blizzard_api_docs.lua` for quick API lookups before manually grepping the generated docs.
- Useful commands:
  - `./tools/blizzard_api_docs.lua show UnitName`
  - `./tools/blizzard_api_docs.lua show C_UnitAuras.GetAuraDataByIndex`
  - `./tools/blizzard_api_docs.lua find aura`
  - `./tools/blizzard_api_docs.lua systems unit`
- Do not assume `Blizzard_APIDocumentationGenerated` contains every callable WoW API surface or behavior detail; use the wider `BlizzardInterfaceCode` source as a fallback for undocumented globals, helper Lua, XML/template behavior, and internal/secure details.
