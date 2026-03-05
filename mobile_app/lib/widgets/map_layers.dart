import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math' as math;

/// Builds the user location marker with optional heading arrow
Marker buildUserLocationMarker({required LatLng position, double? heading}) {
  return Marker(
    point: position,
    width: 60,
    height: 60,
    child: Stack(
      alignment: Alignment.center,
      children: [
        if (heading != null)
          Transform.rotate(
            angle: heading * (math.pi / 180),
            child: const Icon(
              Icons.navigation,
              color: Colors.blueAccent,
              size: 50,
              shadows: [Shadow(color: Colors.white, blurRadius: 10)],
            ),
          ),
        if (heading == null)
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 3,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

/// Builds small white circle markers at each polygon vertex
List<Marker> buildPolygonVertexMarkers(List<LatLng> points) {
  return points
      .map(
        (point) => Marker(
          point: point,
          width: 12,
          height: 12,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.green, width: 2),
            ),
          ),
        ),
      )
      .toList();
}
