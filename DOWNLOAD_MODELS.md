# 🚗 Medium-Poly Car Models to Download (15k–50k triangles)

I researched Sketchfab's catalog through their API and **verified every car below**:
✅ FREE download · ✅ 15,000–50,000 triangles (your medium-poly range) · ✅ game-ready style models with PBR textures

> I can't download from Sketchfab myself (it needs a login + my network is restricted),
> so please download these and upload the ZIPs into the **`incoming-models/`** folder of this repo.
> I'll extract, inspect, compress and wire them into the game. Instructions at the bottom. 👇

---

## ⭐ TOP PICKS — Download These 6 First

| # | Car | Triangles | Size | License | Author | Link |
|---|-----|-----------|------|---------|--------|------|
| 1 | **Marussia** (supercar) | 22,872 | ~1 MB | CC BY-NC | Lexyc16 | [Open on Sketchfab](https://sketchfab.com/3d-models/none-c5a45faa55174b3ea9b7ac37d6412c6c) |
| 2 | **Nissan Skyline (R32) GT-R** | 24,612 | ~3 MB | CC BY-NC | Lexyc16 | [Open on Sketchfab](https://sketchfab.com/3d-models/none-8810e677eca543a6b840cf67dd064aa4) |
| 3 | **Nissan Fairlady 300ZX (Z32)** | 31,339 | ~3 MB | CC BY-NC | Lexyc16 | [Open on Sketchfab](https://sketchfab.com/3d-models/none-8c04336a4ed84f6f836760db8256f9f0) |
| 4 | **Phoenix 455 '71** (American muscle) | 25,947 | ~12 MB | CC BY | Daniel Zhabotinsky | [Open on Sketchfab](https://sketchfab.com/3d-models/none-955edc733c6d44fabc0ad7c246a15896) |
| 5 | **Formula One LP-830 SDC** (F1 car) | 31,180 | ~3 MB | CC BY | SDC PERFORMANCE™️ | [Open on Sketchfab](https://sketchfab.com/3d-models/none-aeebdfa53e294e0390f3c2e8bbfe31b6) |
| 6 | **Canyon '75 Taxi** (traffic) | 20,037 | ~12 MB | CC BY | Daniel Zhabotinsky | [Open on Sketchfab](https://sketchfab.com/3d-models/none-9e8f92a215784f3d8aaaaeab1bef54c4) |

These 6 give us: hero supercar + 2 JDM sports cars + muscle car + F1 special + first traffic car. Enough to build the whole game around. 🏁

## 🚙 More Verified Picks (traffic / variety — download if you like them)

| Car | Triangles | Size | License | Author | Link |
|-----|-----------|------|---------|--------|------|
| **Negotiator '80** (police-style sedan) | 19,747 | ~11 MB | CC BY | Daniel Zhabotinsky | [Open on Sketchfab](https://sketchfab.com/3d-models/none-892b2684fb37442299bfad9222cf331c) |
| **Fairheaven LT '80** (sedan) | 19,709 | ~16 MB | CC BY | Daniel Zhabotinsky | [Open on Sketchfab](https://sketchfab.com/3d-models/none-e2678da920cc4be68dbc193727919ffb) |
| **1995 Fiat Punto GT** (hatchback) | 35,168 | ⚠️ ~30 MB | CC BY | Lionsharp Studios | [Open on Sketchfab](https://sketchfab.com/3d-models/none-48db6facb4b64e99b60f36b8c01185e1) |

⚠️ **Fiat Punto GT warning:** its ZIP is ~30 MB (4K textures) and GitHub's web upload limit is 25 MB per file — the browser upload will likely fail. Either skip this one, or upload it with GitHub Desktop / git. All other picks fit fine.

## 🔍 Bonus (in range, spotted during research — optional extras)

- De Tomaso P72 2020 (hypercar) — https://sketchfab.com/3d-models/none-ab85c302e652492196b600ee1eb7106a
- 2001 Crown Victoria Taxi — https://sketchfab.com/3d-models/none-2429a825ff1646568e8e6e1453f9c501
- Fairheaven SW '84 (station wagon, traffic) — https://sketchfab.com/3d-models/none-aa0becb6e854422596cac6b21bf79787
- GMC Motorhome (big traffic vehicle) — https://sketchfab.com/3d-models/none-6hiH0iyDqXqtdD9wbqSbyLLhKmz

**Want even more cars?** These two authors have big game-ready garages — browse with the "Downloadable" filter and check the triangle count on each model page (keep it 15k–50k):
- Lexyc16 → https://sketchfab.com/Lexyc16/models
- Daniel Zhabotinsky → https://sketchfab.com/DanielZhabotinsky/models

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

- **CC BY** = free for anything, just credit the author (I'll maintain a CREDITS file in the game).
- **CC BY-NC** (the three Lexyc16 cars) = free for **non-commercial** use with credit. Perfect while the game is free/personal. If you ever plan to monetize the game (ads, paid, etc.), tell me — I'll find CC-BY/CC0 replacements for those three.
- Real car brand names (Nissan, etc.) belong to their companies — another reason to keep the game non-commercial or rebrand cars in-game later.

## 🏪 About Fab.com

Fab also has free vehicle models (https://www.fab.com/search?q=car — tick the **Free** filter), BUT most Fab assets come in Unreal Engine / FBX format, which needs a Blender conversion step before a browser game can use them. Sketchfab's glTF downloads work instantly in our engine — that's why the list above is Sketchfab-first. If you spot a Fab car you love, grab the FBX and I'll guide you through converting it.
