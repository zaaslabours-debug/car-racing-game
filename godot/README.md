# Silver Lake GP — Godot Edition (4.2.2-stable)

Asphalt-style arcade racing: splash screen, premium home, garage with 3 cars,
career sprints vs AI on the Silver Lake circuit, nitro + drift physics,
mobile **TouchDrive** controls + PC keyboard/gamepad.

> This game is made by **sab ka baap Ahad Shaikh**.
> The owner of this game is **Ahad Shaikh**.

---

## 1) Play it in 2 minutes (PC)

1. Install **Godot 4.2.2-stable** (free): https://godotengine.org/download/archive/ → *4.2.2 → your OS* (use the standard build, **not** .NET unless you know why).
2. Open Godot → **Import** → select this folder's `project.godot` → **Import & Edit**.
3. Wait for the first import to finish (importing the 3D models can take a few minutes — let the progress bar complete!).
4. Press **F5** (Play). Splash → owner popup → Home → **PLAY**.

## 2) Controls

| Action | Keyboard | Gamepad | Mobile (touch) |
|---|---|---|---|
| Accelerate | W / Up | RT | **TouchDrive: automatic** (or GAS button) |
| Brake / Reverse | S / Down | LT | BRAKE button |
| Steer | A D / Arrows | Left stick | < > buttons (or enable **Tilt Steering** in Settings) |
| Drift | Space | B | DRIFT button |
| Nitro | Shift | A | NITRO button |
| Camera | C | Y | — (pause menu has settings) |
| Reset car | R | X | — |
| Teleport ahead | T | — | — |
| Pause | Esc / P | Start | **II** button (top right) |

Drifting refills the nitro tank. You start at the **back of the grid** — overtake everyone!

## 3) Export an Android APK (one-time setup)

Export presets are already included (`export_presets.cfg` → preset **Android**).

1. Install **JDK 17** (e.g. Microsoft OpenJDK or Temurin).
2. Install **Android Studio** → SDK Manager → install: *Android SDK Platform 34*, *Build-Tools 34*, *Platform-Tools*, *Command-line Tools*.
3. In Godot: **Editor → Editor Settings → Export → Android**: set *Android SDK Path* (e.g. `C:\Users\<you>\AppData\Local\Android\Sdk`) and *Java SDK Path*.
4. **Project → Install Android Build Template** (downloads into `android/`).
5. **Project → Export → Android → Export Project** → saves `builds/android/SilverLakeGP.apk` (debug-signed — installable on your phone; enable USB debugging or just copy & open the APK).

The package id is `com.saranghad.silverlakegp`, landscape, arm64.

## 4) Export Windows / Linux / Web

In Godot: **Editor → Manage Export Templates → Download and Install** (once),
then **Project → Export** and pick a preset (Windows Desktop / Linux / Web).

> Web export needs a server with COOP/COEP headers (`Cross-Origin-Opener-Policy: same-origin`, `Cross-Origin-Embedder-Policy: require-corp`) — Netlify/Vercel can add these via headers config.

## 5) How it works (for the curious)

- `scenes/splash.gd` — hero-art splash, threaded loading, tips.
- `scenes/home.gd` — ALU-style home: turntable showroom, top bar, career, owner popup.
- `scenes/garage.gd` — buy/select cars, stat bars (persistent credits in `user://`).
- `scenes/race.gd` — runtime world build: trimesh collisions from material names (`asphalt_*` → Road physics layer), **auto-scales the track by measuring road width with raycasts**, scouts the asphalt on a 64×64 grid, finds a sprint route with BFS, resamples it every ~8 m, grid start, countdown, AI (pure-pursuit + rubber-banding), positions, results.
- `scripts/car_controller.gd` — shared arcade physics: bicycle steering, drift grip, nitro economy, terrain-following raycasts, wall impacts, flames/smoke/brake-glow VFX.
- `scripts/car_rig.gd` — loads a car GLB, rotates nose to -Z, scales to real size, rigs steering/spinning wheel pivots (tagged groups or generic axle detection).
- `autoload/game_state.gd` — save data, car catalogue (orientation values verified from the model files), input map, synth beeps.

## 6) Troubleshooting

- **First open is slow / "importing"**: normal — 50 MB of GLBs. Let it finish, then F5.
- **Red errors in the debugger**: copy the exact error text (or screenshot) and send it — it points straight to the fix.
- **Race loading feels long**: the track collision + road scouting happens once per race start (watch the loading bar). It's the price of auto-fitting any track scale.
- **Car faces the wrong way** (should not happen — orientations were measured from the files): flip `yaw_offset_deg` for that car in `autoload/game_state.gd` by 180.

## Credits

- Cars: Saba V12 '95 & Formula One LP-830 SDC by Daniel Zhabotinsky (CC BY); P72 by ROH3D (CC BY) — via Sketchfab
- Track: Silver Lake LITE via Sketchfab (CC BY listing; prototype use)
- Audio: Kenney (CC0) · Font: Orbitron (OFL, The League of Moveable Type)
- Splash/banner art: AI-generated for this project
