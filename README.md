# Anime Tracker

Aplikasi pemantau rilis anime terbaru dengan **update realtime**. Terdiri dari:

- **Backend (Go)** — proxy ke GraphQL API AniList, penyimpanan lokal (bbolt), dan stream update realtime via SSE (Server-Sent Events).
- **App (Flutter)** — UI responsif untuk Android/iOS/desktop dengan notifikasi sistem saat anime yang dilacak mendapat episode atau status baru.

## Fitur

- **Update terkini realtime** — deteksi episode/status baru lewat polling backend + SSE, tampil langsung di app tanpa refresh.
- **Notifikasi sistem Android** — notifikasi muncul saat anime yang kamu lacak mendapat episode baru atau statusnya berubah (channel `tracker_updates`, toggle di Pengaturan).
- **Filter status** — Semua / Tayang (Ongoing) / Selesai (Completed) / Segera (Coming Soon).
- **Filter genre & kategori** — banyak pilihan: genre (Action, Romance, Mecha, dll.) dan kategori/tag (Isekai, Harem, School, Seinen, Shounen, Cyberpunk, dll.), bisa dikombinasikan dengan filter status.
- **Browse musim** — daftar anime musim berjalan.
- **Pencarian + Detail** — cari anime, lihat sinopsis, skor, studio, genre, format, status, dan link resmi AniList.
- **Tracker** — tandai anime untuk dilacak + riwayat aktivitas update realtime.
- **Tema anime** — mode gelap/terang, warna ungu-pink khas anime, ikon bertema anime.
- **Responsif** — aman untuk notch/punch-hole/gesture bar, mendukung tablet & desktop.

## Struktur Proyek

```
.
├── backend/          # Backend Go
│   ├── main.go
│   └── internal/
│       ├── anilist/  # Klien + query GraphQL AniList
│       ├── store/    # Penyimpanan bbolt
│       ├── hub/      # Pub/sub untuk SSE
│       ├── poller/   # Polling deteksi perubahan
│       └── server/   # HTTP handler + SSE
└── app/              # App Flutter
    └── lib/
        ├── main.dart
        └── src/
            ├── api/          # ApiClient + RealtimeService (SSE)
            ├── models/       # Model data
            ├── services/     # NotificationService
            ├── screens/      # Home, Search, Detail, Tracked, Settings
            ├── state/        # AppState (Provider)
            ├── theme/        # Tema anime
            ├── utils/        # Helper responsif
            └── widgets/      # Grid, Card, CoverImage, dll.
```

## Persyaratan

- **Go** 1.25+ (untuk backend)
- **Flutter** (stable) + Android SDK (untuk build app Android)

## Menjalankan Backend

```bash
cd backend
go build -o anime-tracker .
./anime-tracker -addr :8080 -db data/tracker.db -poll 60s
```

Verifikasi:

```bash
curl http://localhost:8080/api/health
```

### Flag backend

| Flag | Default | Keterangan |
|------|---------|------------|
| `-addr` | `:8080` | Alamat HTTP yang didengarkan |
| `-db` | `data/tracker.db` | Lokasi file database |
| `-poll` | `5m` | Interval polling ke AniList |
| `-adult` | `false` | Sertakan konten dewasa di feed (default **off**) |
| `-season-offset` | `0` | Offset musim untuk browse (`-1..1`) |

### Endpoint API

| Endpoint | Keterangan |
|----------|------------|
| `GET /api/health` | Cek kesehatan server |
| `GET /api/anime?search=&genre=&tag=&status=&sort=&page=&perPage=` | Pencarian + filter |
| `GET /api/anime/{id}` | Detail anime (termasuk status track) |
| `GET /api/season/{offset}?status=&genre=&tag=` | Anime per musim + filter |
| `GET /api/latest?status=&genre=&tag=` | Update terkini per status |
| `GET /api/genres` | Daftar genre yang tersedia |
| `GET /api/tags` | Daftar kategori (tag) yang tersedia |
| `GET /api/tracked` | Daftar anime yang dilacak |
| `POST /api/track` `{"id": ...}` | Lacak anime |
| `DELETE /api/track/{id}` | Berhenti melacak |
| `GET /api/stream` | Stream event realtime (SSE) |
| `GET /api/status` | Status poller & konfigurasi |

## Menjalankan App

```bash
cd app
flutter pub get
flutter run
```

### Menghubungkan ke server

Default URL server di app: `http://192.168.1.101:8080` (ubah di tab **Atur → Server Backend → Tes & Simpan**).

- **Emulator Android**: gunakan `http://10.0.2.2:8080`
- **Perangkat fisik**: gunakan IP LAN laptop/PC yang menjalankan backend, mis. `http://192.168.1.101:8080`
- **Via USB (adb reverse)**:
  ```bash
  adb reverse tcp:8080 tcp:8080
  # lalu set URL server ke http://127.0.0.1:8080
  ```

### Build APK

```bash
cd app
flutter build apk --debug --split-per-abi
# hasil: build/app/outputs/flutter-apk/app-<abi>-debug.apk
flutter install
```

### Test

```bash
cd app && flutter test
cd backend && go vet ./...
```

## Catatan

- Filter genre **hentai/konten dewasa tidak disertakan**; app menampilkan katalog anime normal (`isAdult=false`).
- Notifikasi butuh izin **POST_NOTIFICATIONS** (Android 13+); izin diminta otomatis saat app pertama kali dibuka.
- Data anime bersumber dari [AniList](https://anilist.co) (GraphQL API).
