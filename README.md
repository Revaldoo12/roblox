# 🎮 One Button Chaos

Game Roblox endless-runner dengan **satu tombol untuk semua aksi**. Karakter lari otomatis, semakin cepat seiring waktu. Satu tombol (Space / klik / tap / tombol A gamepad) melakukan aksi berbeda tergantung situasi:

- **Di tanah →** Lompat
- **Di udara →** Dash (dorongan ke depan)

Simpel dipahami, susah dikuasai — resep klasik game viral yang enak di-clip untuk TikTok/Shorts.

---

## 📂 Struktur Project

```
OneButtonChaos/
├── default.project.json        # Konfigurasi Rojo (sync ke Studio)
├── src/
│   ├── shared/                 # ReplicatedStorage (dipakai client & server)
│   │   ├── GameConfig.lua       # SEMUA tuning/balancing ada di sini
│   │   ├── Remotes.lua          # Manajemen RemoteEvent
│   │   └── ObstacleGenerator.lua# Pola rintangan deterministik (seed)
│   ├── client/                 # StarterPlayerScripts
│   │   ├── Main.client.lua      # Game loop utama (perekat semua modul)
│   │   ├── InputController.lua  # INTI: satu input lintas-platform
│   │   ├── PlayerRunner.lua     # Gerak otomatis + aksi context-sensitive
│   │   └── HUD.lua              # Skor & UI (dibuat via kode, no manual UI)
│   └── server/
│       ├── Main.server.lua      # Perekat server: validasi skor + rangkai sistem
│       ├── TrackBuilder.lua     # Bangun SELURUH map via kode (no manual build!)
│       ├── Monetization.lua     # Game Pass & Developer Products
│       └── GlobalLeaderboard.lua# Papan skor global top-100 (OrderedDataStore)
└── README.md
```

---

## 🚀 Cara Menjalankan (via Rojo)

[Rojo](https://rojo.space/) adalah tool standar untuk menyinkronkan kode dari folder ini ke Roblox Studio.

1. **Install Rojo** (butuh [Aftman](https://github.com/LPGhatguy/aftman) atau unduh biner Rojo):
   ```bash
   aftman add rojo-rbx/rojo
   ```
2. **Install plugin Rojo** di Roblox Studio (dari Toolbox atau `rojo plugin install`).
3. Dari folder project ini, jalankan:
   ```bash
   rojo serve
   ```
4. Di Studio, buka panel **Rojo** → **Connect**. Semua skrip akan muncul di tempatnya.

> Tidak mau pakai Rojo? Kamu bisa salin isi tiap file `.lua` ke Script/ModuleScript yang sesuai di Studio secara manual (lihat lokasi di `default.project.json`).

---

## 🗺️ Map Dibangun Otomatis (tidak perlu susun manual!)

`TrackBuilder.lua` membangun **seluruh map lewat kode** saat server start:
lantai lintasan, garis tengah neon, SpawnLocation, zona mati, dan semua
rintangan (Low = dilompati, High = di-dash). Begitu kamu Connect Rojo dan tekan
Play, game langsung bisa dimainkan.

Mau ubah tampilan/panjang/kepadatan? Edit konstanta di atas `TrackBuilder.Build`
(`TRACK_LENGTH`, dll) dan tuning di `src/shared/GameConfig.lua`.

> **Endless sejati:** untuk prototipe & publish awal, lintasan panjang 4000 studs
> sudah cukup. Untuk endless tak terbatas, ubah TrackBuilder agar men-stream
> "chunk" baru di depan pemain dan menghapus yang di belakang.

## 💰 Monetisasi

`Monetization.lua` sudah menyiapkan kerangka:
- **Game Pass "Double Score"** — skor x2 (digandakan di SERVER = aman dari cheat).
- **Dev Product "Revive"** — hidup lagi 1x tanpa reset skor.
- **Dev Product "Skin Neon"** — trail warna-warni (clippable!).

Cara aktifkan: buat item di Creator Hub, lalu salin ID-nya ke tabel
`GamePasses` / `Products` di `Monetization.lua` (ganti angka `0`).

> ⚠️ **Produksi:** `ProcessReceipt` sebaiknya menyimpan receipt ke DataStore agar
> pembelian consumable tidak diproses dua kali saat server restart (ada TODO di kode).

## 🏆 Leaderboard Global

`GlobalLeaderboard.lua` menyimpan skor tertinggi antar SEMUA pemain via
OrderedDataStore dan menampilkan **Top 10** di panel kiri atas (dibuat otomatis
oleh `HUD.lua`). Refresh tiap 60 detik. Butuh **API Services aktif**.

---

## ✅ Checklist Siap Publish ke Roblox

- [ ] **Game bisa dimainkan** full loop: start → main → game over → ulangi.
- [ ] **Aktifkan API Services** (Game Settings → Security) agar DataStore high score jalan.
- [ ] **Uji di mobile** (emulator Studio) — pastikan tap bekerja.
- [ ] **Thumbnail & ikon** menarik (ini SANGAT menentukan klik di Roblox).
- [ ] **Judul & deskripsi** dengan kata kunci ("one button", "hard", "rage").
- [ ] **Genre** di Game Settings diisi.
- [ ] **Patuhi [Community Standards](https://en.help.roblox.com/hc/en-us/articles/203313410) Roblox.**
- [ ] (Opsional) **Monetisasi:** Game Passes / Developer Products untuk skin, revive, atau 2x score. Payout lewat **DevEx** (butuh umur & syarat tertentu).
- [ ] **Publish:** File → Publish to Roblox → set ke **Public** saat siap.

---

## 💡 Ide Pengembangan (bikin makin beda & viral)

- **Skin karakter** yang kelihatan jelas di clip pendek.
- **Daily challenge** dengan seed harian (pakai `ObstacleGenerator` + seed = tanggal) → semua pemain dapat pola sama, bisa adu skor.
- **Ghost race:** tampilkan "bayangan" skor terbaikmu.
- **Trail efek** warna-warni saat dash untuk visual yang clippable.
- **Haptics/sound** yang memuaskan tiap aksi — kunci rasa "nagih".
