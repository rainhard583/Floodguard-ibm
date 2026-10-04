# FloodGuard — AI Analyst Backend

Dokumen ini menjelaskan arsitektur backend AI Analyst FloodGuard yang **aktif digunakan**.

> **Catatan:** Dokumentasi lama merujuk Firebase Cloud Functions + Gemini sebagai AI backend.
> Arsitektur tersebut **sudah tidak digunakan**. Implementasi aktual menggunakan
> Laravel → Langflow → Ollama → IBM Granite, seperti yang dijelaskan di bawah ini.

---

## Arsitektur Aktual

```
Flutter (DetectionScreen)
    │  POST /api/ai/analyze
    │  Header: Authorization: Bearer <Firebase ID Token>
    │  Body: { question, context, latitude, longitude, ... }
    ▼
Laravel (FloodGuard Backend API)
    │  1. Verifikasi Firebase ID Token
    │  2. Ambil data realtime (WeatherAPI, BMKG, dsb.)
    │  3. Bangun konteks lengkap dari data FloodGuard
    │  4. Kirim ke Langflow
    ▼
Langflow (Orkestrasi AI)
    │  Terima prompt + konteks dari Laravel
    │  Susun instruksi ke model
    ▼
Ollama (Runtime Model Lokal)
    │  Jalankan inferensi lokal
    ▼
IBM Granite (Model Bahasa)
    │  Hasilkan jawaban berdasarkan konteks
    ▼
Langflow → Laravel → Flutter
    Respons: { analysis, model, generatedAt, realtime }
```

---

## Peran Tiap Komponen

### Laravel
- Gateway utama antara Flutter dan sistem AI.
- Memvalidasi identitas user via Firebase ID Token.
- Mengambil data realtime (cuaca WeatherAPI, gempa BMKG, dsb.) sebelum dikirim ke Langflow.
- Menjaga agar API key pihak ketiga **tidak pernah masuk ke APK Flutter**.

### Langflow
- Orkestrasi alur AI: menerima konteks dari Laravel, menyusun prompt, meneruskan ke Ollama.
- Memungkinkan perubahan alur/prompt tanpa mengubah kode Laravel atau Flutter.

### Ollama
- Runtime inferensi model AI yang berjalan **secara lokal** di server.
- Menjalankan model IBM Granite yang telah disiapkan.

### IBM Granite
- Model bahasa yang digunakan untuk menjawab pertanyaan pengguna.
- Dijalankan lokal melalui Ollama — **bukan** melalui watsonx.ai atau layanan cloud IBM.
- Menerima konteks data FloodGuard (indeks bahaya, data cuaca, data gempa) dan menghasilkan
  penjelasan dalam bahasa natural.

---

## Prinsip AI Analyst FloodGuard

- **AI tidak memprediksi bencana.** AI hanya menjelaskan data yang diberikan oleh
  Risk Engine FloodGuard dan sumber data resmi (InaRISK/BNPB, BMKG).
- **AI harus membedakan tiga jenis informasi:**
  1. *Data teramati* — fakta dari sensor/observasi (cuaca saat ini, gempa terbaru).
  2. *Analisis risiko kawasan* — indeks bahaya dari peta resmi (InaRISK).
  3. *Rekomendasi* — saran berdasarkan data di atas, bukan tebakan.
- **AI tidak boleh mengarang data.** Jika data tidak tersedia, jawaban harus menyatakan
  ketidaktersediaan itu secara jelas.
- **Peringatan dini resmi tetap dari BMKG/BNPB.** AI Analyst bukan pengganti sistem
  peringatan dini resmi pemerintah.

---

## Konfigurasi URL

Flutter membaca URL backend dari `--dart-define`:

```
--dart-define=FLOODGUARD_API_URL=http://<IP_SERVER>:8000/api
```

Endpoint AI Analyst: `<FLOODGUARD_API_URL>/ai/analyze`

Untuk emulator Android, default: `http://10.0.2.2:8000/api`
Untuk iOS simulator / desktop: `http://127.0.0.1:8000/api`

---

## Autentikasi

Setiap request ke `/api/ai/analyze` harus menyertakan header:

```
Authorization: Bearer <Firebase ID Token>
```

Token diambil otomatis dari `FirebaseAuth.instance.currentUser.getIdToken()`.
Laravel memverifikasi token ini sebelum meneruskan request ke Langflow.
