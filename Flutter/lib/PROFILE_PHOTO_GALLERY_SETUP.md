# Foto Profil dari Galeri

Fitur ini menambahkan pemilih foto profil dari galeri HP pada halaman Profil. Foto disimpan sebagai path lokal di SharedPreferences agar tetap tampil setelah aplikasi dibuka kembali selama file foto masih ada di perangkat.

## Dependency
Jalankan dari root project Flutter:

```powershell
flutter pub add image_picker
flutter pub add shared_preferences
```

Tidak perlu menambahkan permission storage manual untuk Android modern karena image_picker menggunakan Android Photo Picker saat tersedia.

Cara pakai: buka Profil -> ketuk foto/inisial -> Pilih dari galeri.
