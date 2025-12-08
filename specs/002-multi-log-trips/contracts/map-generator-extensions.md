# Contract: MapGenerator Extensions

**Date**: 2025-12-07
**Feature**: 002-multi-log-trips

## Overview

Extensions to the existing MapGenerator to support rendering routes with gap segments (dashed lines for missing data between log fragments).

---

## Modified Interface

### writeHTML (Extended)

```swift
/// Writes an interactive HTML map with support for gap segments.
/// - Parameters:
///   - tripId: Trip identifier for file naming
///   - segments: Route segments with type information
///   - to: Output file path
/// - Throws: `TripVisualizerError` on write failure
public func writeHTML(
    tripId: UUID,
    segments: [RouteSegment],
    to path: String
) throws
```

### Legacy writeHTML (Maintained)

```swift
/// Legacy method - creates single continuous segment internally.
/// - Parameters:
///   - tripId: Trip identifier
///   - waypoints: Waypoints to render
///   - to: Output file path
public func writeHTML(
    tripId: UUID,
    waypoints: [Waypoint],
    to path: String
) throws
```

---

## Segment Rendering Rules

### HTML/JavaScript Maps

| Segment Type | Rendering |
|--------------|-----------|
| `.continuous` | Solid polyline (existing style) |
| `.gap` | Dashed polyline with transparency |

**Dashed Line Style**:
```javascript
{
  strokeColor: '#808080',  // Gray
  strokeOpacity: 0.6,
  strokeWeight: routeWeight,
  icons: [{
    icon: {
      path: 'M 0,-1 0,1',
      strokeOpacity: 1,
      scale: 4
    },
    offset: '0',
    repeat: '20px'
  }]
}
```

### Static Maps (PNG)

| Segment Type | Rendering |
|--------------|-----------|
| `.continuous` | Blue polyline (existing) |
| `.gap` | Gray polyline (0x808080) |

**Note**: Google Static Maps API does not support dashed lines. We use color differentiation instead.

### URL Output

For URL output, gaps are noted in console output but the URL includes all waypoints in order.

---

## Input Contract

### RouteSegment Array

| Property | Type | Required | Validation |
|----------|------|----------|------------|
| segments | [RouteSegment] | Yes | Non-empty |

### Each RouteSegment

| Property | Type | Required | Validation |
|----------|------|----------|------------|
| waypoints | [Waypoint] | Yes | Non-empty |
| type | SegmentType | Yes | `.continuous` or `.gap` |
| sourceFragmentId | String? | No | For debugging |

---

## Output Contract

### HTML File

The generated HTML file includes:
1. Google Maps JavaScript API integration
2. Multiple polylines (one per segment)
3. Different styling for continuous vs gap segments
4. Legend indicating gap segments (if any exist)
5. Info window showing segment details on click

### PNG File

Static map image with:
1. All waypoints as a continuous path
2. Gap segments in gray color
3. Continuous segments in configured route color

---

## HTML Template Changes

### New Polyline Generation

```javascript
// For each segment
segments.forEach((segment, index) => {
  const path = segment.waypoints.map(w => ({
    lat: w.latitude,
    lng: w.longitude
  }));

  const polyline = new google.maps.Polyline({
    path: path,
    strokeColor: segment.type === 'gap' ? '#808080' : routeColor,
    strokeOpacity: segment.type === 'gap' ? 0.6 : 1.0,
    strokeWeight: routeWeight,
    map: map
  });

  if (segment.type === 'gap') {
    // Apply dashed line pattern
    polyline.setOptions({
      icons: [{
        icon: { path: 'M 0,-1 0,1', strokeOpacity: 1, scale: 4 },
        offset: '0',
        repeat: '20px'
      }]
    });
  }
});
```

### Legend (when gaps present)

```html
<div class="legend">
  <div><span class="solid-line"></span> Route data</div>
  <div><span class="dashed-line"></span> Gap (missing data)</div>
</div>
```

---

## Static Maps URL Changes

### Multiple Paths

When gaps exist, generate separate `path` parameters:

```
https://maps.googleapis.com/maps/api/staticmap?
  size=800x600&
  path=color:0x0000FF|weight:4|enc:...continuous1...&
  path=color:0x808080|weight:4|enc:...gap1...&
  path=color:0x0000FF|weight:4|enc:...continuous2...&
  key=API_KEY
```

**Note**: Multiple `path` parameters are supported by the Static Maps API.

---

## Example Usage

```swift
let generator = MapGenerator(apiKey: key, routeColor: "0000FF", routeWeight: 4)

let segments = [
    RouteSegment(waypoints: [w1, w2, w3], type: .continuous, sourceFragmentId: "log1"),
    RouteSegment(waypoints: [w3, w4], type: .gap, sourceFragmentId: nil),
    RouteSegment(waypoints: [w4, w5, w6], type: .continuous, sourceFragmentId: "log2")
]

try generator.writeHTML(tripId: tripId, segments: segments, to: outputPath)
```

---

## Backward Compatibility

The existing `writeHTML(tripId:waypoints:to:)` method continues to work by:
1. Wrapping waypoints in a single continuous RouteSegment
2. Delegating to the new `writeHTML(tripId:segments:to:)` method

```swift
public func writeHTML(tripId: UUID, waypoints: [Waypoint], to path: String) throws {
    let segment = RouteSegment(
        waypoints: waypoints,
        type: .continuous,
        sourceFragmentId: nil
    )
    try writeHTML(tripId: tripId, segments: [segment], to: path)
}
```
