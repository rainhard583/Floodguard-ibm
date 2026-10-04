# FloodGuard Weather Fix 3

Perbaikan utama:

- WeatherAPI tetap menjadi sumber utama current weather.
- Suhu udara aktual (`temp_c`) TIDAK diganti/ditambah manual agar sama dengan aplikasi cuaca HP.
- `feelslike_c` ditampilkan terpisah sebagai "Terasa ...°C" bila berbeda cukup jauh.
- Jika kondisi `Clear` terjadi pada malam hari, UI menampilkan "Cerah malam" dan ikon bulan.
- Forecast WeatherAPI sekarang membawa `precip_mm` supaya indikator Risiko Banjir memakai data presipitasi dari respons yang sama.
- Home Risiko Banjir tidak lagi melakukan request WeatherAPI kedua. Provider memakai data `weatherProvider` yang sama, sehingga mengurangi timeout/gagal ganda.
- Error card Risiko Banjir diperbesar agar tidak terjadi `RenderFlex overflowed by 46 pixels`.

## Penting tentang angka 29°C di aplikasi cuaca HP

Aplikasi cuaca HP dapat memakai provider/model/stasiun yang berbeda dari WeatherAPI. Karena itu FloodGuard tidak boleh memaksa 27 menjadi 29 dengan +2°C atau angka hard-code. Jika WeatherAPI melaporkan suhu udara 27°C tetapi suhu terasa 29°C, UI akan menampilkan keduanya secara jelas.

Untuk mendapatkan angka yang persis sama dengan aplikasi cuaca HP, FloodGuard harus memakai provider yang sama dengan aplikasi tersebut; provider internal Xiaomi tidak dipakai sebagai API publik di project ini.
