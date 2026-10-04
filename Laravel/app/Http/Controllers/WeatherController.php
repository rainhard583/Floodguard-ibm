<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Throwable;

class WeatherController extends Controller
{
    private const CACHE_SECONDS = 120;

    public function current(Request $request)
    {
        $lat = is_numeric($request->input('latitude')) ? (float) $request->input('latitude') : null;
        $lon = is_numeric($request->input('longitude')) ? (float) $request->input('longitude') : null;

        if ($lat === null || $lon === null || $lat < -90 || $lat > 90 || $lon < -180 || $lon > 180) {
            return response()->json([
                'success' => false,
                'provider' => 'WeatherAPI',
                'error' => 'Latitude/longitude tidak valid.',
            ], 422);
        }

        $key = trim((string) (config('services.weatherapi.key') ?: env('WEATHER_API_KEY', '')));
        if ($key === '') {
            return response()->json([
                'success' => false,
                'provider' => 'WeatherAPI',
                'error' => 'WEATHER_API_KEY belum dikonfigurasi di Laravel .env.',
            ], 503);
        }

        $cacheKey = 'floodguard:weatherapi:home:' . round($lat, 4) . ':' . round($lon, 4);

        try {
            $payload = Cache::remember($cacheKey, now()->addSeconds(self::CACHE_SECONDS), function () use ($key, $lat, $lon) {
                $response = Http::timeout(10)->connectTimeout(4)->get(
                    'https://api.weatherapi.com/v1/forecast.json',
                    [
                        'key' => $key,
                        'q' => $lat . ',' . $lon,
                        'days' => 2,
                        'aqi' => 'no',
                        'alerts' => 'no',
                        'lang' => 'id',
                    ]
                );

                if (!$response->successful()) {
                    throw new \RuntimeException('WeatherAPI HTTP ' . $response->status());
                }

                $json = $response->json();
                $current = $json['current'] ?? null;
                if (!is_array($current) || !isset($current['temp_c'])) {
                    throw new \RuntimeException('WeatherAPI tidak mengembalikan current weather.');
                }

                $location = $json['location'] ?? [];
                $forecast = [];
                foreach (($json['forecast']['forecastday'] ?? []) as $day) {
                    foreach (($day['hour'] ?? []) as $hour) {
                        if (!is_array($hour)) continue;
                        $forecast[] = [
                            'time' => $hour['time'] ?? null,
                            'temperature_c' => $hour['temp_c'] ?? null,
                            'condition' => data_get($hour, 'condition.text'),
                            'condition_code' => data_get($hour, 'condition.code'),
                            'is_day' => $hour['is_day'] ?? null,
                            'precip_mm' => $hour['precip_mm'] ?? null,
                            'chance_of_rain_percent' => $hour['chance_of_rain'] ?? null,
                            'humidity_percent' => $hour['humidity'] ?? null,
                            'wind_kph' => $hour['wind_kph'] ?? null,
                        ];
                    }
                }

                return [
                    'provider' => 'WeatherAPI',
                    'fetched_at' => now()->toIso8601String(),
                    'location' => [
                        'name' => $location['name'] ?? null,
                        'region' => $location['region'] ?? null,
                        'country' => $location['country'] ?? null,
                        'latitude' => $location['lat'] ?? $lat,
                        'longitude' => $location['lon'] ?? $lon,
                        'localtime' => $location['localtime'] ?? null,
                    ],
                    'current' => [
                        'temperature_c' => $current['temp_c'] ?? null,
                        'feels_like_c' => $current['feelslike_c'] ?? null,
                        'condition' => data_get($current, 'condition.text'),
                        'condition_code' => data_get($current, 'condition.code'),
                        'is_day' => $current['is_day'] ?? null,
                        'precip_mm' => $current['precip_mm'] ?? null,
                        'humidity_percent' => $current['humidity'] ?? null,
                        'wind_kph' => $current['wind_kph'] ?? null,
                        'wind_direction' => $current['wind_dir'] ?? null,
                        'wind_gust_kph' => $current['gust_kph'] ?? null,
                        'pressure_hpa' => $current['pressure_mb'] ?? null,
                        'cloud_percent' => $current['cloud'] ?? null,
                        'uv_index' => $current['uv'] ?? null,
                        'visibility_km' => $current['vis_km'] ?? null,
                        'dewpoint_c' => $current['dewpoint_c'] ?? null,
                        'last_updated' => $current['last_updated'] ?? null,
                        'source' => 'WeatherAPI â€” Current Weather',
                        'observation_type' => 'current',
                    ],
                    'forecast' => array_slice($forecast, 0, 48),
                ];
            });

            return response()->json([
                'success' => true,
                ...$payload,
                'requested_coordinates' => [
                    'latitude' => $lat,
                    'longitude' => $lon,
                ],
            ]);
        } catch (Throwable $e) {
            report($e);
            return response()->json([
                'success' => false,
                'provider' => 'WeatherAPI',
                'error' => 'WeatherAPI gagal diambil. Cek WEATHER_API_KEY dan koneksi Laravel ke api.weatherapi.com.',
                'requested_coordinates' => [
                    'latitude' => $lat,
                    'longitude' => $lon,
                ],
            ], 503);
        }
    }
}

