# Map Enrichment Marker Contracts

**Feature**: 004-order-location-enrichment
**Date**: 2025-12-08

## Overview

This document defines the contracts for rendering enrichment markers on trip visualizations. Includes both HTML/JavaScript interactive maps and Static Maps API URLs.

---

## 1. Marker Types

### Existing Markers (unchanged)
| Type | Icon | Color | Purpose |
|------|------|-------|---------|
| Start | green-dot | Green | Trip start point |
| End | red-dot | Red | Trip end point |
| Delivery (route) | circle with number | Orange (#FF6600) | Actual delivery waypoints from route |

### New Enrichment Markers
| Type | Default Icon | Default Color | Purpose |
|------|--------------|---------------|---------|
| Delivery Destination | home | Purple (#9900FF) | Intended delivery address |
| Restaurant Origin | restaurant | Blue (#0066FF) | Restaurant pickup location |

---

## 2. HTML/JavaScript Map Contract

### Restaurant Origin Marker
```javascript
// Restaurant origin marker
new google.maps.Marker({
  position: {lat: {latitude}, lng: {longitude}},
  map: map,
  icon: {
    url: "http://maps.google.com/mapfiles/ms/icons/{icon}-dot.png",
    // OR for custom icon:
    path: google.maps.SymbolPath.BACKWARD_CLOSED_ARROW,
    scale: 8,
    fillColor: "#{color}",
    fillOpacity: 1,
    strokeColor: "#FFFFFF",
    strokeWeight: 2
  },
  title: "{restaurantName}",
  label: {
    text: "R",
    color: "white",
    fontWeight: "bold"
  }
});

// Info window with restaurant details
const restaurantInfoWindow = new google.maps.InfoWindow({
  content: `
    <div style="font-family: Arial, sans-serif; padding: 8px;">
      <strong>{restaurantName}</strong><br>
      {formattedAddress}
    </div>
  `
});
marker.addListener('click', () => restaurantInfoWindow.open(map, marker));
```

### Delivery Destination Marker
```javascript
// Delivery destination marker (per order)
new google.maps.Marker({
  position: {lat: {latitude}, lng: {longitude}},
  map: map,
  icon: {
    path: google.maps.SymbolPath.CIRCLE,
    scale: 10,
    fillColor: "#{color}",
    fillOpacity: 1,
    strokeColor: "#FFFFFF",
    strokeWeight: 2
  },
  title: "Delivery: {addressDisplayLine1}",
  label: {
    text: "D{orderNumber}",
    color: "white",
    fontSize: "10px",
    fontWeight: "bold"
  }
});

// Info window with delivery details
const deliveryInfoWindow = new google.maps.InfoWindow({
  content: `
    <div style="font-family: Arial, sans-serif; padding: 8px;">
      <strong>Delivery #{orderNumber}</strong><br>
      {address}<br>
      <small style="color: #666;">Order: {orderId}</small>
    </div>
  `
});
marker.addListener('click', () => deliveryInfoWindow.open(map, marker));
```

---

## 3. Static Maps API Contract

### Restaurant Marker URL Parameter
```
markers=icon:https://maps.google.com/mapfiles/kml/paddle/blu-blank.png|{latitude},{longitude}
```

Or with label:
```
markers=color:0x{color}|label:R|{latitude},{longitude}
```

### Delivery Destination Marker URL Parameter
```
markers=color:0x{color}|label:D{orderNumber}|{latitude},{longitude}
```

### Full URL Example
```
https://maps.googleapis.com/maps/api/staticmap?
  size=800x600&
  key={GOOGLE_MAPS_API_KEY}&
  path=color:0x0000FF|weight:4|enc:{encodedPath}&
  markers=color:green|label:S|{startLat},{startLng}&
  markers=color:red|label:E|{endLat},{endLng}&
  markers=color:0x0066FF|label:R|{restaurantLat},{restaurantLng}&
  markers=color:0x9900FF|label:D1|{delivery1Lat},{delivery1Lng}&
  markers=color:0x9900FF|label:D2|{delivery2Lat},{delivery2Lng}
```

---

## 4. Legend Contract

### HTML Legend (when enrichment markers present)
```html
<div class="legend">
  <div class="legend-item">
    <span class="solid-line"></span> Route data
  </div>
  <div class="legend-item">
    <span class="dashed-line"></span> Gap (missing data)
  </div>
  <div class="legend-item">
    <span class="marker-icon" style="background: #{restaurantColor};"></span> Restaurant
  </div>
  <div class="legend-item">
    <span class="marker-icon" style="background: #{deliveryDestColor};"></span> Delivery destination
  </div>
  <div class="legend-item">
    <span class="marker-icon" style="background: #FF6600;"></span> Route waypoint
  </div>
</div>
```

### CSS for Legend
```css
.legend {
  position: absolute;
  bottom: 20px;
  left: 20px;
  background: white;
  padding: 10px 15px;
  border-radius: 4px;
  box-shadow: 0 2px 6px rgba(0,0,0,0.3);
  font-family: Arial, sans-serif;
  font-size: 12px;
  z-index: 1;
}
.legend-item {
  display: flex;
  align-items: center;
  margin: 5px 0;
}
.marker-icon {
  width: 12px;
  height: 12px;
  border-radius: 50%;
  margin-right: 8px;
  border: 1px solid #ccc;
}
```

---

## 5. Swift Service Contract

### MapGenerator Extension
```swift
extension MapGenerator {
    /// Generates JavaScript for enrichment markers
    /// - Parameters:
    ///   - enrichment: EnrichmentResult with restaurant and delivery data
    ///   - config: Configuration with marker styles
    /// - Returns: JavaScript code string
    func generateEnrichmentMarkersJS(
        enrichment: EnrichmentResult,
        config: Configuration
    ) -> String

    /// Generates Static Maps URL with enrichment markers
    /// - Parameters:
    ///   - segments: Route segments
    ///   - enrichment: EnrichmentResult with restaurant and delivery data
    ///   - config: Configuration with marker styles
    ///   - width: Image width
    ///   - height: Image height
    /// - Returns: Static Maps URL
    func generateStaticMapsURL(
        segments: [RouteSegment],
        enrichment: EnrichmentResult,
        config: Configuration,
        width: Int,
        height: Int
    ) -> URL?
}
```

---

## 6. Visual Hierarchy

Markers should render in this z-order (top to bottom):
1. **Info windows** (when clicked)
2. **Restaurant marker** (unique, prominent)
3. **Delivery destination markers** (intended locations)
4. **Route delivery markers** (actual waypoints)
5. **Start/End markers**
6. **Route polylines**

This ensures that enrichment data is visually prominent for trip analysis.

---

## 7. Conditional Rendering

### When to show enrichment markers

| Condition | Restaurant Marker | Delivery Markers |
|-----------|-------------------|------------------|
| enrichment.status.locationDataFound = true | Show | - |
| enrichment.status.locationDataFound = false | Hide | - |
| enrichment.status.orderDataFound = true | - | Show all found |
| enrichment.status.orderDataFound = false | - | Hide all |
| deliveryDestinations.isEmpty | - | Hide section |

### Fallback behavior
- If no enrichment data available, map renders with existing markers only
- Legend adapts to show only relevant marker types

