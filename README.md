# Level20
 
A simple helper addon for 20 level players:

- Suppresses "Max Level" alerts and red error text in the character info pane.
- Silently hides all talents requiring level 21 or higher to keep your interface relevant.
- Adds a clear "20" marker to player nameplates to easily identify others at the bracket cap.
- Triggers a warning if you are level 20 on a subscribed account without your XP gain disabled.
- Adds detailed info lines to the UI showing Account Type (Starter/Veteran/Standard), Subscription Status, XP Lock state, and Chromie Time.
- Shows Shadowlands campaign state and can block campaign skip / covenant choice actions that make Shadowlands unavailable for level-20 characters.
- One-click map pins for the Experience Eliminator (Behsten/Slahtz), Chromie, and Lorewalker Cho.
- Adds a challenge mode style dungeon timer that starts on first combat, stops on dungeon completion, and can be reset manually from the addon window.

## Local API docs helper

This repo includes a small CLI for querying Blizzard's shipped generated API docs from local source:

```bash
luajit tools/blizzard_api_docs.lua show UnitName
luajit tools/blizzard_api_docs.lua find aura
luajit tools/blizzard_api_docs.lua systems unit
luajit tools/blizzard_api_docs.lua --json show C_UnitAuras
```

The tool reads `../../../BlizzardInterfaceCode/Interface/AddOns/Blizzard_APIDocumentationGenerated` directly, so it is useful for AI agents and local development workflows that need quick access to official API signatures, systems, events, and documentation text.
