FloodGuard Flutter BMKG AI V10

Changes:
- AI request no longer waits for or sends Open-Meteo weather data.
- Backend receives GPS coordinates + location name and obtains BMKG data.
- Removed duplicate invalidate call when pressing Tanya AI; changing the question is enough to create a new Riverpod request.
- AI loading text says BMKG.
- Mercator/map configuration is untouched.
- Gemini key is not stored in Flutter.

Replace only these files:
lib/services/ai_analyst_service.dart
lib/providers/ai_analyst_provider.dart
lib/repositories/ai_analyst_repository.dart
lib/screens/detection/detection_screen.dart
