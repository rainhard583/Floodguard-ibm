# FloodGuard — WeatherAPI + BMKG + MAGMA/PVMBG

## Sumber data
- WeatherAPI: **sumber utama current weather dan forecast untuk Home dan AI**.
- Open-Meteo: hanya untuk map/grid/model meteorologi, bukan current Home/AI.
- BMKG: nowcast/peringatan dini dan gempa Indonesia.
- MAGMA Indonesia/PVMBG: status gunung api; gerakan tanah tidak diisi bila endpoint resmi publik yang stabil belum tersedia.
- Gemini: hanya interpretasi data, bukan sumber fakta cuaca.

## WeatherAPI key
**Jangan pernah memasukkan WEATHERAPI_KEY ke Flutter atau APK.** Simpan hanya di Laravel `.env`:

```env
WEATHERAPI_KEY=YOUR_WEATHERAPI_KEY
```

Pastikan `config/services.php` mempunyai:

```php
'weatherapi' => [
    'key' => env('WEATHERAPI_KEY'),
],
```

Setelah mengubah `.env`:

```powershell
php artisan optimize:clear
php artisan route:list --path=weather/current
php artisan serve --host=0.0.0.0 --port=8000
```

## Flutter
Flutter hanya membutuhkan URL Laravel:

```powershell
flutter run --dart-define=FLOODGUARD_API_URL=http://192.168.0.2:8000/api
```

## Catatan akurasi
- FloodGuard menampilkan `last_updated` dari WeatherAPI sebagai waktu observasi sumber.
- Polling aplikasi tidak dapat membuat observasi provider menjadi lebih baru dari sumbernya.
- Jika WeatherAPI gagal, FloodGuard tidak lagi diam-diam mengganti current Home/AI dengan Open-Meteo. UI akan menunjukkan bahwa current WeatherAPI belum tersedia.
- Perbedaan kecil dengan aplikasi cuaca HP tetap dapat terjadi karena aplikasi lain bisa menggunakan stasiun/model/provider berbeda.
