<?php


namespace App\Http\Controllers;


use Illuminate\Http\Request;

use Illuminate\Support\Facades\Cache;

use Illuminate\Support\Facades\Http;

use Illuminate\Support\Str;

use Throwable;


/**

 * FloodGuard Global Realtime AI Controller

 *

 * Important:

 * - The AI layer NEVER invents current weather/earthquake values.

 * - Location in the user's question is resolved globally with Open-Meteo geocoding.

 * - WeatherAPI is preferred for current conditions when WEATHER_API_KEY exists.

 * - Open-Meteo is the global fallback.

 * - USGS is the global earthquake feed; BMKG is added for Indonesian locations.

 * - GDACS adds global multi-hazard situational awareness.

 * - NWS active alerts are added for US locations.

 * - Short caches prevent hammering public APIs while keeping data fresh.

 */

class AiAnalystController extends Controller

{

    private const WEATHER_CACHE_SECONDS = 300;      // 5 min

    private const EARTHQUAKE_CACHE_SECONDS = 60;    // 1 min

    private const GDACS_CACHE_SECONDS = 360;        // 6 min

    private const GEOCODE_CACHE_SECONDS = 86400;    // 24 h (coordinates don't change)


    public function ping()

    {

        return response()->json([

            'success' => true,

            'service' => 'FloodGuard AI backend',

            'server_time' => now()->toIso8601String(),

        ]);

    }


    public function weatherTest(Request $request)

    {

        $lat = is_numeric($request->input('latitude')) ? (float) $request->input('latitude') : null;

        $lon = is_numeric($request->input('longitude')) ? (float) $request->input('longitude') : null;


        if ($lat === null || $lon === null || $lat < -90 || $lat > 90 || $lon < -180 || $lon > 180) {

            return response()->json(['success' => false, 'error' => 'Latitude/longitude tidak valid.'], 422);

        }


        $configured = trim((string) (config('services.weatherapi.key') ?: env('WEATHER_API_KEY', ''))) !== '';

        $weatherApi = $this->weatherApiCurrent($lat, $lon);

        if ($weatherApi !== null) {

            return response()->json([

                'success' => true,

                'provider' => 'WeatherAPI',

                'weather' => $weatherApi['current'],

                'updated_at' => $weatherApi['updated_at'] ?? null,

                'fallback_used' => false,

                'requested_coordinates' => ['latitude' => $lat, 'longitude' => $lon],

            ]);

        }


        return response()->json([

            'success' => false,

            'provider' => 'WeatherAPI',

            'error' => $configured

                ? 'WeatherAPI gagal mengembalikan current weather untuk koordinat ini.'

                : 'WEATHER_API_KEY belum dikonfigurasi di Laravel .env.',

            'weatherapi_configured' => $configured,

            'requested_coordinates' => ['latitude' => $lat, 'longitude' => $lon],

        ], 503);

    }


    public function floodRisk(Request $request)

    {

        $lat = is_numeric($request->input('latitude')) ? (float) $request->input('latitude') : null;

        $lon = is_numeric($request->input('longitude')) ? (float) $request->input('longitude') : null;


        if ($lat === null || $lon === null || $lat < -90 || $lat > 90 || $lon < -180 || $lon > 180) {

            return response()->json([

                'success' => false,

                'error' => 'Latitude/longitude tidak valid.',

            ], 422);

        }


        return response()->json([

            'success' => true,

            'result' => $this->floodRiskAtPoint($lat, $lon),

            'latitude' => $lat,

            'longitude' => $lon,

            'checked_at' => now()->toIso8601String(),

        ]);

    }


    public function analyze(Request $request)

    {

        $message = trim((string) $request->input('message', ''));

        $clientLat = is_numeric($request->input('latitude')) ? (float) $request->input('latitude') : null;

        $clientLon = is_numeric($request->input('longitude')) ? (float) $request->input('longitude') : null;

        $clientLocationName = trim((string) $request->input('location_name', '')) ?: null;


        if ($message === '') {

            return response()->json(['success' => false, 'error' => 'Pesan analisis kosong.'], 422);

        }


        try {

            $target = $this->resolveTargetLocation($message, $clientLat, $clientLon, $clientLocationName);

            $data = $this->collectRealtimeData($target, $message);

        } catch (Throwable $e) {

            report($e);

            return response()->json([

                'success' => true,

                'analysis' => 'Data lokasi/bencana belum berhasil diambil. Coba lagi beberapa saat kemudian. Data tidak dikarang.',

                'model' => 'FloodGuard factual fallback',

                'generatedAt' => now()->toIso8601String(),

                'target' => [

                    'name' => $clientLocationName ?: 'Lokasi perangkat',

                    'latitude' => $clientLat,

                    'longitude' => $clientLon,

                    'resolution' => 'device',

                ],

                'sources' => [],

                'realtime' => [],

            ]);

        }


        // Penting untuk ketahanan: data realtime dikumpulkan SATU KALI.

        // Jika Langflow gagal/timeout, jangan memanggil semua provider kedua kali.

        try {

            $prompt = $this->buildPrompt($message, $target, $data);

            [$answer, $model] = $this->generateLangflow($prompt);


            return response()->json([

                'success' => true,

                'analysis' => trim($answer),

                'model' => $model,

                'generatedAt' => now()->toIso8601String(),

                'target' => $target,

                'sources' => $data['sources'],

                'realtime' => $data,

            ]);

        } catch (Throwable $e) {

            report($e);


            return response()->json([

                'success' => true,

                'analysis' => $this->fallbackAnswer($message, $target, $data),

                'model' => 'FloodGuard factual fallback',

                'generatedAt' => now()->toIso8601String(),

                'target' => $target,

                'sources' => $data['sources'],

                'realtime' => $data,

            ]);

        }

    }


    private function resolveTargetLocation(

        string $message,

        ?float $clientLat,

        ?float $clientLon,

        ?string $clientLocationName

    ): array {

        $query = $this->extractLocationQuery($message);


        if ($query !== null) {

            $cacheKey = 'floodguard:global:geocode:' . sha1(mb_strtolower($query));

            $resolved = Cache::remember($cacheKey, now()->addSeconds(self::GEOCODE_CACHE_SECONDS), function () use ($query) {

                try {

                    $response = Http::timeout(8)->connectTimeout(3)->get(

                        'https://geocoding-api.open-meteo.com/v1/search',

                        [

                            'name' => $query,

                            'count' => 5,

                            'language' => 'en',

                            'format' => 'json',

                        ]

                    );


                    if (!$response->successful()) return null;

                    $rows = $response->json('results', []);

                    if (!is_array($rows) || empty($rows)) return null;


                    $row = $rows[0];

                    if (!is_array($row) || !isset($row['latitude'], $row['longitude'])) return null;


                    return [

                        'name' => $row['name'] ?? $query,

                        'country' => $row['country'] ?? null,

                        'country_code' => isset($row['country_code']) ? strtoupper((string) $row['country_code']) : null,

                        'admin1' => $row['admin1'] ?? null,

                        'latitude' => (float) $row['latitude'],

                        'longitude' => (float) $row['longitude'],

                        'timezone' => $row['timezone'] ?? null,

                        'resolution' => 'question',

                    ];

                } catch (Throwable $e) {

                    report($e);

                    return null;

                }

            });


            if (is_array($resolved)) return $resolved;

        }


        if ($clientLat !== null && $clientLon !== null) {

            return [

                'name' => $clientLocationName ?: 'Lokasi perangkat',

                'country' => null,

                'country_code' => null,

                'admin1' => null,

                'latitude' => $clientLat,

                'longitude' => $clientLon,

                'timezone' => null,

                'resolution' => 'device',

            ];

        }


        return [

            'name' => 'Global',

            'country' => null,

            'country_code' => null,

            'admin1' => null,

            'latitude' => null,

            'longitude' => null,

            'timezone' => null,

            'resolution' => 'none',

        ];

    }


    /**

     * Turns natural language into a geocoding query without hard-coding a country list.

     * Examples:

     * "berapa suhu Tokyo sekarang" -> Tokyo

     * "gempa di Tokyo saat ini" -> Tokyo

     * "cuaca New York besok" -> New York

     */

    private function extractLocationQuery(string $message): ?string

    {

        $text = trim(preg_replace('/\s+/u', ' ', $message));

        if ($text === '') return null;


        // Prefer the text after a location preposition.

        if (preg_match('/\b(?:di|ke|sekitar|wilayah|kota|area)\s+([^?!.]+)/iu', $text, $m)) {

            $candidate = trim($m[1]);

            $candidate = preg_split('/\b(?:sekarang|saat ini|hari ini|besok|nanti|malam ini|pagi ini|siang ini|sore ini|berapa|ada|terjadi|apakah|dan|juga)\b/iu', $candidate)[0] ?? $candidate;

            $candidate = trim($candidate, " ,.-:;\t\n\r\0\x0B");

            if ($candidate !== '') return $candidate;

        }


        // Otherwise remove common question words and leave the probable place name.

        $candidate = mb_strtolower($text);

        $stopWords = [

            'berapa','suhu','temperatur','temperature','cuaca','weather','kondisi','kondisinya',

            'sekarang','saat','ini','hari','today','besok','tomorrow','nanti','malam','pagi','siang','sore',

            'ada','apakah','terjadi','gempa','earthquake','skala','magnitudo','magnitude','hujan','hujannya',

            'angin','kelembapan','humidity','banjir','flood','risiko','risk','di','ke','dan','atau','untuk',

            'tolong','cek','coba','dong','ya','gak','nggak','tidak','bagaimana','gimana','berapa','yang',

            'wilayah','lokasi','kota','area','saat','saja','terdekat','terbaru','terkini','real','realtime','real-time',

        ];

        foreach ($stopWords as $word) {

            $candidate = preg_replace('/\b' . preg_quote($word, '/') . '\b/iu', ' ', $candidate);

        }

        $candidate = trim(preg_replace('/\s+/u', ' ', $candidate));

        $candidate = trim($candidate, " ,.-:;?!");


        if ($candidate === '' || mb_strlen($candidate) < 2) return null;

        if (preg_match('/^[0-9.,\\- ]+$/', $candidate)) return null;

        return $candidate;

    }


    private function collectRealtimeData(array $target, string $message = ''): array

    {

        $lat = $target['latitude'] ?? null;

        $lon = $target['longitude'] ?? null;

        $intent = $this->detectWeatherIntent($message);


        $data = [

            'collected_at' => now()->toIso8601String(),

            'target' => $target,

            'intent' => $intent,

            'current_weather' => null,

            'forecast' => [],

            'historical_weather' => [],

            'rain_history' => [],

            'earthquakes' => [],

            'regional_earthquake' => null,

            'gdacs_events' => [],

            'official_alerts' => [],

            'volcano' => [],

            'flood_risk' => null,

            'sources' => [],

        ];


        if ($lat === null || $lon === null) {

            $data['earthquakes'] = $this->usgsGlobal();

            if (!empty($data['earthquakes'])) $data['sources'][] = 'USGS Earthquake Catalog';

            $data['gdacs_events'] = $this->gdacsNearby(null, null);

            if (!empty($data['gdacs_events'])) $data['sources'][] = 'GDACS';

            $data['sources'][] = 'Langflow + IBM Granite — interpretation only';

            return $data;

        }


        // IMPORTANT: weather questions must not wait for BNPB, GDACS, earthquakes,

        // volcanoes, etc. This keeps "berapa suhu sekarang?" fast and reliable.

        if ($intent === 'current_weather') {

            [$weather, $provider] = $this->getCurrentWeatherWithFallback($lat, $lon);

            if ($weather !== null) {

                $data['current_weather'] = $weather['current'];

                $data['forecast'] = $weather['forecast'] ?? [];

                $data['historical_weather'] = $weather['history'] ?? [];

                $data['rain_history'] = $this->extractRainHistory($data['historical_weather']);

                $data['sources'][] = $provider;

            }

            $data['sources'][] = 'Langflow + IBM Granite — interpretation only';

            return $data;

        }


        if ($intent === 'historical_weather') {

            [$weather, $provider] = $this->getHistoricalWeatherWithFallback($lat, $lon);

            if ($weather !== null) {

                $data['current_weather'] = $weather['current'] ?? null;

                $data['forecast'] = $weather['forecast'] ?? [];

                $data['historical_weather'] = $weather['history'] ?? [];

                $data['rain_history'] = $this->extractRainHistory($data['historical_weather']);

                $data['sources'][] = $provider;

            }

            $data['sources'][] = 'Langflow + IBM Granite — interpretation only';

            return $data;

        }


        if ($intent === 'flood_risk') {

            $data['flood_risk'] = $this->floodRiskAtPoint($lat, $lon);

            if (is_array($data['flood_risk']) && !empty($data['flood_risk']['available'])) {

                $data['sources'][] = 'BNPB InaRISK — Peta Bahaya/Risiko Banjir';

            }

            $data['sources'][] = 'Langflow + IBM Granite — interpretation only';

            return $data;

        }


        // General disaster questions: collect the broader context.

        $data['flood_risk'] = $this->floodRiskAtPoint($lat, $lon);

        if (is_array($data['flood_risk']) && !empty($data['flood_risk']['available'])) {

            $data['sources'][] = 'BNPB InaRISK — Peta Bahaya/Risiko Banjir';

        }


        [$weather, $provider] = $this->getCurrentWeatherWithFallback($lat, $lon);

        if ($weather !== null) {

            $data['current_weather'] = $weather['current'];

            $data['forecast'] = $weather['forecast'] ?? [];

            $data['historical_weather'] = $weather['history'] ?? [];

            $data['rain_history'] = $this->extractRainHistory($data['historical_weather']);

            $data['sources'][] = $provider;

        }


        $quakes = $this->usgsNearby($lat, $lon);

        $data['earthquakes'] = $quakes;

        if (!empty($quakes)) $data['sources'][] = 'USGS Earthquake Catalog';


        if (($target['country_code'] ?? '') === 'ID') {

            $bmkg = $this->bmkgEarthquake();

            $data['regional_earthquake'] = $bmkg;

            if ($bmkg !== null) $data['sources'][] = 'BMKG';

        }


        $gdacs = $this->gdacsNearby($lat, $lon);

        $data['gdacs_events'] = $gdacs;

        if (!empty($gdacs)) $data['sources'][] = 'GDACS';


        if (($target['country_code'] ?? '') === 'US') {

            $alerts = $this->nwsAlerts($lat, $lon);

            $data['official_alerts'] = $alerts;

            if (!empty($alerts)) $data['sources'][] = 'NOAA/NWS';

            $volcano = $this->usgsVolcanoRegion($lat, $lon);

            $data['volcano'] = $volcano;

            if (!empty($volcano)) $data['sources'][] = 'USGS Volcano Hazards Program';

        }


        $data['sources'][] = 'Langflow + IBM Granite — interpretation only';

        $data['sources'] = array_values(array_unique($data['sources']));

        return $data;

    }


    private function detectWeatherIntent(string $message): string

    {

        $m = mb_strtolower(trim($message));

        if ($m === '') return 'general';


        $historical = preg_match('/\b(kemarin|tadi|pagi tadi|siang tadi|sore tadi|malam tadi|tanggal\s+\d{1,2}|tgl\s+\d{1,2}|hari sebelumnya|minggu lalu|bulan lalu)\b/u', $m);

        $flood = preg_match('/\b(banjir|rawan banjir|terkena banjir|kebanjiran|tanah|rumah|properti|lokasi ini aman|aman dari banjir)\b/u', $m);

        $current = preg_match('/\b(sekarang|saat ini|kondisi sekarang|suhu sekarang|berapa suhu|temperatur sekarang|cuaca sekarang|sekarang hujan|saat ini hujan)\b/u', $m);

        $future = preg_match('/\b(besok|nanti|malam ini|pagi ini|siang ini|sore ini|malam nanti|minggu depan|sabtu|minggu)\b/u', $m);


        if ($flood && !$historical && !$future) return 'flood_risk';

        if ($historical) return 'historical_weather';

        if ($current) return 'current_weather';

        if ($future) return 'forecast_weather';

        return 'general';

    }


    private function getCurrentWeatherWithFallback(float $lat, float $lon): array

    {

        // Current weather must stay on the same provider as Home. Do not

        // silently substitute a model source and then present it as current

        // WeatherAPI data. Open-Meteo remains available for map/model layers.

        $weather = $this->weatherApiCurrent($lat, $lon);

        if ($weather !== null) return [$weather, 'WeatherAPI'];


        return [null, null];

    }


    private function getHistoricalWeatherWithFallback(float $lat, float $lon): array

    {

        $weather = $this->weatherApiHistorical($lat, $lon);

        if ($weather !== null && !empty($weather['history'])) return [$weather, 'WeatherAPI'];


        $weather = $this->openMeteoHistorical($lat, $lon);

        if ($weather !== null) return [$weather, 'Open-Meteo historical fallback'];


        return [null, null];

    }

    private function floodRiskAtPoint(float $lat, float $lon): array

    {

        $cacheKey = 'floodguard:bnpb:flood-point:' . round($lat, 5) . ':' . round($lon, 5);

        return Cache::remember($cacheKey, now()->addHours(12), function () use ($lat, $lon) {

            $hazard = $this->identifyInaRiskPixel(

                'https://gis.bnpb.go.id/server/rest/services/inarisk/layer_bahaya_banjir/ImageServer/identify',

                $lat,

                $lon

            );

            $risk = $this->identifyInaRiskPixel(

                'https://gis.bnpb.go.id/server/rest/services/inarisk/layer_risiko_banjir/ImageServer/identify',

                $lat,

                $lon

            );


            $hazardIndex = $hazard['value'] ?? null;

            $riskIndex = $risk['value'] ?? null;

            $available = $hazardIndex !== null || $riskIndex !== null;


            if (!$available) {

                return [

                    'available' => false,

                    'answer' => 'BELUM DAPAT DITENTUKAN',

                    'hazard_index' => null,

                    'hazard_class' => null,

                    'risk_index' => null,

                    'risk_class' => null,

                    'source' => 'BNPB InaRISK',

                    'explanation' => 'Titik tidak mendapatkan nilai raster dari layer BNPB yang diperiksa.',

                ];

            }


            $hazardClass = $this->classifyInaRiskIndex($hazardIndex);

            $riskClass = $this->classifyInaRiskIndex($riskIndex);

            // Untuk jawaban biner, "YA" berarti titik masuk kelas bahaya banjir

            // sedang/tinggi. Kelas rendah tidak dipresentasikan sebagai jaminan bebas banjir.

            $answer = in_array($hazardClass, ['Sedang', 'Tinggi'], true) ? 'YA' : 'TIDAK';


            $explanation = $answer === 'YA'

                ? 'Titik ini masuk kelas bahaya banjir ' . $hazardClass . ' pada layer bahaya banjir BNPB InaRISK.'

                : 'Titik ini tidak masuk kelas bahaya banjir sedang/tinggi pada layer BNPB InaRISK yang diperiksa.';


            return [

                'available' => true,

                'answer' => $answer,

                'hazard_index' => $hazardIndex,

                'hazard_class' => $hazardClass,

                'risk_index' => $riskIndex,

                'risk_class' => $riskClass,

                'source' => 'BNPB InaRISK',

                'layer_resolution_m' => 100,

                'explanation' => $explanation,

                'checked_at' => now()->toIso8601String(),

            ];

        });

    }


    private function identifyInaRiskPixel(string $url, float $lat, float $lon): array

    {

        try {

            $response = Http::timeout(8)->connectTimeout(3)->get($url, [

                'geometry' => $lon . ',' . $lat,

                'geometryType' => 'esriGeometryPoint',

                'sr' => '4326',

                'returnGeometry' => 'false',

                'returnCatalogItems' => 'false',

                'f' => 'json',

            ]);

            if (!$response->successful()) return ['value' => null];

            $json = $response->json();

            if (!is_array($json)) return ['value' => null];

            $value = $json['value'] ?? $json['pixelValue'] ?? null;

            if (is_numeric($value)) return ['value' => (float) $value];

            return ['value' => null];

        } catch (Throwable $e) {

            report($e);

            return ['value' => null];

        }

    }


    private function classifyInaRiskIndex($value): ?string

    {

        if (!is_numeric($value)) return null;

        $v = (float) $value;

        if ($v <= 0.333) return 'Rendah';

        if ($v <= 0.666) return 'Sedang';

        return 'Tinggi';

    }


    private function weatherApiCurrent(float $lat, float $lon): ?array

    {

        $key = trim((string) (config('services.weatherapi.key') ?: env('WEATHER_API_KEY', '')));

        if ($key === '') return null;


        $cacheKey = 'floodguard:weatherapi:current:' . round($lat, 3) . ':' . round($lon, 3);

        return Cache::remember($cacheKey, now()->addSeconds(300), function () use ($key, $lat, $lon) {

            try {

                $response = Http::timeout(8)->connectTimeout(3)->get('https://api.weatherapi.com/v1/current.json', [

                    'key' => $key,

                    'q' => $lat . ',' . $lon,

                    'aqi' => 'no',

                    'lang' => 'id',

                ]);

                if (!$response->successful()) return null;

                $json = $response->json();

                $current = $json['current'] ?? null;

                if (!is_array($current) || !isset($current['temp_c'])) return null;


                return [

                    'provider' => 'WeatherAPI',

                    'updated_at' => $current['last_updated'] ?? null,

                    'current' => [

                        'temperature_c' => $current['temp_c'] ?? null,

                        'feels_like_c' => $current['feelslike_c'] ?? null,

                        'humidity_percent' => $current['humidity'] ?? null,

                        'condition' => data_get($current, 'condition.text'),

                        'wind_kph' => $current['wind_kph'] ?? null,

                        'wind_direction' => $current['wind_dir'] ?? null,

                        'gust_kph' => $current['gust_kph'] ?? null,

                        'pressure_mb' => $current['pressure_mb'] ?? null,

                        'cloud_percent' => $current['cloud'] ?? null,

                        'visibility_km' => $current['vis_km'] ?? null,

                        'precip_mm' => $current['precip_mm'] ?? null,

                        'uv' => $current['uv'] ?? null,

                        'air_quality' => $current['air_quality'] ?? null,

                        'source_type' => 'WeatherAPI current observation/model blend',

                    ],

                    'forecast' => [],

                    'history' => [],

                ];

            } catch (Throwable $e) {

                report($e);

                return null;

            }

        });

    }


    private function weatherApiHistorical(float $lat, float $lon): ?array

    {

        $key = trim((string) (config('services.weatherapi.key') ?: env('WEATHER_API_KEY', '')));

        if ($key === '') return null;


        $cacheKey = 'floodguard:weatherapi:history:' . round($lat, 3) . ':' . round($lon, 3);

        return Cache::remember($cacheKey, now()->addSeconds(900), function () use ($key, $lat, $lon) {

            try {

                $history = [];

                $dates = [now()->subDay()->format('Y-m-d'), now()->format('Y-m-d')];

                foreach ($dates as $historyDate) {

                    $response = Http::timeout(8)->connectTimeout(3)->get('https://api.weatherapi.com/v1/history.json', [

                        'key' => $key,

                        'q' => $lat . ',' . $lon,

                        'dt' => $historyDate,

                    ]);

                    if (!$response->successful()) continue;

                    $days = $response->json('forecast.forecastday', []);

                    if (is_array($days)) $history = array_merge($history, $days);

                }

                if (empty($history)) return null;

                return [

                    'provider' => 'WeatherAPI',

                    'updated_at' => now()->toIso8601String(),

                    'current' => null,

                    'forecast' => [],

                    'history' => $history,

                ];

            } catch (Throwable $e) {

                report($e);

                return null;

            }

        });

    }


    private function openMeteoCurrent(float $lat, float $lon): ?array

    {

        $cacheKey = 'floodguard:openmeteo:current:' . round($lat, 3) . ':' . round($lon, 3);

        return Cache::remember($cacheKey, now()->addSeconds(300), function () use ($lat, $lon) {

            try {

                $response = Http::timeout(8)->connectTimeout(3)->get('https://api.open-meteo.com/v1/forecast', [

                    'latitude' => $lat,

                    'longitude' => $lon,

                    'current' => 'temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,rain,showers,weather_code,wind_speed_10m,wind_direction_10m,wind_gusts_10m,surface_pressure,cloud_cover,visibility,dew_point_2m',

                    'timezone' => 'auto',

                ]);

                if (!$response->successful()) return null;

                $json = $response->json();

                if (!is_array($json) || !isset($json['current']['temperature_2m'])) return null;

                return [

                    'provider' => 'Open-Meteo',

                    'updated_at' => $json['current']['time'] ?? null,

                    'current' => $json['current'],

                    'forecast' => [],

                    'history' => [],

                ];

            } catch (Throwable $e) {

                report($e);

                return null;

            }

        });

    }


    private function openMeteoHistorical(float $lat, float $lon): ?array

    {

        $cacheKey = 'floodguard:openmeteo:history:' . round($lat, 3) . ':' . round($lon, 3);

        return Cache::remember($cacheKey, now()->addSeconds(900), function () use ($lat, $lon) {

            try {

                $response = Http::timeout(10)->connectTimeout(3)->get('https://api.open-meteo.com/v1/forecast', [

                    'latitude' => $lat,

                    'longitude' => $lon,

                    'hourly' => 'temperature_2m,precipitation,weather_code,wind_speed_10m,relative_humidity_2m',

                    'forecast_days' => 2,

                    'past_days' => 2,

                    'timezone' => 'auto',

                ]);

                if (!$response->successful()) return null;

                $json = $response->json();

                if (!is_array($json) || empty($json['hourly'])) return null;

                return [

                    'provider' => 'Open-Meteo',

                    'updated_at' => now()->toIso8601String(),

                    'current' => null,

                    'forecast' => $json['hourly'],

                    'history' => $this->extractOpenMeteoHistory($json['hourly']),

                ];

            } catch (Throwable $e) {

                report($e);

                return null;

            }

        });

    }

    private function extractOpenMeteoHistory(array $hourly): array

    {

        $times = $hourly['time'] ?? [];

        $precip = $hourly['precipitation'] ?? [];

        $weather = $hourly['weather_code'] ?? [];

        $out = [];

        foreach ($times as $i => $time) {

            try {

                $dt = new \DateTimeImmutable((string) $time);

                // Keep only hours before the current server hour.

                if ($dt > now()) continue;

            } catch (Throwable $e) {

                continue;

            }

            $out[] = [

                'time' => $time,

                'precipitation_mm' => isset($precip[$i]) ? (float) $precip[$i] : null,

                'weather_code' => $weather[$i] ?? null,

                'source_type' => 'Open-Meteo historical model/reanalysis estimate',

            ];

        }

        return array_slice($out, -48);

    }


    private function extractRainHistory(array $history): array

    {

        $out = [];

        foreach ($history as $day) {

            foreach (($day['hour'] ?? []) as $hour) {

                if (!is_array($hour)) continue;

                $time = $hour['time'] ?? null;

                if ($time === null) continue;

                $out[] = [

                    'time' => $time,

                    'precipitation_mm' => isset($hour['precip_mm']) ? (float) $hour['precip_mm'] : null,

                    'condition' => data_get($hour, 'condition.text'),

                    'chance_of_rain_percent' => isset($hour['chance_of_rain']) ? (int) $hour['chance_of_rain'] : null,

                    'source_type' => 'WeatherAPI historical/current observation',

                ];

            }

        }

        return array_slice($out, -24);

    }


    private function usgsNearby(float $lat, float $lon): array

    {

        $cacheKey = 'floodguard:usgs:nearby:' . round($lat, 2) . ':' . round($lon, 2);

        return Cache::remember($cacheKey, now()->addSeconds(self::EARTHQUAKE_CACHE_SECONDS), function () use ($lat, $lon) {

            try {

                $response = Http::timeout(12)->connectTimeout(3)->get('https://earthquake.usgs.gov/fdsnws/event/1/query', [

                    'format' => 'geojson',

                    'starttime' => now()->subDay()->toIso8601String(),

                    'endtime' => now()->toIso8601String(),

                    'latitude' => $lat,

                    'longitude' => $lon,

                    'maxradiuskm' => 500,

                    'orderby' => 'time',

                    'limit' => 100,

                ]);

                if (!$response->successful()) return [];

                return $this->normalizeUsgs($response->json('features', []));

            } catch (Throwable $e) {

                report($e);

                return [];

            }

        });

    }


    private function usgsGlobal(): array

    {

        return Cache::remember('floodguard:usgs:global:day', now()->addSeconds(self::EARTHQUAKE_CACHE_SECONDS), function () {

            try {

                $response = Http::timeout(12)->connectTimeout(3)->get('https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/all_day.geojson');

                if (!$response->successful()) return [];

                return $this->normalizeUsgs($response->json('features', []));

            } catch (Throwable $e) {

                report($e);

                return [];

            }

        });

    }


    private function normalizeUsgs($features): array

    {

        if (!is_array($features)) return [];

        $out = [];

        foreach ($features as $feature) {

            if (!is_array($feature)) continue;

            $p = $feature['properties'] ?? [];

            $g = $feature['geometry'] ?? [];

            $c = $g['coordinates'] ?? [];

            if (!is_array($p) || !is_array($c) || count($c) < 3) continue;

            $out[] = [

                'id' => $feature['id'] ?? null,

                'magnitude' => $p['mag'] ?? null,

                'place' => $p['place'] ?? null,

                'time' => isset($p['time']) ? date(DATE_ATOM, ((int) $p['time']) / 1000) : null,

                'depth_km' => $c[2] ?? null,

                'latitude' => $c[1] ?? null,

                'longitude' => $c[0] ?? null,

                'tsunami' => ((int) ($p['tsunami'] ?? 0)) === 1,

                'url' => $p['url'] ?? null,

            ];

        }

        return $out;

    }


    private function bmkgEarthquake(): ?array

    {

        return Cache::remember('floodguard:bmkg:earthquake:latest', now()->addSeconds(60), function () {

            try {

                $response = Http::timeout(8)->connectTimeout(3)->get('https://data.bmkg.go.id/DataMKG/TEWS/autogempa.json');

                return $response->successful() ? $response->json('Infogempa.gempa') : null;

            } catch (Throwable $e) {

                report($e);

                return null;

            }

        });

    }


    private function gdacsNearby(?float $lat, ?float $lon): array

    {

        $cacheKey = 'floodguard:gdacs:2day';

        $events = Cache::remember($cacheKey, now()->addSeconds(self::GDACS_CACHE_SECONDS), function () {

            try {

                $response = Http::timeout(12)->connectTimeout(3)->get('https://www.gdacs.org/gdacsapi/api/Events/geteventlist/SEARCH', [

                    'eventlist' => 'EQ;TC;FL;WF',

                    'fromdate' => now()->subDays(2)->format('Y-m-d'),

                    'todate' => now()->format('Y-m-d'),

                    'alertlevel' => 'red;orange;green',

                ]);

                if (!$response->successful()) return [];

                $json = $response->json();

                return is_array($json['features'] ?? null) ? $json['features'] : [];

            } catch (Throwable $e) {

                report($e);

                return [];

            }

        });


        if ($lat === null || $lon === null) return array_slice($events, 0, 50);

        $near = [];

        foreach ($events as $event) {

            if (!is_array($event)) continue;

            $coords = data_get($event, 'geometry.coordinates');

            if (!is_array($coords) || count($coords) < 2) continue;

            $distance = $this->distanceKm($lat, $lon, (float) $coords[1], (float) $coords[0]);

            if ($distance <= 1000) {

                $event['\_distance_km'] = round($distance, 1);

                $near[] = $event;

            }

        }

        return array_slice($near, 0, 50);

    }


    private function nwsAlerts(float $lat, float $lon): array

    {

        $key = 'floodguard:nws:alerts:' . round($lat, 2) . ':' . round($lon, 2);

        return Cache::remember($key, now()->addSeconds(60), function () use ($lat, $lon) {

            try {

                $response = Http::timeout(8)->connectTimeout(3)->withHeaders(['User-Agent' => 'FloodGuard/1.0'])->get(

                    'https://api.weather.gov/alerts/active',

                    ['point' => $lat . ',' . $lon]

                );

                if (!$response->successful()) return [];

                return array_slice((array) $response->json('features', []), 0, 30);

            } catch (Throwable $e) {

                report($e);

                return [];

            }

        });

    }


    private function usgsVolcanoRegion(float $lat, float $lon): array

    {

        $lat1 = $lat - 3; $lat2 = $lat + 3; $lon1 = $lon - 3; $lon2 = $lon + 3;

        $key = 'floodguard:usgs:volcano:' . round($lat, 1) . ':' . round($lon, 1);

        return Cache::remember($key, now()->addMinutes(10), function () use ($lat1, $lat2, $lon1, $lon2) {

            try {

                $response = Http::timeout(10)->connectTimeout(3)->get('https://volcanoes.usgs.gov/vsc/api/volcanoApi/regionstatus', [

                    'lat1' => $lat1, 'lat2' => $lat2, 'long1' => $lon1, 'long2' => $lon2,

                ]);

                if (!$response->successful()) return [];

                $json = $response->json();

                return is_array($json) ? $json : [];

            } catch (Throwable $e) {

                report($e);

                return [];

            }

        });

    }


    private function buildPrompt(string $message, array $target, array $data): string

    {

        $now = now()->toIso8601String();

        $json = json_encode($data, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);


        return <<<PROMPT

Kamu adalah FloodGuard AI Analyst. Kamu berjalan melalui Langflow dan menggunakan IBM Granite melalui Ollama.


WAKTU SERVER: {$now}


PERTANYAAN PENGGUNA:

{$message}


TARGET LOKASI YANG SUDAH DIRESOLUSI:

Nama: {$target['name']}

Negara: {$target['country']} ({$target['country_code']})

Koordinat: {$target['latitude']}, {$target['longitude']}

Resolusi: {$target['resolution']}


DATA REALTIME/TERBARU YANG SUDAH DIAMBIL SERVER:

{$json}


ATURAN WAJIB:

1. Untuk angka kondisi saat ini (suhu, kelembapan, angin, hujan, tekanan, dll), gunakan HANYA data current_weather yang diberikan.

2. Jangan menggunakan pengetahuan bawaan model AI untuk mengisi angka terkini.

3. Untuk gempa, gunakan HANYA earthquakes/regional_earthquake yang diberikan. Jangan mengarang magnitudo, kedalaman, waktu, atau lokasi.

4. Jika pengguna menyebut kota/negara tertentu, jawab lokasi tersebut, BUKAN otomatis lokasi perangkat.

5. Jika lokasi target berbeda dari lokasi perangkat, jangan mencampur kedua lokasi.

6. Jika data kosong, katakan data belum tersedia. Jangan menebak.

7. Bedakan data current dari forecast/model. Jangan menyebut forecast sebagai sensor langsung.

8. Sebutkan sumber jika relevan: WeatherAPI/Open-Meteo, USGS, BMKG, GDACS, NOAA/NWS.

9. Untuk pertanyaan "sekarang", gunakan current_weather. Jika source_type adalah WeatherAPI, sebutkan waktu updated_at bila tersedia. Jangan menggunakan forecast/history untuk responder suhu sekarang.

10. Untuk pertanyaan seperti "tadi hujan?", "hari ini hujan?", "pagi tadi hujan?", gunakan rain_history/historical_weather. Jika sumbernya Open-Meteo historical model/reanalysis, sebutkan bahwa itu estimasi model, bukan pengukuran hujan langsung. Jangan memakai current_weather untuk membuktikan hujan yang sudah terjadi beberapa jam lalu.

11. Untuk pertanyaan apakah suatu titik/wilayah terkena atau rawan banjir, gunakan HANYA field flood_risk yang berasal dari BNPB InaRISK. Jawaban harus dimulai tepat dengan "JAWABAN: YA", "JAWABAN: TIDAK", atau "JAWABAN: BELUM DAPAT DITENTUKAN". YA berarti titik berada pada kelas bahaya banjir sedang/tinggi pada layer resmi yang diperiksa; TIDAK berarti titik tidak berada pada kelas sedang/tinggi. Jangan mengubah TIDAK menjadi jaminan bebas banjir. Jika pengguna membahas membeli tanah/rumah, jelaskan bahwa hasil ini adalah pemeriksaan peta bahaya/risko pada titik, bukan jaminan legal/teknis bahwa bangunan pasti aman.

12. Untuk pertanyaan gempa "saat ini", jelaskan bahwa magnitudo adalah besaran kejadian gempa terbaru yang terdeteksi, bukan "skala suhu" atau prediksi.

11. Jawab Bahasa Indonesia, natural, singkat, jelas, dan langsung menjawab pertanyaan.


JANGAN membuat daftar negara yang didukung. Sistem FloodGuard bersifat global berbasis koordinat.

PROMPT;

    }


    private function generateLangflow(string $prompt): array
    {
        $baseUrl = rtrim(
            (string) config('services.langflow.url', 'http://127.0.0.1:7860'),
            '/'
        );

        $flowId = trim((string) config('services.langflow.flow_id', ''));
        $apiKey = trim((string) config('services.langflow.api_key', ''));

        if ($flowId === '') {
            throw new \RuntimeException('LANGFLOW_FLOW_ID belum dikonfigurasi.');
        }

        if ($apiKey === '') {
            throw new \RuntimeException('LANGFLOW_API_KEY belum dikonfigurasi.');
        }

        $url = $baseUrl . '/api/v1/run/' . $flowId;

        $response = Http::timeout(90)
            ->connectTimeout(5)
            ->withHeaders([
                'x-api-key' => $apiKey,
                'Accept' => 'application/json',
                'Content-Type' => 'application/json',
            ])
            ->post($url, [
                'output_type' => 'chat',
                'input_type' => 'chat',
                'input_value' => $prompt,
                'session_id' => (string) Str::uuid(),
            ]);

        if (!$response->successful()) {
            throw new \RuntimeException(
                'Langflow HTTP ' . $response->status() . ': ' . $response->body()
            );
        }

        $json = $response->json();

        if (!is_array($json)) {
            throw new \RuntimeException(
                'Respons Langflow bukan JSON object yang valid.'
            );
        }

        $answer = $this->extractLangflowText($json);

        if ($answer === '') {
            throw new \RuntimeException(
                'Langflow berhasil merespons tetapi teks AI tidak ditemukan dalam response.'
            );
        }

        return [$answer, 'IBM Granite via Ollama + Langflow'];
    }

    private function extractLangflowText(array $data): string
    {
        $candidates = [
            data_get($data, 'outputs.0.outputs.0.results.message.text'),
            data_get($data, 'outputs.0.outputs.0.message.text'),
            data_get($data, 'outputs.0.outputs.0.results.text'),
            data_get($data, 'outputs.0.outputs.0.text'),
            data_get($data, 'outputs.0.outputs.0.artifacts.message'),
            data_get($data, 'outputs.0.outputs.0.artifacts.text'),
            data_get($data, 'outputs.0.outputs.0.data.text'),
        ];

        foreach ($candidates as $candidate) {
            if (is_string($candidate) && trim($candidate) !== '') {
                return trim($candidate);
            }
        }

        $found = $this->findLangflowText($data);

        return $found !== null ? trim($found) : '';
    }

    private function findLangflowText(mixed $value): ?string
    {
        if (!is_array($value)) {
            return null;
        }

        foreach (['text', 'message', 'content'] as $key) {
            if (
                isset($value[$key]) &&
                is_string($value[$key]) &&
                trim($value[$key]) !== ''
            ) {
                return trim($value[$key]);
            }
        }

        foreach ($value as $child) {
            $found = $this->findLangflowText($child);

            if ($found !== null && $found !== '') {
                return $found;
            }
        }

        return null;
    }

    private function fallbackAnswer(string $message, array $target, array $data): string

    {

        $name = $target['name'] ?? 'lokasi tersebut';

        $lower = mb_strtolower($message);


        // Pertanyaan properti/banjir harus punya jawaban deterministik dari BNPB,

        // bukan fallback cuaca yang bisa menyesatkan.

        if (preg_match('/**\b**(banjir|banjirnya|rawan banjir|terkena banjir|kebanjiran|rumah|tanah|properti)**\b**/u', $lower)) {

            $f = $data['flood_risk'] ?? null;

            if (is_array($f) && !empty($f['available'])) {

                $answer = ($f['answer'] ?? null) === 'YA' ? 'JAWABAN: YA' : (($f['answer'] ?? null) === 'TIDAK' ? 'JAWABAN: TIDAK' : 'JAWABAN: BELUM DAPAT DITENTUKAN');

                $detail = $f['explanation'] ?? 'Pemeriksaan menggunakan layer bahaya banjir BNPB InaRISK pada titik yang dipilih.';

                return $answer . '. ' . $detail . ' Ini bukan jaminan bahwa lokasi pasti bebas banjir pada setiap kejadian.';

            }

            return 'JAWABAN: BELUM DAPAT DITENTUKAN. Layer BNPB InaRISK untuk titik ini belum berhasil dibaca, jadi FloodGuard tidak akan menebak.';

        }


        // Jangan menjawab pertanyaan historis dengan suhu/kondisi saat ini.

        if (preg_match('/**\b**(hujan|gerimis|hujannya|curah hujan)**\b**/u', $lower) && preg_match('/**\b**(kemarin|tadi|pagi tadi|siang tadi|sore tadi|malam tadi|hari ini)**\b**/u', $lower)) {

            $history = $data['rain_history'] ?? [];

            if (is_array($history) && !empty($history)) {

                $rainHours = array_values(array_filter($history, static function ($h) {

                    return is_array($h) && isset($h['precipitation_mm']) && (float) $h['precipitation_mm'] > 0.1;

                }));

                $max = 0.0;

                foreach ($history as $h) {

                    if (is_array($h) && isset($h['precipitation_mm'])) $max = max($max, (float) $h['precipitation_mm']);

                }

                $sourceType = $history[0]['source_type'] ?? '';

                $estimate = str_contains(strtolower($sourceType), 'model') ? ' Ini estimasi model/reanalysis, bukan pengukuran hujan langsung.' : '';

                if (!empty($rainHours)) {

                    return 'Ya, data historis yang tersedia menunjukkan ada curah hujan pada beberapa jam dalam periode yang ditanyakan. Curah hujan maksimum yang tercatat/terestimasi sekitar ' . number_format($max, 1, ',', '.') . ' mm per jam.' . $estimate;

                }

                return 'Tidak, pada data historis yang tersedia tidak terlihat curah hujan berarti pada periode yang ditanyakan.' . $estimate;

            }

            return 'JAWABAN: BELUM DAPAT DITENTUKAN. Data historis hujan untuk periode yang ditanyakan belum tersedia.';

        }

        $current = $data['current_weather'] ?? null;

        $parts = [];

        if (is_array($current)) {

            $temp = $current['temperature_c'] ?? $current['temperature_2m'] ?? null;

            $condition = $current['condition'] ?? null;

            if ($temp !== null) $parts[] = 'suhu ' . $temp . 'Â°C';

            if ($condition !== null) $parts[] = 'kondisi ' . $condition;

            $humidity = $current['humidity_percent'] ?? $current['relative_humidity_2m'] ?? null;

            if ($humidity !== null) $parts[] = 'kelembapan ' . $humidity . '%';

            $wind = $current['wind_kph'] ?? $current['wind_speed_10m'] ?? null;

            if ($wind !== null) $parts[] = 'angin ' . $wind . ' km/j';

        }


        $answer = $parts

            ? 'Data terbaru untuk ' . $name . ': ' . implode(', ', $parts) . '.'

            : 'Data cuaca terbaru untuk ' . $name . ' belum tersedia.';


        $quake = $data['earthquakes'][0] ?? null;

        if (is_array($quake)) {

            $answer .= ' Gempa terdekat/terbaru yang terdeteksi USGS: M' . ($quake['magnitude'] ?? '-')

                . ', ' . ($quake['place'] ?? 'lokasi tidak diketahui') . ', waktu ' . ($quake['time'] ?? '-') . '.';

        } elseif (is_array($data['regional_earthquake'])) {

            $q = $data['regional_earthquake'];

            $answer .= ' BMKG melaporkan gempa terbaru: M' . ($q['Magnitude'] ?? '-') . ' di ' . ($q['Wilayah'] ?? '-') . '.';

        }


        return $answer . ' Data tidak dikarang.';

    }


    private function distanceKm(float $lat1, float $lon1, float $lat2, float $lon2): float

    {

        $r = 6371.0;

        $p1 = deg2rad($lat1); $p2 = deg2rad($lat2);

        $dp = deg2rad($lat2 - $lat1); $dl = deg2rad($lon2 - $lon1);

        $a = sin($dp / 2) ** 2 + cos($p1) * cos($p2) * sin($dl / 2) ** 2;

        return $r * 2 * atan2(sqrt($a), sqrt(max(0.0, 1 - $a)));

    }

}
