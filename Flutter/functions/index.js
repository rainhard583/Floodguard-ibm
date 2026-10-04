const { onRequest } = require('firebase-functions/v2/https');
const { setGlobalOptions } = require('firebase-functions/v2');
const { defineSecret } = require('firebase-functions/params');
const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { GoogleGenAI } = require('@google/genai');

initializeApp();
setGlobalOptions({ region: 'asia-southeast2', maxInstances: 5 });

const geminiApiKey = defineSecret('GEMINI_API_KEY');

const SYSTEM_INSTRUCTION = `
Kamu adalah AI Analyst FloodGuard untuk menjelaskan risiko lokasi di Indonesia.

ATURAN KERAS:
1. Angka indeks dan level bahaya berasal dari data FloodGuard yang diberikan di input. Jangan mengubah, menaikkan, menurunkan, atau mengarang angka.
2. Jika data sebuah bahaya adalah DATA TIDAK TERSEDIA, katakan data tersebut tidak tersedia. Jangan menebak.
3. Jangan memprediksi kapan gempa, tsunami, banjir, longsor, atau erupsi akan terjadi.
4. Gempa BMKG/USGS adalah kejadian yang sudah tercatat, bukan prediksi.
5. Peta bahaya InaRISK adalah indeks bahaya kawasan, bukan peringatan dini real-time.
6. Cuaca Open-Meteo adalah model cuaca, bukan sensor lapangan.
7. Untuk peringatan resmi, arahkan pengguna ke BMKG, BNPB, atau Badan Geologi/PVMBG sesuai jenis bencana.
8. Jika pertanyaan meminta fakta yang tidak ada di konteks, katakan bahwa konteks saat ini tidak cukup.
9. Jangan mengarang koordinat, wilayah, magnitudo, status gunung api, atau waktu kejadian.
10. Jawaban harus singkat, jelas, dalam Bahasa Indonesia, dan berbasis konteks lokasi.
`;

exports.analyzeFloodGuardLocation = onRequest(
  { secrets: [geminiApiKey], timeoutSeconds: 60, memory: '256MiB' },
  async (req, res) => {
    if (req.method === 'OPTIONS') {
      res.set('Access-Control-Allow-Origin', '*');
      res.set('Access-Control-Allow-Headers', 'Authorization, Content-Type');
      res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
      return res.status(204).send('');
    }

    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Headers', 'Authorization, Content-Type');

    if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

    try {
      const authHeader = req.get('Authorization') || '';
      if (!authHeader.startsWith('Bearer ')) {
        return res.status(401).json({ error: 'Token login diperlukan.' });
      }
      await getAuth().verifyIdToken(authHeader.substring(7));

      const body = req.body || {};
      const location = body.location;
      const analysis = body.analysis;
      const question = typeof body.question === 'string' ? body.question.trim() : '';

      if (!location || !analysis || !Array.isArray(analysis.hazards)) {
        return res.status(400).json({ error: 'Konteks analisis lokasi tidak lengkap.' });
      }

      const prompt = [
        'KONTEKS FLOODGUARD (gunakan hanya data ini):',
        JSON.stringify({ location, analysis }, null, 2),
        '',
        question
          ? `PERTANYAAN PENGGUNA: ${question}`
          : 'TUGAS: Jelaskan kondisi bahaya lokasi ini, bahaya yang datanya tersedia, faktor pendukung yang terlihat, keterbatasan, dan langkah kesiapsiagaan umum yang relevan. Jangan membuat prediksi kejadian.',
      ].join('\n');

      const ai = new GoogleGenAI({ apiKey: geminiApiKey.value() });
      const response = await ai.models.generateContent({
        model: 'gemini-3.6-flash',
        contents: prompt,
        config: {
          systemInstruction: SYSTEM_INSTRUCTION,
          temperature: 0.2,
          maxOutputTokens: 700,
        },
      });

      const answer = (response.text || '').trim();
      if (!answer) return res.status(502).json({ error: 'AI tidak mengembalikan jawaban.' });

      return res.status(200).json({
        answer,
        model: 'Gemini 3.6 Flash',
        generatedAt: new Date().toISOString(),
      });
    } catch (error) {
      console.error('[FloodGuard AI]', error);
      return res.status(500).json({ error: 'Layanan AI sementara tidak tersedia.' });
    }
  },
);
