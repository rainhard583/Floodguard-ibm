# FloodGuard Global Realtime Data Architecture

FloodGuard is **global by coordinates**, not limited to a fixed list of countries.

## Active in this build

| Data | Source | Role | Refresh/cache |
|---|---|---|---|
| Location search | Open-Meteo Geocoding | Resolve Tokyo/Jakarta/New York/etc. to coordinates | 24 h cache |
| Current weather | WeatherAPI (Laravel, required for current Home/AI) | Current temperature/condition/humidity/wind | 2 min cache |
| Weather fallback | Open-Meteo | Global weather + forecast fallback | 2 min cache |
| Earthquakes | USGS | Global earthquake events | 1 min cache |
| Indonesia earthquakes | BMKG | Official Indonesian latest earthquake | 1 min cache |
| Global hazards | GDACS | Earthquake/cyclone/flood/wildfire situational awareness | 6 min cache |
| US alerts | NOAA/NWS | Active alerts for US coordinates | 1 min cache |
| US volcano | USGS Volcano Hazards Program | Regional volcano status for US coordinates | 10 min cache |
| AI | Gemini | Interpretation only; never source of current facts | On demand |

## Why not hard-code 7 countries?

The AI first resolves the location in the user's question. Therefore:

- `suhu Tokyo sekarang` -> Tokyo coordinates -> weather for Tokyo
- `gempa di Tokyo` -> Tokyo coordinates -> USGS earthquakes near Tokyo
- `cuaca New York` -> New York coordinates -> weather for New York + NWS alerts
- `kondisi Jakarta` -> Jakarta coordinates -> WeatherAPI/Open-Meteo + BMKG + USGS + GDACS

The system does not need a separate `if Japan`, `if USA`, etc. for basic global weather/earthquake coverage.

Regional agencies are added when they provide additional authoritative information for that area.

## Realtime means latest available provider data

No public API can guarantee that every hazard variable is a live sensor at every location. For example, USGS's real-time GeoJSON earthquake feeds are updated every minute, while global weather models have their own model update cycles. The app therefore refreshes frequently, but it does not manufacture a newer observation timestamp.

## Secrets

Keep `GEMINI_API_KEY` and `WEATHERAPI_KEY` on Laravel. Do not put them in Flutter `--dart-define` values or the APK.
