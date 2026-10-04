<?php
namespace App\Http\Controllers;
use App\Services\EarthquakeService;
use Illuminate\Http\Request;
use Throwable;
class EarthquakeController extends Controller
{
    public function overview(Request $request, EarthquakeService $service)
    {
        $lat=is_numeric($request->query('latitude'))?(float)$request->query('latitude'):null;
        $lon=is_numeric($request->query('longitude'))?(float)$request->query('longitude'):null;
        $radius=is_numeric($request->query('radius_km'))?max(1,min(2000,(float)$request->query('radius_km'))):500;
        try { return response()->json(['success'=>true]+$service->overview($lat,$lon,$radius)); }
        catch(Throwable $e){ report($e); return response()->json(['success'=>false,'error'=>'Data gempa belum tersedia.'],502); }
    }
}
