# FloodGuard AI — BMKG + Global + Data Bencana

Flutter client untuk backend FloodGuard AI yang menggunakan
**IBM Granite via Ollama + Langflow**.

---

## Stack AI Aktual

```
Flutter → Laravel /api/ai/analyze → Langflow → Ollama → IBM Granite
```

- **IBM Granite** dijalankan secara lokal melalui **Ollama** (bukan layanan cloud).
- **Langflow** mengatur orkestrasi prompt dan alur data ke model.
- **Laravel** memvalidasi identitas user (Firebase JWT), mengambil data realtime,
  lalu meneruskan konteks ke Langflow.
- **Tidak menggunakan** Gemini, OpenAI, atau provider AI cloud lain.

---

## Jenis Pertanyaan yang Didukung

AI Analyst menjawab berdasarkan konteks data FloodGuard yang dikirim Laravel:

- Cuaca saat ini: suhu, hujan, kelembapan, angin, tekanan, UV, visibilitas
- Prakiraan beberapa jam ke depan
- Banjir: indeks bahaya kawasan, curah hujan pemicu, potensi genangan
- Gempa terbaru: Indonesia (BMKG) maupun global (USGS)
- Tsunami: indeks bahaya kawasan + feed BMKG berpotensi tsunami
- Bahaya lain: longsor, gunung api, cuaca ekstrem (indeks InaRISK/BNPB)

---

## Prinsip AI Analyst

- AI **tidak memprediksi bencana** — AI menjelaskan data yang sudah ada.
- AI membedakan antara *data teramati*, *analisis risiko kawasan*, dan *rekomendasi*.
- AI tidak boleh mengarang data; jika data tidak tersedia, jawaban harus menyatakan itu.
- Peringatan dini resmi tetap dari **BMKG/BNPB** — AI Analyst bukan penggantinya.

---

## Fitur Peta Cuaca

Mercator weather map tetap dipertahankan dan menggunakan **Open-Meteo** secara langsung
(tanpa Laravel) untuk overlay grid — ini terpisah dari alur AI Analyst.
