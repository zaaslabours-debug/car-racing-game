# 🏎️ Asset Checklist — Asphalt-Style Browser Racing Game

Everything we need to build the game. Tick items off as we collect them.
**Golden rule:** MEDIUM-POLY assets for the Asphalt Legends feel — cars **15k–50k triangles**, `.GLB`/glTF format, textures ≤ 2048×2048.

> 📋 **Car download list is ready → [DOWNLOAD_MODELS.md](DOWNLOAD_MODELS.md)** (9 verified free Sketchfab cars in range). Waiting for ZIPs to be uploaded to `incoming-models/`.
> ❌ Low-poly kits (Kenney cars ~2k tris etc.) were tested and **rejected** — too low-poly for the Asphalt look. Only the Kenney *audio* was kept.

---

## 🚗 1. Cars (Player + AI Opponents) — 15k–50k tris each

Wheels should be separate meshes so they can spin and steer (I'll verify after upload).

- [ ] Supercar — *Marussia (22.9k tris) picked, awaiting download*
- [ ] Sports car — *Nissan Skyline R32 GT-R (24.6k) picked, awaiting download*
- [ ] Sports car 2 — *Nissan 300ZX Z32 (31.3k) picked, awaiting download*
- [ ] Muscle car — *Phoenix 455 '71 (25.9k) picked, awaiting download*
- [ ] F1 / open-wheel — *Formula One LP-830 SDC (31.2k) picked, awaiting download*
- [ ] Hypercar / concept — *optional: De Tomaso P72 (bonus list)*

## 🚙 2. Traffic Vehicles

- [ ] Taxi — *Canyon '75 Taxi (20.0k) picked, awaiting download*
- [ ] Sedan — *Fairheaven LT '80 (19.7k) picked, awaiting download*
- [ ] Police sedan — *Negotiator '80 (19.7k) picked, awaiting download*
- [ ] Hatchback — *Fiat Punto GT (35.2k) picked, awaiting download*
- [ ] Truck / van / bus — *to pick in round 2*

## 🏙️ 3. Track & Environment

Strategy: build the track procedurally in code (road ribbon from a spline, guardrails,
ramps, instanced city buildings with PBR window textures) so it matches the medium-poly
cars and stays fast. Ready-made pieces below only if needed.

- [ ] Road / track surface — *procedural (code)*
- [ ] **Ramps** for jumps (signature Asphalt feature!) — *procedural (code)*
- [ ] City buildings — *procedural + textures (code), or medium-poly pack later*
- [ ] Start / finish arch — *procedural (code)*
- [ ] Guardrails / barriers — *procedural (code)*
- [ ] Streetlights, cones, billboards, trees — *procedural/instanced (code)*

## 🌆 4. Sky & Textures

- [ ] Sky — gradient + clouds generated in code (sunset city vibe), HDRI optional
- [ ] Road asphalt texture (tileable) — procedural canvas texture or free PBR texture
- [x] Particle sprites (smoke, spark) — generated in code

## 🔊 5. Audio

- [x] Engine sound loop — `public/audio/engine.ogg` (Kenney, CC0) — I'll pitch-shift with RPM
- [x] Tire screech / skid — `public/audio/skid.ogg` (Kenney, CC0)
- [x] Crash / impact — `public/audio/impact.ogg` (Kenney, CC0)
- [x] Alt engine (motorcycle) — `public/audio/engine-motorcycle.ogg` (Kenney, CC0)
- [ ] Nitro / boost whoosh — synth in code or find sample
- [ ] Countdown beeps + GO — synth in code (Web Audio)
- [ ] UI click / hover — synth in code
- [ ] Win / lose jingle — synth in code
- [ ] Background music — 2–3 electronic tracks (TBD)

## 🎨 6. UI / 2D (handled by me)

- [x] Racing font — Orbitron (Google Fonts)
- [x] Speedometer, nitro bar, minimap, position display — HTML/CSS/SVG
- [x] Icons (pause, settings, nitro) — SVG
- [ ] Game logo / name artwork

---

## 🆓 Asset Sources

| Source | Best for | Notes |
|---|---|---|
| **sketchfab.com** | Medium-poly cars (15k–50k) | ✅ Main source — verified list in DOWNLOAD_MODELS.md |
| fab.com | Vehicle packs | Mostly Unreal/FBX — needs Blender → GLB conversion |
| kenney.nl | Audio (CC0) | Models too low-poly for this project |
| freesound.org | Extra sounds | Check license per file |

## 📁 Project Structure

```
public/
├── models/
│   ├── cars/          ← hero + AI cars (.glb) — filled after upload
│   ├── traffic/       ← traffic vehicles (.glb)
│   └── environment/   ← props if needed
└── audio/             ← engine/skid/impact ✅ already here
incoming-models/       ← 📥 user uploads Sketchfab ZIPs here
```

## ⚠️ Format Rules (Browser Performance)

- ✅ `.GLB` / glTF format
- ✅ Cars **15k–50k triangles** (medium poly = Asphalt feel + 60 FPS)
- ✅ Textures ≤ 2048×2048 (I'll compress oversized ones after upload)
- ✅ Total game size target: **under 50 MB**
- ❌ No 100k+ tri showcase models, no cartoon low-poly for hero cars

## 💻 What I Build in Code (NO assets needed)

- Arcade car physics — acceleration, steering, **drift mechanics**
- **Nitro system** with FOV kick + speed effects
- AI opponent racers with racing lines
- Procedural track + city environment (spline road, ramps, buildings)
- Collision detection & crash physics
- Chase camera with shake + dynamic FOV
- HUD — speedometer, position, lap counter, nitro bar, minimap
- Menus — main menu, car selection, pause, race results
- Particle effects — drift smoke, sparks, nitro flames, speed lines
- Race logic — laps, checkpoints, positions, countdown
- Keyboard + mobile touch controls
- Sound manager (engine pitch tied to speed)

## 🗺️ Build Order

1. **Phase 1 (playable core):** 1 car + procedural track + physics + nitro + HUD
2. **Phase 2 (real race):** AI opponents, laps, positions, countdown, results
3. **Phase 3 (Asphalt feel):** car selection, all cars, ramps/jumps, particles, music
4. **Phase 4 (polish):** traffic, extra track theme, mobile controls, optimization
