# 🎮 One Button Chaos

Endless runner Roblox bertema **kota neon malam hari**. Karakter lari otomatis dan makin cepat. Kamu cuma punya **satu tombol** (Space / klik / tap / tombol A gamepad):

- **Di tanah → LOMPAT**
- **Di udara → DASH** (melesat + melayang, 1x per lompatan, untuk menyeberangi jurang panjang)

## ✨ Isi game

| Bagian | Isi |
|---|---|
| Lintasan | Endless, dibangun terus di depan pemain: lantai kaca gelap, rel neon, garis grid, gerbang neon, gedung kota cyber, grid synthwave di bawah |
| Zona | Warna dunia berganti tiap 800 studs: Neon City → Sunset Drive → Toxic Grid → Void Palace → Overdrive |
| Rintangan | Dinding neon (lompat), pagar laser (lompat), jurang pendek (lompat), jurang panjang (lompat + dash), dinding ganda, dinding + jurang, crusher yang menghantam (timing) |
| Keadilan | Jarak rintangan dihitung dari fisika lompat & dash pada kecepatan saat itu, jadi selalu bisa dilewati. Hitbox sedikit lebih kecil dari visual. Ada coyote time & jump buffer |
| Efek | Trail neon, cahaya karakter, debu lompat, percikan dash, ledakan + serpihan saat crash, partikel angin, kamera FOV melebar saat ngebut, guncangan kamera, flash layar |
| UI | Layar judul animasi, kartu cara main, hitung mundur 3-2-1-GO, skor + bar kecepatan, popup zona & milestone, kartu Game Over (NEW BEST, Main Lagi, Revive), papan peringkat Top 10 |
| Petunjuk | Label "LOMPAT ⬆" / "LOMPAT + DASH ⚡" muncul di awal permainan sebagai tutorial |

## 📂 Struktur

```
src/
├── shared/                    (ReplicatedStorage.Shared)
│   ├── GameConfig.lua          tuning, palet warna, suara, ID monetisasi
│   ├── TrackGenerator.lua      pola rintangan deterministik & adil
│   └── Remotes.lua             RemoteEvent
├── client/                    (StarterPlayerScripts.Client)
│   ├── Main.client.lua         state machine: Menu → Countdown → Lari → Game Over
│   ├── InputController.lua     satu input lintas-platform
│   ├── PlayerRunner.lua        gerak, lompat, dash, deteksi tabrakan
│   ├── TrackStreamer.lua       bangun/hapus lintasan, rintangan, dekorasi
│   ├── Effects.lua             suara, partikel, trail
│   ├── CameraController.lua    kamera sinematik
│   └── HUD.lua                 semua UI
└── server/                    (ServerScriptService.Server)
    ├── Main.server.lua         validasi skor + high score
    ├── Environment.lua         lighting neon, platform start, collision group
    ├── Monetization.lua        Game Pass & Developer Product
    └── GlobalLeaderboard.lua   papan peringkat global
```

## 🚀 Menjalankan

1. Di folder project: `rojo serve` (atau `.\rojo.exe serve` di Windows).
2. Roblox Studio → **New → Baseplate** → Plugins → **Rojo → Connect**.
3. Tekan **Play**.

> Saat server mulai, `Environment.lua` **menghapus Baseplate & SpawnLocation bawaan template** supaya jurang benar-benar bisa bikin jatuh. Ini disengaja.

Kalau sebelumnya sudah sync versi lama, hapus skrip lama yang tersisa di Studio (`TrackBuilder`, `ObstacleGenerator`) bila masih ada.

## 🎛️ Tuning

Semua angka ada di `src/shared/GameConfig.lua`: kecepatan, lompat, dash, panjang zona, warna, suara. Suara memakai file bawaan Roblox (`rbxasset://sounds/...`). Untuk musik, isi `MusicId` dengan ID musik berlisensi dari Creator Store.

## 💰 Monetisasi

Isi ID di `GameConfig.lua` (0 = tombol disembunyikan):

- `GamePassIds.DoubleScore`: skor resmi x2 (dihitung di server)
- `GamePassIds.RainbowTrail`: trail pelangi
- `ProductIds.Revive`: lanjut dari titik crash, 1x per run. Receipt dicatat di DataStore agar tidak diproses dua kali.

## ✅ Checklist publish

- [ ] Game Settings → Security → **Enable Studio Access to API Services** (high score & leaderboard)
- [ ] Tes di emulator HP (Test → Device) — tap harus jalan
- [ ] Ikon & thumbnail menarik (screenshot zona neon + crash)
- [ ] Judul/deskripsi dengan kata kunci: "one button", "hard", "runner", "rage"
- [ ] Isi ID Game Pass / Product kalau mau monetisasi
- [ ] File → Publish to Roblox → set **Public**
