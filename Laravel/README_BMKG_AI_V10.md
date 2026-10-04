FloodGuard Backend BMKG AI V10

Changes:
- BMKG is the primary/only weather source in the AI backend.
- Open-Meteo is removed from the AI weather path.
- BMKG forecast uses official API with adm4.
- Current build recognizes Jatimakmur -> 32.75.08.1003 as a temporary location alias.
- Gemini 3.7 is removed because it timed out in the user's Laravel log.
- Gemini tries 3.8 Flash, then 3.6 Flash.
- Each Gemini attempt has a 7-second timeout.
- Gemini failure does NOT return HTTP 500; backend returns a BMKG-only fallback response.
- BMKG nowcast, earthquake, and Anak Krakatau ash image remain available.
- No Gemini API key is included.

Important:
For full Indonesia village-level BMKG coverage, pass `bmkg_adm4` in the POST payload or add a proper GPS -> BMKG adm4 resolver. The official BMKG forecast API requires an adm4 code.
