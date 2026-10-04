# FloodGuard Open-Meteo Map Fix

Perubahan utama:
- Weather Map tidak lagi bergantung pada `MERCATOR_API_KEY`.
- Layer cuaca dan lingkungan dirender langsung di FlutterMap sebagai grid
  nilai nyata dari Open-Meteo.
- Cuaca: angin, gust, hujan, suhu, titik embun, kelembapan, tekanan, awan,
  visibility, UV.
- Lingkungan/CAMS: AQI, PM2.5, PM10, SO2, NO2, CO, O3.
- Pemeriksaan titik pada kartu peta menggunakan Open-Meteo langsung.
- Layer grid memakai debounce saat pan/zoom agar tidak melakukan request
  setiap frame.
- Air quality memakai `domains=cams_global` agar cakupan global konsisten.
- `MERCATOR_API_KEY` tidak diperlukan untuk fitur cuaca/lingkungan ini.

Sumber:
- Open-Meteo Weather Forecast API: https://api.open-meteo.com/v1/forecast
- Open-Meteo Air Quality API: https://air-quality-api.open-meteo.com/v1/air-quality

Catatan:
- Open-Meteo/CAMS adalah data model/forecast, bukan sensor lokal.
- Radar/satelit tetap belum diaktifkan karena membutuhkan sumber/tile API
  khusus; jangan menampilkan data palsu untuk layer tersebut.
