# Level20

A helper addon for level-20 World of Warcraft players.

Open Level20 from the minimap button, `/level20`, or `/l20`.

## Features

- Shows a compact info panel with account type, subscription status, XP gain state, current phase, Shadowlands state, and addon version status.
- Warns level-20 characters on active subscriptions when XP gain is still enabled.
- Suppresses trial/restricted-account upgrade interruptions, including subscription popups, expansion trial dialogs, Traveler's Log restrictions, and the character pane's max-level warning text.
- Filters class/spec talents and PvP talents down to the level-20 usable view.
- Adds a clear `20` badge above visible level-20 player nameplates.
- Shows Shadowlands campaign state and can block campaign skip or covenant choice actions that can make Shadowlands unavailable for level-20 characters.
- Provides one-click map waypoints for Chromie, the Experience Eliminator, and a Lorewalker, plus a clear-waypoint button.
- Syncs group data with other Level20 users and displays level, class, role, instance/phase state, War Mode, addon version, key items, and battle resurrection availability.
- Adds an optional challenge-style dungeon/raid tracker for normal level-20 runs, including timer controls, completion handling, death and wipe tracking, score display, optional Enemy Forces estimates, and battle resurrection tracking.
- Includes optional dungeon combat log controls, with separate toggles for combat logging and Advanced Combat Logging.
- Can start dungeon challenge runs from a guild addon message when enabled.
- Adds optional folder-based normal bag windows with custom folders, icons, item assignment, hiding, and show-all controls.

## Local API docs helper

This repo includes a small CLI for querying Blizzard's shipped generated API docs from local source:

```bash
luajit tools/blizzard_api_docs.lua show UnitName
luajit tools/blizzard_api_docs.lua find aura
luajit tools/blizzard_api_docs.lua systems unit
luajit tools/blizzard_api_docs.lua --json show C_UnitAuras
```

The tool reads `../../../BlizzardInterfaceCode/Interface/AddOns/Blizzard_APIDocumentationGenerated` directly, so it is useful for AI agents and local development workflows that need quick access to official API signatures, systems, events, and documentation text.
