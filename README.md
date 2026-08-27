# Shadow Duel

An endless isometric sword-fighting campaign built with Flutter + Flame, using
free CC0 / CC BY pixel-art packs downloaded from itch.io and Kenney (see
[CREDITS.md](CREDITS.md)).

| Title | Stage map | Battle |
| --- | --- | --- |
| ![title](screenshots/title.png) | ![map](screenshots/map.png) | ![fight](screenshots/fight.png) |

## Run

```sh
flutter run            # pick a device; landscape is enforced on mobile
```

## Flow

**Title → endless stage map → battle → result → next stage.** The map winds
upward forever; every stage pits Kaito against the next of 14 villains, and
each lap through the roster raises the tier (more HP, damage, aggression).
Progress (highest stage cleared) is saved on the device.

## Sword cards

Every owned sword is a card in the bar at the bottom of the battle screen —
Clash-style, with bare hands as the first slot.

- **Strength** multiplies all damage; **Power** additionally multiplies the
  heavy smash; **Speed** scales swing time.
- **Durability** wears down with every swing (more when the enemy blocks).
  When it hits zero the blade **shatters**, goes on **recharge**, and the next
  ready card is drawn automatically — or you fight bare-handed.
- **Tap a card mid-fight to switch.** The card you put away recharges for half
  its recharge time and comes back at full durability.
- Each sword has a **special**: Quick Draw, Bleed, Cleave, Ignite, Freeze,
  Lifesteal, Shock, Poison, Radiance, Dragonfire.

Starters: Wakizashi + Katana. Unlocks: Nodachi (stage 2), Flame Blade (4),
Frost Edge (6), Shadow Blade (8), Thunder Fang (10), Venom Kris (12),
Excalibur (14), Dragon Cleaver (16). The **Armory** on the map lists every
blade's stats.

## Controls

| Input | Action |
| --- | --- |
| Left joystick | Move on the isometric floor (x + depth) |
| Tap (right side) | Quick strike |
| Swipe ◄ / ► | Slash |
| Swipe ▲ | Rising kick (launches, can headshot) |
| Swipe ▼ | Heavy smash (breaks guard, can headshot, triggers heavy specials) |
| Stand still | Auto-guard (blocks all but heavy attacks) |
| Card bar | Tap a sword card to switch blades |

## Assets

- `assets/images/packs/<pack>/` — 15 downloaded LuizMelo character packs
  (spaces removed from filenames), each with its `License.txt` and a generated
  `portrait.png`
- `assets/images/swords/` — 10 sword icons (Kyrise)
- `assets/images/ui/` — Kenney card frames, buttons, map nodes, icons
- `assets/images/packs.json` — atlas written by the importer: frame sizes
  (non-square supported), feet anchors, scale, durations, facing, per-frame
  weapon-tip points for trails, and the game-animation → sheet mapping
- `assets/images/arena.png`, `meta.json` — the project's own arena backdrop
  and bare-hands icon

### Adding a character pack

1. Drop the pack's sprite strips into `assets/images/packs/<name>/`.
2. Add it to `PACKS` in `tool/import_packs.py` (on-screen height, portrait
   framing) and run `python3 tool/import_packs.py` — it auto-detects frame
   width, feet line, and facing, and maps Idle/Run/Attack*/Take Hit/Death.
3. List the folder under `assets:` in `pubspec.yaml` and add a `StageChar`
   to the roster in `lib/game/shadow_game.dart`.

## Code map

- `lib/game/shadow_game.dart` — game core: stages, roster, phases, card deck
  wiring, strike resolution and sword specials
- `lib/game/cards.dart` — card economy (durability, shatter, recharge, switch)
- `lib/game/weapons.dart` — the 10 swords, specials, move specs
- `lib/game/progress.dart` — saved progress (shared_preferences)
- `lib/game/sprites.dart` — atlas loader (`SpriteLibrary`)
- `lib/game/fighter.dart` — sprite-sheet fighter, combat state machine,
  status effects (bleed/burn/poison/freeze/shock)
- `lib/game/villain.dart` — villain AI
- `lib/game/hud.dart` — health bars, portraits, combo, card bar, gesture zone
- `lib/ui/screens.dart` — title, endless map, armory, result screens
- `tool/` — asset pipeline (pack importer, arena/icon baker); not compiled
  into the app
