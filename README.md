# 🏎️ Silver Lake GP — Asphalt-Style Browser Racing Game

A 3D arcade racing game for the web, built with **Three.js + Vite**.
Currently at **Prototype 0.1**: one hero car on a full circuit with arcade physics, drifting and nitro.

## ▶️ Run it

```bash
npm install
npm run dev      # http://localhost:5173
```

## 🎮 Controls

| Key | Action |
|---|---|
| W / ↑ | Accelerate |
| S / ↓ | Brake / Reverse |
| A D / ← → | Steer |
| SPACE | Drift (refills nitro) |
| SHIFT | Nitro boost |
| C | Camera (chase far / close / hood) |
| R | Reset car |
| T | Teleport to next spawn point |
| M | Mute |

Touch controls appear automatically on mobile.

## ✨ Prototype 0.1 features

- **Saba V12 '95** hero car (24.5k tris) with spinning + steering wheels, nitro flames, brake glow, underglow
- **Silver Lake circuit** auto-scaled to real-world road width (~13 m), with automatic spawn scouting on the asphalt
- Arcade vehicle physics: bicycle-model steering, lateral-grip drift system, off-road slowdown, wall impacts
- Nitro economy: boost with FOV kick + camera shake + speed vignette; drifting refills the tank
- Terrain-following suspension (bridges/tunnels handled via BVH raycasts), sunset lighting + shadows
- Engine/skid/impact audio with speed-reactive pitch, countdown start sequence, Asphalt-style HUD

## 🗺️ Roadmap

1. ✅ **Phase 1** — playable core (this build)
2. Phase 2 — AI opponents, laps, positions, race results
3. Phase 3 — car selection (De Tomaso P72 joins), ramps/jumps, particles, music
4. Phase 4 — traffic, second track, mobile polish, optimization

## 🙏 Credits

- Car: **Saba V12 '95** by Daniel Zhabotinsky (CC BY) via Sketchfab
- Car (garage, Phase 3): **De Tomaso P72 2020** by ROH3D (CC BY) via Sketchfab
- Track: **Silver Lake LITE** via Sketchfab (CC BY listing; prototype use)
- Audio: Kenney (CC0)

Full asset research: see [DOWNLOAD_MODELS.md](DOWNLOAD_MODELS.md) and [ASSETS.md](ASSETS.md).

---

## 🎮 NEW: Godot Edition (full build, mobile + PC)

The full game now also exists as a **Godot 4.2.2-stable** project in [`godot/`](godot/):
premium Asphalt-style splash + home + garage (3 cars), career sprints vs AI,
TouchDrive mobile controls + keyboard/gamepad, owner popup on launch.

Open `godot/project.godot` with **Godot 4.2.2-stable** and press **F5**. Full setup +
Android APK export guide: [godot/README.md](godot/README.md).
