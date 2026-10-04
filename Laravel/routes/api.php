<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\AiAnalystController;
use App\Http\Controllers\WeatherController;
use App\Http\Controllers\EarthquakeController;



Route::get('/user', function (Request $request) { return $request->user(); })->middleware('auth:sanctum');
Route::post('/ai/analyze', [AiAnalystController::class, 'analyze']);
Route::get('/weather/current', [AiAnalystController::class, 'currentWeather']);
Route::get('/weather/current', [WeatherController::class, 'current']);
Route::get('/earthquakes/overview', [EarthquakeController::class, 'overview']);
Route::get('/hazards/inarisk', [AiAnalystController::class, 'inarisk']);
Route::get('/ai/ping', [AiAnalystController::class, 'ping']);
Route::get('/flood/risk-point', [AiAnalystController::class, 'floodRisk']);
Route::get('/ai/weather-test', [AiAnalystController::class, 'weatherTest']);
