# Google Maps API Contract

**Date**: 2025-12-04
**Feature**: 001-trip-route-visualizer

## Static Maps API

**URL**: `GET https://maps.googleapis.com/maps/api/staticmap`

### Authentication

| Parameter | Value |
|-----------|-------|
| `key` | `$GOOGLE_MAPS_API_KEY` environment variable |

### Request Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `size` | String | Yes | Image dimensions (e.g., `800x600`) |
| `path` | String | Yes | Polyline path (encoded or explicit) |
| `key` | String | Yes | API key |
| `maptype` | String | No | Map type: `roadmap`, `satellite`, `terrain`, `hybrid` |
| `markers` | String | No | Marker definitions |

### Polyline Encoding

**Format**: `path=enc:<encoded_polyline>`

**Encoding Algorithm** (Google Polyline Algorithm):
1. Take the initial signed value
2. Take the two's complement (invert if negative)
3. Left-shift the value by one bit
4. Break into 5-bit chunks (right to left)
5. Place 5-bit chunks into reverse order
6. OR each value with 0x20 if another bit follows
7. Add 63 to each value
8. Convert to ASCII

**Example**:
```
Coordinates: [(38.5, -120.2), (40.7, -120.95), (43.252, -126.453)]
Encoded: _p~iF~ps|U_ulLnnqC_mqNvxq`@
URL: path=enc:_p~iF~ps|U_ulLnnqC_mqNvxq`@
```

### Markers

**Start Marker** (green):
```
markers=color:green|label:S|<lat>,<lng>
```

**End Marker** (red):
```
markers=color:red|label:E|<lat>,<lng>
```

### Path Styling

```
path=color:0x0000ff|weight:5|enc:<encoded_polyline>
```

| Style | Description |
|-------|-------------|
| `color` | Line color (hex or name) |
| `weight` | Line thickness in pixels |
| `fillcolor` | Fill color for polygons |
| `geodesic` | Draw geodesic lines |

### Complete URL Example

```
https://maps.googleapis.com/maps/api/staticmap
  ?size=800x600
  &maptype=roadmap
  &path=color:0x0000ff|weight:4|enc:_p~iF~ps|U_ulLnnqC
  &markers=color:green|label:S|38.5,-120.2
  &markers=color:red|label:E|43.252,-126.453
  &key=YOUR_API_KEY
```

### Limitations

| Limit | Value |
|-------|-------|
| Max URL length | 8192 characters |
| Max image size | 640x640 (free tier) |
| Max path points | ~200-400 (encoded) |

**Mitigation for large routes**:
- Apply Douglas-Peucker simplification
- Generate HTML output instead

### Response

**Success**: PNG image binary

**Error Responses**:

| Status | Meaning |
|--------|---------|
| 400 | Bad request (invalid parameters) |
| 403 | API key invalid or quota exceeded |

---

## JavaScript API (HTML Output)

For interactive HTML output, embed the Maps JavaScript API:

### HTML Template Structure

```html
<!DOCTYPE html>
<html>
<head>
  <title>Trip Route: {TRIP_ID}</title>
  <style>
    #map { height: 100vh; width: 100%; }
  </style>
</head>
<body>
  <div id="map"></div>
  <script>
    function initMap() {
      const coords = {COORDINATES_JSON};
      const map = new google.maps.Map(document.getElementById("map"), {
        zoom: 12,
        center: coords[0]
      });

      const path = new google.maps.Polyline({
        path: coords,
        geodesic: true,
        strokeColor: "#0000FF",
        strokeWeight: 4
      });
      path.setMap(map);

      // Start marker
      new google.maps.Marker({
        position: coords[0],
        map: map,
        icon: "http://maps.google.com/mapfiles/ms/icons/green-dot.png",
        title: "Start"
      });

      // End marker
      new google.maps.Marker({
        position: coords[coords.length - 1],
        map: map,
        icon: "http://maps.google.com/mapfiles/ms/icons/red-dot.png",
        title: "End"
      });

      // Fit bounds
      const bounds = new google.maps.LatLngBounds();
      coords.forEach(c => bounds.extend(c));
      map.fitBounds(bounds);
    }
  </script>
  <script async defer
    src="https://maps.googleapis.com/maps/api/js?key={API_KEY}&callback=initMap">
  </script>
</body>
</html>
```

### Template Placeholders

| Placeholder | Description |
|-------------|-------------|
| `{TRIP_ID}` | UUID of the trip |
| `{COORDINATES_JSON}` | Array of `{lat, lng}` objects |
| `{API_KEY}` | Google Maps API key |

---

## URL Output (Shareable Link)

Generate a Google Maps URL for browser viewing:

```
https://www.google.com/maps/dir/?api=1
  &origin=<start_lat>,<start_lng>
  &destination=<end_lat>,<end_lng>
  &waypoints=<lat1>,<lng1>|<lat2>,<lng2>|...
  &travelmode=driving
```

### Limitations

| Limit | Value |
|-------|-------|
| Max waypoints | 25 (including origin/destination) |
| Max URL length | ~2000 characters recommended |

**Note**: For routes with more than 25 points, use HTML output instead.
