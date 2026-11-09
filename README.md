# One Button Chaos

Endless runner di atas awan. Karakter berlari sendiri di jalan setapak batu yang melayang di langit, makin lama makin cepat. Kamu cuma punya **satu tombol**:

- **Di tanah → lompat**
- **Di udara → dash** (melesat dan melayang sebentar, 1x per lompatan, untuk menyeberangi jurang panjang)

## Isi game

| Bagian | Isi |
|---|---|
| Dunia | Jalan batu krem dengan pagar tali kayu dan lentera, lautan awan di bawah, awan dinamis Roblox, pulau melayang dengan pohon, balon udara |
| Waktu langit | Berganti tiap 800 m: Fajar → Langit Cerah → Jam Emas → Senja → Cahaya Bintang, transisi halus |
| Rintangan | Peti kayu (lompat), pagar tanaman (lompat), jurang bertanda bendera (lompat, yang panjang lompat + dash), balok batu yang turun-naik (timing) |
| Keadilan | Jarak rintangan dihitung dari fisika lompat & dash pada kecepatan saat itu. Hitbox sedikit lebih kecil dari visual. Ada coyote time & jump buffer |
| Avatar | **R6 only**. Baju, warna kulit, dan aksesori pemain tetap dipakai. Animasi lari ikut kecepatan |
| Bahasa | Otomatis ikut setting bahasa Roblox pemain. 15 bahasa: en, id, es, pt, fr, de, it, ru, tr, ja, ko, zh-cn, zh-tw, th, vi. Bahasa lain → Inggris |
| Perangkat | PC (Spasi/W/Panah Atas/klik), HP & tablet (ketuk di mana saja), gamepad Xbox/PlayStation (A atau R2). Petunjuk di layar ikut perangkat yang sedang dipakai |
| UI | Menu, cara main, hitung mundur, skor + bar kecepatan, popup zona & milestone, kartu game over, papan peringkat Top 10, tombol suara |

## Struktur

```
src/
├── shared/                    (ReplicatedStorage.Shared)
│   ├── GameConfig.lua          tuning, warna, zona langit, suara, ID monetisasi
│   ├── Locale.lua              teks 15 bahasa + deteksi bahasa
│   ├── TrackGenerator.lua      pola rintangan deterministik & adil
│   └── Remotes.lua             RemoteEvent
├── client/                    (StarterPlayerScripts.Client)
│   ├── Main.client.lua         alur game: Menu → Countdown → Lari → Game Over
│   ├── InputController.lua     satu tombol untuk semua perangkat + deteksi perangkat
│   ├── PlayerRunner.lua        gerak, lompat, dash, tabrakan
│   ├── RunnerAnimator.lua      animasi R6
│   ├── TrackStreamer.lua       jalan, rintangan, dekorasi langit
│   ├── Effects.lua             suara & partikel
│   ├── CameraController.lua    kamera
│   └── HUD.lua                 semua UI
└── server/                    (ServerScriptService.Server)
    ├── Main.server.lua         validasi skor + high score
    ├── Environment.lua         langit, cahaya, pulau start
    ├── Characters.lua          spawn karakter R6
    ├── Monetization.lua        Game Pass & Developer Product
    └── GlobalLeaderboard.lua   papan peringkat global
```

## Menjalankan

1. Di folder project: `git pull`, lalu `.\rojo.exe serve` (Windows) atau `rojo serve`.
2. Roblox Studio → **New → Baseplate** → Plugins → **Rojo → Connect**.
3. Tekan **Play**.

Catatan:
- Saat server mulai, Baseplate & SpawnLocation bawaan template **dihapus otomatis** supaya jurang benar-benar bisa bikin jatuh.
- Kalau masih memakai place lama, hapus skrip yang sudah tidak ada di daftar di atas (mis. `TrackBuilder`, `ObstacleGenerator`).
- R6 sudah dipaksa lewat script. Supaya konsisten di halaman game juga, set **Game Settings → Avatar → Avatar Type: R6**.

## Tes bahasa & perangkat di Studio

- **Bahasa:** isi `Locale.ForceLanguage = "ja"` (atau kode lain) di `src/shared/Locale.lua`, tekan Play, lalu kembalikan ke `nil`. Bisa juga lewat tab **Test → Player Emulator → Locale**.
- **HP/tablet:** tab **Test → Device**, pilih HP. Ketuk layar untuk mulai.
- **Gamepad:** colok gamepad, tekan A.

## Tuning

Semua angka ada di `src/shared/GameConfig.lua`: kecepatan, lompat, dash, panjang zona, warna, waktu langit, suara. Suara memakai file bawaan Roblox. Untuk musik, isi `MusicId` dengan ID musik berlisensi dari Creator Store.

## Monetisasi

Isi ID di `GameConfig.lua` (0 = tombol disembunyikan):

- `GamePassIds.DoubleScore`: skor resmi x2 (dihitung di server)
- `GamePassIds.RainbowTrail`: jejak pelangi pastel
- `ProductIds.Revive`: lanjut dari titik jatuh, 1x per run. Receipt dicatat di DataStore agar tidak diproses dua kali.

## Checklist publish

- [ ] Game Settings → Security → **Enable Studio Access to API Services**
- [ ] Game Settings → Avatar → **R6**
- [ ] Tes di emulator HP & dengan gamepad
- [ ] Ikon & thumbnail (screenshot jalan di atas awan saat Jam Emas)
- [ ] Judul & deskripsi (bisa ditulis dalam beberapa bahasa di Creator Hub → Localization)
- [ ] Isi ID Game Pass / Product kalau mau monetisasi
- [ ] File → Publish to Roblox → set **Public**
