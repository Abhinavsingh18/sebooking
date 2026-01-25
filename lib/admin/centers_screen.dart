import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:se_booking/config.dart';
import 'map_picker_screen.dart';

class CentersScreen extends StatefulWidget {
  const CentersScreen({super.key});

  @override
  State<CentersScreen> createState() => _CentersScreenState();
}

class _CentersScreenState extends State<CentersScreen> {
  List centers = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadCenters();
  }

  Future<void> loadCenters() async {
    final res = await http.get(
      Uri.parse('${Config.baseUrl}/admin/centers'),
    );

    if (res.statusCode == 200) {
      centers = jsonDecode(res.body);
    } else {
      centers = [];
    }

    setState(() => loading = false);
  }

  Future<void> toggleCenter(int centerId, bool enabled) async {
    await http.post(
      Uri.parse('${Config.baseUrl}/admin/toggle_center'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "center_id": centerId,
        "enabled": enabled,
      }),
    );
    loadCenters();
  }

  void showCenterDialog({Map? center}) {
    final bool isEdit = center != null;

    final idCtrl =
        TextEditingController(text: isEdit ? center['id'].toString() : '');
    final nameCtrl =
        TextEditingController(text: isEdit ? center['center_name'] : '');
    final addressCtrl =
        TextEditingController(text: isEdit ? center['address'] : '');
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();

    double? lat = center?['lat'];
    double? lng = center?['lng'];

    // 🕒 TIMINGS STATE
    List<Map<String, dynamic>> timings = [];
    if (isEdit && center['timings'] != null) {
      timings = List<Map<String, dynamic>>.from(center['timings']);
    }

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(isEdit ? 'Edit Center' : 'Add Center'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: idCtrl,
                    enabled: !isEdit,
                    decoration: const InputDecoration(labelText: 'Center ID'),
                  ),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Center Name'),
                  ),
                  TextField(
                    controller: addressCtrl,
                    decoration: const InputDecoration(labelText: 'Address'),
                  ),

                  const SizedBox(height: 10),

                  // 🗺 MAP PICKER
                  ElevatedButton.icon(
                    icon: const Icon(Icons.map),
                    label: Text(
                      lat == null
                          ? 'Select Location on Map'
                          : 'Change Location on Map',
                    ),
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MapPickerScreen(),
                        ),
                      );

                      if (result != null) {
                        setState(() {
                          lat = result['lat'];
                          lng = result['lng'];
                        });
                      }
                    },
                  ),

                  if (lat != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Lat: ${lat!.toStringAsFixed(5)}, Lng: ${lng!.toStringAsFixed(5)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),

                  const Divider(),

                  // 🕒 TIMINGS SECTION
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Center Timings',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle, color: Colors.blue),
                        onPressed: () {
                          _showAddTimingDialog(context, (newTiming) {
                            setState(() {
                              timings.add(newTiming);
                            });
                          });
                        },
                      ),
                    ],
                  ),
                  ...timings.asMap().entries.map((entry) {
                    final int idx = entry.key;
                    final Map t = entry.value;
                    return Card(
                      color: Colors.grey.shade50,
                      child: ListTile(
                        dense: true,
                        title: Text(t['label'] ?? ''),
                        subtitle: Text(t['time'] ?? ''),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              timings.removeAt(idx);
                            });
                          },
                        ),
                      ),
                    );
                  }),

                  const Divider(),

                  TextField(
                    controller: userCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Login Username'),
                  ),
                  TextField(
                    controller: passCtrl,
                    obscureText: true,
                    decoration:
                        const InputDecoration(labelText: 'Login Password'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                child: const Text('Save'),
                onPressed: () async {
                  final int centerId = int.parse(idCtrl.text);

                  if (isEdit) {
                    // 🔹 UPDATE CENTER
                    await http.post(
                      Uri.parse('${Config.baseUrl}/admin/update_center'),
                      headers: {'Content-Type': 'application/json'},
                      body: jsonEncode({
                        "id": centerId,
                        "center_name": nameCtrl.text,
                        "address": addressCtrl.text,
                        "lat": lat,
                        "lng": lng,
                        "timings": timings,
                      }),
                    );

                    // 🔹 UPDATE LOGIN (OPTIONAL)
                    if (userCtrl.text.isNotEmpty && passCtrl.text.isNotEmpty) {
                      await http.post(
                        Uri.parse('${Config.baseUrl}/admin/update_center_user'),
                        headers: {'Content-Type': 'application/json'},
                        body: jsonEncode({
                          "center_id": centerId,
                          "username": userCtrl.text,
                          "password": passCtrl.text,
                        }),
                      );
                    }
                  } else {
                    // 🔹 ADD CENTER
                    await http.post(
                      Uri.parse('${Config.baseUrl}/admin/add_center'),
                      headers: {'Content-Type': 'application/json'},
                      body: jsonEncode({
                        "id": centerId,
                        "center_name": nameCtrl.text,
                        "address": addressCtrl.text,
                        "lat": lat,
                        "lng": lng,
                        "timings": timings,
                        "enabled": true,
                      }),
                    );

                    // 🔹 CREATE LOGIN
                    await http.post(
                      Uri.parse('${Config.baseUrl}/admin/create_center_user'),
                      headers: {'Content-Type': 'application/json'},
                      body: jsonEncode({
                        "center_id": centerId,
                        "username": userCtrl.text,
                        "password": passCtrl.text,
                      }),
                    );
                  }

                  Navigator.pop(context);
                  loadCenters();
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddTimingDialog(
      BuildContext context, Function(Map<String, dynamic>) onAdd) {
    final labelCtrl = TextEditingController();
    final timeCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Timing'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelCtrl,
              decoration: const InputDecoration(
                  labelText: 'Label (e.g. Weekdays, 24/7)'),
            ),
            TextField(
              controller: timeCtrl,
              decoration: const InputDecoration(
                  labelText: 'Time (e.g. 9:00 AM - 5:00 PM)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (labelCtrl.text.isNotEmpty && timeCtrl.text.isNotEmpty) {
                onAdd({
                  "label": labelCtrl.text,
                  "time": timeCtrl.text,
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Centers')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showCenterDialog(),
        child: const Icon(Icons.add),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
        itemCount: centers.length,
        itemBuilder: (_, i) {
          final c = centers[i];
          final bool enabled = c['enabled'] ?? true;

          return Card(
            child: ListTile(
              title: Text(c['center_name'] ?? ''),
              subtitle: Text(c['address'] ?? ''),
              leading: Switch(
                value: enabled,
                activeColor: Colors.green,
                onChanged: (v) => toggleCenter(c['id'], v),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => showCenterDialog(center: c),
              ),
            ),
          );
        },
      ),
    );
  }
}
