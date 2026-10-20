# 🚗 Medium-Poly Car Models to Download (15k–50k triangles) — Commercial-Safe Edition

I researched Sketchfab's catalog through their API and **verified every car below**:
✅ FREE download · ✅ 15,000–50,000 triangles · ✅ **CC-BY license (legal even if you monetize the game later)**

> 💡 Since you might monetize the game someday, I removed all "CC BY-**NC**" (NonCommercial) cars
> from the earlier list and replaced them with commercial-safe **CC-BY** models.
> Most picks are *generic* (unbranded) designs — the safest choice for a commercial game.

> I can't download from Sketchfab myself (it needs a login + my network is restricted),
> so please download these and upload the ZIPs into the **`incoming-models/`** folder of this repo.
> Instructions at the bottom. 👇

---

## ⭐ TOP PICKS — Download These 6 First

| # | Car | Triangles | Size | License | Author | Link |
|---|-----|-----------|------|---------|--------|------|
| 1 | **Saba V12 '95** (Italian-style supercar ⭐ hero car) | 24,552 | ~13 MB | CC BY | Daniel Zhabotinsky | [Open on Sketchfab](https://sketchfab.com/3d-models/none-3ab977050c334c13b6abb5de078b4957) |
| 2 | **De Tomaso P72 2020** (hypercar) | 21,496 | ~17 MB | CC BY | ROH3D | [Open on Sketchfab](https://sketchfab.com/3d-models/none-ab85c302e652492196b600ee1eb7106a) |
| 3 | **Tiara GT '83 Tuned** (JDM drift sports car) | 18,553 | ~11 MB | CC BY | Daniel Zhabotinsky | [Open on Sketchfab](https://sketchfab.com/3d-models/none-59a0eaaa2af144b2956957e7032d0221) |
| 4 | **Phoenix 455 '71** (American muscle) | 25,947 | ~12 MB | CC BY | Daniel Zhabotinsky | [Open on Sketchfab](https://sketchfab.com/3d-models/none-955edc733c6d44fabc0ad7c246a15896) |
| 5 | **Formula One LP-830 SDC** (F1 car) | 31,180 | ~3 MB | CC BY | SDC PERFORMANCE™️ | [Open on Sketchfab](https://sketchfab.com/3d-models/none-aeebdfa53e294e0390f3c2e8bbfe31b6) |
| 6 | **Canyon '75 Taxi** (traffic) | 20,037 | ~12 MB | CC BY | Daniel Zhabotinsky | [Open on Sketchfab](https://sketchfab.com/3d-models/none-9e8f92a215784f3d8aaaaeab1bef54c4) |

These 6 give us: hero supercar + hypercar + drift sports car + muscle car + F1 special + first traffic car. Enough to build the whole game around. 🏁

## 🚙 More Verified Picks (traffic variety — grab them too if you can)

| Car | Triangles | Size | License | Author | Link |
|-----|-----------|------|---------|--------|------|
| **Negotiator '80** (police-style sedan) | 19,747 | ~11 MB | CC BY | Daniel Zhabotinsky | [Open on Sketchfab](https://sketchfab.com/3d-models/none-892b2684fb37442299bfad9222cf331c) |
| **Fairheaven LT '80** (sedan) | 19,709 | ~16 MB | CC BY | Daniel Zhabotinsky | [Open on Sketchfab](https://sketchfab.com/3d-models/none-e2678da920cc4be68dbc193727919ffb) |
| **Chrysler Saratoga 1960** (classic sedan) | 17,764 | ~13 MB | CC BY | ROH3D | [Open on Sketchfab](https://sketchfab.com/3d-models/none-3fa89e6bf78b49aab111af4195efb6fe) |

## 🏔️ Bonus Environment (optional, later)

| Model | Triangles | Size | License | Author | Link |
|-------|-----------|------|---------|--------|------|
| **Snowy Mountain Road Scene** | 34,778 | ⚠️ ~36 MB | CC BY | 99.Miles | [Open on Sketchfab](https://sketchfab.com/3d-models/none-504729dd1afc4ff0a7dd17687ccd71a1) |

⚠️ The snowy scene's ZIP is ~34 MB — GitHub's *web* upload limit is 25 MB, so this one needs GitHub Desktop/git (or skip it; our main track will be procedural anyway).

## 🔍 Want Even More Cars?

These two authors are goldmines of commercial-safe, game-ready cars (their "low poly" naming is misleading — most are actually in our 15k–50k sweet spot). Browse with the **Downloadable** filter and check each page shows **15k–50k triangles** + **CC Attribution** license:
- Daniel Zhabotinsky → https://sketchfab.com/DanielZhabotinsky/models (generic cars, explicit "use as you see fit" permission)
- ROH3D → https://sketchfab.com/roh3d/models

## ⛔ Do NOT Download These (checked, rejected)

| Model | Why rejected |
|---|---|
| Marussia, Nissan R32 GT-R, Nissan 300ZX, Toyota Supra A80 (Lexyc16), Nissan GT-R (iSteven) | **CC BY-NC** — illegal to use if you monetize |
| 1995 Fiat Punto GT (Lionsharp) | ~30 MB ZIP (over upload limit) + real Fiat branding |
| Koenigsegg Agera RS (RongstadJ) | 48k tris but **50 MB** / 102 textures — way too heavy for web |

---

## 📥 How to Download & Upload (2 minutes per car)

1. **Create a free Sketchfab account** (needed to download) → https://sketchfab.com
2. Open a car link above → click **Download 3D Model** → choose **glTF** format
   (⚠️ NOT "USDZ", NOT "Original format" — glTF is what our game engine eats). You'll get a `.zip` file.
3. Open this GitHub repo → switch branch to **`arena/f157b2e5-car-racing-game`** (branch dropdown, top-left of file list)
4. Open the **`incoming-models`** folder → **Add file → Upload files** → drag the `.zip` file(s) in — **don't unzip them** → **Commit changes**
5. Come back here and tell me: **"models uploaded"** ✅

Then I will: extract the ZIPs → verify triangle counts & check wheels are separate parts → fix scale/orientation → compress the textures (most of these cars shrink 3–4×, e.g. 12 MB → ~3 MB, with no visible quality loss) → organize them into `public/models/` → add author credits → start building Phase 1. 🎮

## ⚖️ License Notes (important, quick read)

- **CC BY** = free for anything *including commercial*, just credit the author (I'll maintain a CREDITS file in the game). Every car on this list is CC BY. ✔️
- **CC BY-NC** = NonCommercial — **banned from our list** since you may monetize.
- Two picks are real-world designs (**De Tomaso P72**, **Chrysler Saratoga**) — the *models* are CC BY, but car brand names/designs are trademarks of their companies. Standard indie solution: I'll **rename them in-game** (e.g. "Veloce P72", "Saratoga Classic") and we never use the real brand names in marketing. The other 7 cars are fully generic — zero risk.
- Daniel Zhabotinsky additionally writes on every model: *"I unconditionally give you permission to use this model at your discretion, modify it or implement it into a digital product."* — as safe as it gets. 🛡️

## 🏪 About Fab.com

Fab also has free vehicle models (https://www.fab.com/search?q=car — tick the **Free** filter), BUT most Fab assets come in Unreal Engine / FBX format, which needs a Blender conversion step before a browser game can use them. Sketchfab's glTF downloads work instantly in our engine — that's why the list above is Sketchfab-first. If you spot a Fab car you love, grab the FBX and I'll guide you through converting it.
