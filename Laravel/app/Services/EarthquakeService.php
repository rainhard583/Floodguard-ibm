<?php

namespace App\Services;

use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Throwable;

class EarthquakeService
{
    public function overview(?float $lat = null, ?float $lon = null, float $radiusKm = 500): array
    {
        $global = Cache::remember('floodguard:eq:usgs:day', now()->addMinutes(1), fn () => $this->usgsDay());
        $bmkg = Cache::remember('floodguard:eq:bmkg:latest', now()->addMinutes(1), fn () => $this->bmkg());
        $afad = Cache::remember('floodguard:eq:afad:latest', now()->addMinutes(1), fn () => $this->afad());

        $events = $this->deduplicate(array_merge($global, $bmkg, $afad));
        usort($events, fn($a,$b) => ($b['time_epoch'] ?? 0) <=> ($a['time_epoch'] ?? 0));

        $location = null;
        if ($lat !== null && $lon !== null) {
            $near = [];
            foreach ($events as $event) {
                if (!isset($event['latitude'], $event['longitude'])) continue;
                $distance = $this->distanceKm($lat, $lon, $event['latitude'], $event['longitude']);
                if ($distance <= $radiusKm) {
                    $event['distance_km'] = round($distance, 1);
                    $near[] = $event;
                }
            }
            usort($near, fn($a,$b) => ($a['distance_km'] ?? INF) <=> ($b['distance_km'] ?? INF));
            $location = ['latitude'=>$lat,'longitude'=>$lon,'radius_km'=>$radiusKm,'events'=>$near,'nearest'=>$near[0] ?? null];
        }

        return [
            'status' => 'ok',
            'updated_at' => now()->toIso8601String(),
            'global_source' => 'USGS',
            'global' => array_slice($events, 0, 50),
            'latest_relevant' => $location['nearest'] ?? ($events[0] ?? null),
            'local_sources' => array_values(array_filter([
                !empty($bmkg) ? ['source'=>'BMKG — Indonesia','count'=>count($bmkg),'latest'=>$bmkg[0]??null] : null,
                !empty($afad) ? ['source'=>'AFAD — Türkiye','count'=>count($afad),'latest'=>$afad[0]??null] : null,
            ])),
            'location' => $location,
        ];
    }

    private function usgsDay(): array
    {
        $json = Http::timeout(10)->connectTimeout(3)->get('https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/all_day.geojson')->throw()->json();
        return collect($json['features'] ?? [])->map(fn($f) => $this->normalizeUsgs($f))->filter()->values()->all();
    }

    private function normalizeUsgs(array $f): ?array
    {
        $p=$f['properties']??[]; $g=$f['geometry']['coordinates']??[];
        if (!isset($g[0],$g[1])) return null;
        return ['id'=>(string)($f['id']??''),'source'=>'USGS','magnitude'=>isset($p['mag'])?(float)$p['mag']:null,'mag_type'=>$p['magType']??null,'place'=>$p['place']??null,'time_epoch'=>isset($p['time'])?(int)($p['time']/1000):null,'updated_epoch'=>isset($p['updated'])?(int)($p['updated']/1000):null,'latitude'=>(float)$g[1],'longitude'=>(float)$g[0],'depth_km'=>isset($g[2])?(float)$g[2]:null,'mmi'=>$p['mmi']??null,'cdi'=>$p['cdi']??null,'tsunami'=>$p['tsunami']??null,'detail'=>$p['detail']??null];
    }

    private function bmkg(): array
    {
        try {
            $json=Http::timeout(8)->connectTimeout(3)->get('https://data.bmkg.go.id/DataMKG/TEWS/gempaterkini.json')->throw()->json();
            $items=$json['Infogempa']['gempa']??[];
            return collect($items)->map(function($e){
                $coord=$e['Coordinates']??$e['coordinates']??''; $parts=preg_split('/\s*,\s*/',(string)$coord);
                $lat=isset($parts[0])?(float)$parts[0]:null; $lon=isset($parts[1])?(float)$parts[1]:null;
                return ['id'=>'bmkg-'.md5(json_encode($e)),'source'=>'BMKG','magnitude'=>isset($e['Magnitude'])?(float)$e['Magnitude']:null,'mag_type'=>null,'place'=>$e['Wilayah']??null,'time_epoch'=>$this->parseTime($e['DateTime']??$e['Tanggal'].' '.$e['Jam']??null),'latitude'=>$lat,'longitude'=>$lon,'depth_km'=>$this->parseDepth($e['Kedalaman']??null),'mmi'=>$e['Dirasakan']??null,'tsunami'=>$e['Potensi']??null];
            })->filter(fn($x)=>$x['latitude']!==null&&$x['longitude']!==null)->values()->all();
        } catch(Throwable $e){ report($e); return []; }
    }

    private function afad(): array
    {
        try {
            $html=Http::timeout(10)->connectTimeout(3)->get('https://deprem.afad.gov.tr/last-earthquakes.html')->throw()->body();
            if (!preg_match_all('/<tr[^>]*>\s*<td[^>]*>(.*?)<\/td>\s*<td[^>]*>(.*?)<\/td>\s*<td[^>]*>(.*?)<\/td>\s*<td[^>]*>(.*?)<\/td>\s*<td[^>]*>(.*?)<\/td>\s*<td[^>]*>(.*?)<\/td>\s*<td[^>]*>(.*?)<\/td>/is',$html,$m,PREG_SET_ORDER)) return [];
            $out=[];
            foreach($m as $r){
                $clean=fn($s)=>trim(html_entity_decode(strip_tags($s)));
                $date=$clean($r[1]); $lat=(float)$clean($r[2]); $lon=(float)$clean($r[3]); $depth=(float)$clean($r[4]); $mag=(float)$clean($r[6]); $place=$clean($r[7]);
                if(!$lat || !$lon) continue;
                $out[]=['id'=>'afad-'.sha1($date.'|'.$lat.'|'.$lon.'|'.$mag.'|'.$place),'source'=>'AFAD — Türkiye','magnitude'=>$mag,'mag_type'=>$clean($r[5]),'place'=>$place,'time_epoch'=>strtotime($date.' UTC'),'latitude'=>$lat,'longitude'=>$lon,'depth_km'=>$depth];
            }
            return array_slice($out,0,100);
        } catch(Throwable $e){ report($e); return []; }
    }

    private function deduplicate(array $events): array
    {
        $out=[];
        foreach($events as $e){
            $matched=null;
            foreach($out as $i=>$x){
                if(($e['latitude']??999)===null||($x['latitude']??999)===null) continue;
                $d=$this->distanceKm($e['latitude'],$e['longitude'],$x['latitude'],$x['longitude']);
                $dt=abs(($e['time_epoch']??0)-($x['time_epoch']??0));
                if($d<=35 && $dt<=180){$matched=$i;break;}
            }
            if($matched===null){$out[]=$e;continue;}
            $existing=$out[$matched];
            $sources=array_unique(array_merge(explode(' + ',$existing['source']??''),[$e['source']??'']));
            $existing['source']=implode(' + ',array_filter($sources));
            foreach(['magnitude','mag_type','place','mmi','cdi','tsunami','detail'] as $k) if(($existing[$k]??null)===null && ($e[$k]??null)!==null) $existing[$k]=$e[$k];
            $out[$matched]=$existing;
        }
        return $out;
    }

    private function parseTime($value): ?int { if(!$value) return null; $t=strtotime((string)$value); return $t===false?null:$t; }
    private function parseDepth($value): ?float { if(!$value) return null; if(preg_match('/([0-9]+(?:\.[0-9]+)?)/',(string)$value,$m)) return (float)$m[1]; return null; }
    private function distanceKm(float $lat1,float $lon1,float $lat2,float $lon2): float { $r=6371; $dLat=deg2rad($lat2-$lat1); $dLon=deg2rad($lon2-$lon1); $a=sin($dLat/2)**2+cos(deg2rad($lat1))*cos(deg2rad($lat2))*sin($dLon/2)**2; return $r*2*asin(min(1,sqrt($a))); }
}
