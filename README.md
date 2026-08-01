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

## Known issues

### Talent application cast bar taint

The class/spec talent filter modifies Blizzard's `PlayerSpellsFrame.TalentsFrame`.
Calling `RefreshLoadoutOptions`, installing a callback with `SetNodesFilter`, and
calling `SetBasePanOffset` were each independently confirmed to taint Blizzard's
protected talent-application casting bar path.

One reproducible sequence is:

1. Reload the UI.
2. Change talents and apply them.
3. Move while the changes are being applied to interrupt the cast.
4. Stop moving and apply the changes again.

Blizzard can then raise an error from `CastingBarFrame:GetTypeInfo` while indexing
the protected `CastingBarTypeInfo` table. The talent change continues, but the
application cast bar may not appear. This is currently accepted in order to keep
the filtered Blizzard talent window. When talent filtering is disabled, Level20
does not install these callbacks or modify the talent frames. Disabling an
already-installed filter offers to reload the UI because WoW cannot remove
existing frame taint during the current UI session. Choosing to reload later
keeps the setting disabled, but the existing taint remains until the next reload.

## Local API docs helper

This repo includes a small CLI for querying Blizzard's shipped generated API docs from local source:

```bash
luajit tools/blizzard_api_docs.lua show UnitName
luajit tools/blizzard_api_docs.lua find aura
luajit tools/blizzard_api_docs.lua systems unit
luajit tools/blizzard_api_docs.lua --json show C_UnitAuras
```

The tool reads `../../../BlizzardInterfaceCode/Interface/AddOns/Blizzard_APIDocumentationGenerated` directly, so it is useful for AI agents and local development workflows that need quick access to official API signatures, systems, events, and documentation text.
