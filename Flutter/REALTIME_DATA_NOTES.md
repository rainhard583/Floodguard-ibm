# FloodGuard realtime data notes

- BMKG Data Gempabumi Terbuka: event feed Indonesia, updated whenever an earthquake event is published.
- BMKG tsunami-potential feed: current/most recent events whose `Potensi` contains tsunami potential.
- Open-Meteo: current weather model data at the selected coordinate.
- InaRISK/BNPB: official hazard-index raster. This is NOT an event-by-event realtime warning feed. It is queried live from the official ArcGIS service at analysis time, but the underlying hazard map has its own publication/version cycle.
- Volcano status: do not invent current PVMBG/MAGMA status when a machine-readable official endpoint is not available. The InaRISK volcano hazard index may still be available.
