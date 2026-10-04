# FloodGuard AI — BMKG Realtime Mode

AI tidak lagi menggunakan Open-Meteo/CAMS sebagai sumber utama jawaban. Setiap pertanyaan dikirim ke Laravel, dan Laravel mengambil sumber resmi BMKG pada saat request dibuat.

Backend patch menggunakan:
- BMKG Nowcast/CAP: peringatan dini cuaca, pemutakhiran setiap saat.
- BMKG Earthquake Open Data: diperbarui setiap ada kejadian gempa.
- BMKG Citra Sebaran Abu Vulkanik Anak Krakatau: produk satelit resmi; backend dapat mengirim citra terbaru ke Gemini untuk pertanyaan abu/Anak Krakatau.

Tidak adanya peringatan nowcast tidak membuktikan tidak ada hujan. Produk abu vulkanik adalah analisis satelit, bukan sensor permukaan.

Layer Weather/Map lama tidak dihapus; perubahan ini hanya mengubah jalur data yang digunakan AI Analyst.
