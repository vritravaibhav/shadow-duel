# Shadow Duel — animation handoff

**Purpose of this file.** I (the user) am switching devices. This is a self-contained
brief so a fresh Claude session, with no memory of the previous conversation, can pick
up the character-animation work. Read it top to bottom before proposing anything.

Everything marked **VERIFIED** was checked against live sources or against this repo on
2026-09-04. Everything marked **UNVERIFIED** was not confirmed — do not repeat it to me
as fact. If a version number, price or file path below no longer matches reality, trust
the repo and the vendor page, not this document.

---

## 1. The project

| | |
| --- | --- |
| Repo | https://github.com/vritravaibhav/shadow-duel |
| Local path | `~/flutterProjects/game` |
| Stack | Flutter **3.41.9**, Dart **3.11.5**, Flame **1.38.0**, flame_audio, shared_preferences |
| Run | `flutter run` (landscape enforced on mobile) |
| Camera | `CameraComponent.withFixedResolution(960 x 540)` |
| CI | `.github/workflows/ci.yml` — analyze+test, Android APK/AAB, unsigned iOS, web → GitHub Pages |
| APK | https://github.com/vritravaibhav/shadow-duel/releases/latest (rolling `build-N`, debug-signed, sideload) |
| Web | https://vritravaibhav.github.io/shadow-duel/ |

**Standing rule for commits in this repo: never add a `Co-Authored-By: Claude` trailer,
or any other AI attribution.** Commits are mine alone. This has been asked for once and
history has already been rewritten once to strip it.

A 2D isometric-ish sword fighter. Title → endless stage map → battle → result. 15
downloaded CC0/CC-BY character packs, 10 swords as timed cards, sword arts via drawn
V/W glyphs, a 64-combo two-stick control scheme, a dojo that teaches it, three-star
scoring, coins/forge economy.

**Work happens from more than one machine.** Commit `dded6d7` ("added coins, bounce,
forge animation") came from a different session than the one that wrote this file.
**Always `git fetch` and read the actual current code before advising** — a previous
session gave me stale advice by trusting its own memory of a file that had since changed.

---

## 2. What I actually want

**Characters that look like Shadow Fight** — smooth, fluid, not pixelated.

That is the whole ask. I have said twice, and repeat here: **I am not an animator and I
do not want to become one.** Any proposal whose critical path is "you keyframe the
motions" is a bad proposal for me, no matter how good the tool is.

---

## 3. Why it currently looks pixelated (VERIFIED, with numbers)

Measured from this repo, not estimated:

- Source frames are **200 x 200 px**, but the drawn character occupies only about
  **37–48 px wide x 48–56 px tall** inside that canvas (attacks reach ~120x69).
- `packs.json` sets `scale: 0.3467`, so a fighter draws at **69.34 game units** tall in
  a 540-unit-tall camera.
- On a 1080p phone the 960x540 camera is upscaled **2.0–2.5x**.
- Net effect: roughly **52 px of real drawn pixels blown up to ~139 screen px ≈ 2.7x**.

Effective frame rates, computed from `assets/images/packs.json`:

| clip | frames | duration | fps |
| --- | --- | --- | --- |
| idle | 8 | 0.800s | 10.0 |
| walk | 8 | 0.667s | 12.0 |
| punch / kick / slash | 6 | 0.500s | 12.0 |
| heavy | 6 | 0.545s | 11.0 |
| hit | 4 | 0.333s | 12.0 |
| **jump / fall** | **2** | 0.200s | 10.0 |

**Two separate problems, do not conflate them:**

1. **Blockiness** — magnified low-res pixels. *Already addressed, see §4.*
2. **Choppiness** — 6-frame attacks at 10–12 fps, and **2-frame jump/fall**. The aerial
   combos, guard advances and back-hops all run on those 2-frame clips, so airborne
   moves look worst. **Nothing has fixed this. This is the real remaining problem.**

**A third factor that makes it feel worse than the numbers suggest:** every *other*
element in the game — backgrounds, UI, moon, torii, HUD — is smooth vector drawing. The
characters are the only pixel-art objects on screen, so the mismatch is glaring. Making
the characters smooth would make the whole game look coherent.

---

## 4. Already done — do NOT redo these

- **Bilinear filtering + inked silhouette pass.** `lib/game/fighter.dart` (~line 720)
  already renders characters with `FilterQuality.low` and a dark outline pass, with the
  comment "The packs are magnified ~3x; bilinear sampling melts the stair-steps". An
  earlier session proposed this as a "free one-line fix" **after it had already been
  committed** — it was working from stale code. It is done. It helped. It did not solve
  the problem.
- **Guard poses matched to zones** (commit `bd4f259`). The pack's attack wind-ups double
  as guard poses; they were wired inverted (high guard showing the sword low). Fixed.
- **64-combo system + dojo** (commit `cbdcfba`).

---

## 5. Research verdict — what NOT to do

Two multi-agent research runs were done, each with an adversarial vetting pass against
live vendor pages. Findings that survived:

### Do not hand-author Rive or Spine (the main trap)

Independent agents converged on this. These tools give you a **rig**, not **motions**.
64 combos + blocks + parries + step-backs + aerials is **80–100 timelines** to key by
hand. The sharpest conclusion from the vetting:

> A non-animator's hand-keyed Rive fighter will look floaty and weightless — a worse
> outcome than the pixel sprites you have now, because pixel art reads as a deliberate
> style while bad vector animation reads as broken.

Also **VERIFIED**: **Rive's free tier cannot export `.riv` at all.** Shipping requires
Cadet at **$9/seat/month indefinitely**; cancel and you can no longer re-export.

### Tool facts (all VERIFIED on pub.dev / vendor pages, 2026-09-04)

| Thing | Status |
| --- | --- |
| `flame_rive` **1.11.2** (2026-07-19) | Needs flame `^1.38.0`, Flutter `>=3.41.0` — **exact match for this project**. `flutter pub add --dry-run flame_rive` **resolves cleanly**, +4 deps, no conflicts. MIT. |
| `rive` **0.14.11** (2026-08-03) | MIT runtime, actively maintained. Editor free; **export paywalled**. |
| `spine_flutter` **4.3.6** | Exists. But Spine Essential **$69** *excludes meshes* (the thing that makes limbs bend smoothly); Professional **$379**. Flame integration is the least-travelled path — a real risk signal. |
| `dragon_bones` | **Not on pub.dev.** DragonBones Pro's last release is 5.6.3 from **2020**, download link dead. Ruled out. |
| `flutter_scene` (3D) | **Hard blocker**: needs Flutter **3.47+**; this project is on 3.41.9. |
| `flame_3d` | Experimental, 0.3.0, breaking changes between minors. Too risky for a shipping game. |
| Meta "AnimatedDrawings" auto-rigging | Repo **archived 2025-09-03**, read-only. Paper-cut-out limb hinging, not weighty motion. |

### Pixel-art AI generators (from the earlier run, if you stay pixel)

Vetters were harsh: Rosebud's own FAQ admits its sprite generator is unfinished;
Scenario's KB confirms reference images "are not used as starting frames"; Layer and
God Mode AI failed on inability to match an existing character. The two that survived:

- **Retro Diffusion** — uses *your* frame as literal frame 1. **$0.14/generation**,
  $0.25 for `custom_action`. Has an MCP server. Drift across frames needs cleanup.
- **PixelLab** — **skeleton-based**: you pose a stick figure, it renders your character
  into those poses. Ranked best of the generators, precisely because it is skeletal.

---

## 6. Recommended path: mocap → baked silhouette sheets

**Mixamo + Blender**, rendering 3D motion-capture to flat black silhouette sprite sheets.

Why this one:

- **You never key a pose.** Browse a mocap library, click, render.
- **$0** — Mixamo is free with an Adobe ID and **royalty-free for commercial use**
  (VERIFIED; redistributing the raw files is prohibited). Blender is free/GPL.
- The work is **engineering, not animation craft** — building a render pipeline. That is
  my actual skill set.
- Delivers **both** things I asked for: the Shadow Fight silhouette look *and* genuine
  24–30 fps mocap smoothness.
- **The existing codebase survives.** `sprites.dart`, `packs.json`, `import_packs.py`,
  `ClipPhase`/`ComboClip` in `combos.dart` all keep working — they would be fed better
  frames, not rewritten. This is the single biggest advantage over going skeletal.

Honest blockers (VERIFIED):

- Mixamo's melee library is thin — decent idle/walk/hit/death and generic punches and
  kicks, but **no weapon-specific combat**, which a sword game leans on hard.
- **Memory/APK size**: 512x512 RGBA is ~1 MB/frame in GPU memory. Render at 320–384 px,
  keep the existing per-character on-demand loading, or pack silhouette masks into RGBA
  channels.
- Blender is a new tool; the first render will have sliding feet, a non-orthographic
  camera and baked-in root motion. Budget for that.
- **Silhouettes flatten the roster** — Malakar and King Oswald become the same black
  shape unless build and props vary. `packs.json` has a per-character `build` (0.9–1.4)
  which is currently the only differentiator.

### Cheap test first — spend $7 before building anything

A pre-rigged **"Stickman Fighter Spine 2D Character"** is listed at **$7+**
(pay-what-you-want) with **31 animations**, and **no Spine licence is needed if you use
only the included PNG sequences** (VERIFIED). Point `tool/import_packs.py` at it and see
whether silhouettes actually feel right *before* committing to a pipeline.

### If I decide to stay pixel instead

**LuizMelo — Knights Pack** (https://luizmelo.itch.io/knights-pack), the *same artist*
as the current packs, CC0. Animation list VERIFIED live as: *Idle, Run, Jump, Fall,
Attack, **Hold Shield**, **Block**, Take Hit, Death*. This is real block art in a
matching style — it would fix the one genuine art gap (no block/parry/step-back clips).
A **dreamir** pack with 25 animations including *Idle Block, Block, Crouch, Slide* was
also confirmed.

---

## 7. Technical specs a new session will need

**Frame format** (what `tool/import_packs.py` expects and `packs.json` describes):

- 200 x 200 px per frame, **single horizontal row**, transparent PNG
- Feet anchor for `martial-hero`: `ax: 94.5`, `ay: 122`; `scale: 0.3467`
- The importer auto-detects frame width, feet line and facing, and writes per-frame
  weapon-tip points used for sword trails

**Key files**

| File | Role |
| --- | --- |
| `lib/game/sprites.dart` | `SpriteLibrary` — atlas loader, `BakedAnim`, the `pixel` flag |
| `lib/game/combos.dart` | 64 combos; `Dir`, `Combo`, `ClipPhase`, `ComboClip`, `ComboPlayer` |
| `lib/game/fighter.dart` | Combat state machine **and the render path** (filtering, ink pass, tint) |
| `lib/game/shadow_game.dart` | Game core, `_pollSticks` (stick → combo) |
| `assets/images/packs.json` | Atlas: frame sizes, anchors, scale, durations, facing, tips |
| `tool/import_packs.py` | Pack importer (Python/PIL) |

**How animation composition works today** — worth understanding before replacing it.
`ClipPhase` composes 64 distinct motions out of ~11 source clips using `from`/`to`
sub-ranges plus procedural body motion: `hop` (sine arc), `dx` (bell-curve travel that
eases in and out), `lean`, `squash`, `speed`. Motion is already smooth and eased; the
frames are what step. Any replacement must provide the same composability or `combos.dart`
loses the thing that makes 64 combos affordable.

---

## 8. Decisions I still need to make

1. **Silhouettes or full-colour?** Silhouettes are dramatically cheaper and are the
   Shadow Fight look, but collapse 15 distinct villains into one black shape.
2. **Full roster or one fighter?** Any skeletal/mocap path realistically ships 1–2
   fighters, not 15.
3. **Is smoothness worth losing the 15 packs?** They work today and cost nothing.
4. Whether to do the **$7 stickman test** before anything else. (Recommended.)

## 9. Suggested first moves for a new session

1. `git fetch && git log --oneline -5` — confirm the current head; do not trust §4.
2. Read `lib/game/fighter.dart`'s render path and `lib/game/combos.dart`'s `ClipPhase`
   before proposing any replacement.
3. Ask me decisions 1–3 in §8 rather than assuming.
4. If proceeding with mocap: build the Blender → sprite-sheet script first and prove it
   on **one** clip (idle) end-to-end through `import_packs.py` into the running game,
   before touching a second clip.

## 10. Known loose ends (unrelated to animation)

- `test/zz_combatprobe_q7_test.dart` and `test/zz_probe_test.dart` look like leftover
  agent probe files from commit `dded6d7`. Previous sessions have left these behind and
  they were deleted. Check whether they are intentional.
- A "Sword Arts Codex" artifact page exists but is out of date — it still describes the
  old card-durability model and the pre-combo gesture controls.
