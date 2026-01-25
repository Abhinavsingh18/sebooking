import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';
import 'confirm_booking_screen.dart';

class CenterSelectionScreen extends StatefulWidget {
  final int testId;
  final String testName;
  final String patientName;
  final String mobile;

  const CenterSelectionScreen({
    super.key,
    required this.testId,
    required this.testName,
    required this.patientName,
    required this.mobile,
  });

  @override
  State<CenterSelectionScreen> createState() =>
      _CenterSelectionScreenState();
}

class _CenterSelectionScreenState extends State<CenterSelectionScreen> {
  bool loading = true;
  List centers = [];

  double? userLat;
  double? userLng;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _getUserLocation();
    await _loadCenters();
  }

  // ================= LOCATION =================
  Future<void> _getUserLocation() async {
    LocationPermission permission =
    await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    userLat = pos.latitude;
    userLng = pos.longitude;
  }

  // ================= LOAD CENTERS =================
  Future<void> _loadCenters() async {
    final data = await ApiService.getCenters(widget.testId);
    centers = data.where((c) => c['enabled'] == true).toList();
    setState(() => loading = false);
  }

  // ================= DISTANCE =================
  double _distanceKm(
      double lat1, double lon1, double lat2, double lon2) {
    const r = 6371;
    final dLat = _deg(lat2 - lat1);
    final dLon = _deg(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg(lat1)) *
            cos(_deg(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  double _deg(double d) => d * pi / 180;

  // ================= OPEN MAP =================
  Future<void> _openMap(double lat, double lng) async {
    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Center')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: centers.length,
        itemBuilder: (_, i) {
          final c = centers[i];
          final lat = c['lat'];
          final lng = c['lng'];

          double? dist;
          if (userLat != null && lat != null) {
            dist = _distanceKm(
                userLat!, userLng!, lat, lng);
          }

          return Card(
            child: ListTile(
              title: Text(c['center_name']),
              subtitle: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(c['address']),
                  Text('₹${c['price']}'),
                  
                  // 🕒 DISPLAY TIMINGS
                  if (c['timings'] != null && (c['timings'] as List).isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: (c['timings'] as List).map((t) {
                          return Row(
                            children: [
                              const Icon(Icons.access_time,
                                  size: 12, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                '${t['label']}: ${t['time']}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),

                  if (dist != null)
                    Text(
                      '${dist.toStringAsFixed(1)} km away',
                      style: const TextStyle(color: Colors.green),
                    ),
                ],
              ),
              trailing: lat == null
                  ? null
                  : IconButton(
                icon: const Icon(Icons.map),
                onPressed: () =>
                    _openMap(lat, lng),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ConfirmBookingScreen(
                      testId: widget.testId,
                      testName: widget.testName,
                      centerId: c['center_id'],
                      centerName: c['center_name'],
                      price: double.parse(
                          c['price'].toString()),
                      patientName:
                      widget.patientName,
                      mobile: widget.mobile,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
