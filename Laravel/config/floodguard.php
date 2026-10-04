<?php

return [
    'weather_api_key' => env('WEATHER_API_KEY'),
    'gemini_api_key' => env('GEMINI_API_KEY'),
    'weather_timeout' => (int) env('WEATHER_API_TIMEOUT', 12),
];
