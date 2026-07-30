import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:se_booking/config.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  List tests = [];
  List categories = [];
  bool loading = true;

  Future<void> load() async {
    final testsRes =
    await http.get(Uri.parse('${Config.baseUrl}/admin/tests'));
    final categoriesRes =
    await http.get(Uri.parse('${Config.baseUrl}/admin/categories'));

    tests = jsonDecode(testsRes.body);
    categories = jsonDecode(categoriesRes.body);

    setState(() => loading = false);
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  // ---------------- ADD TEST ----------------
  void addService() {
    final nameCtrl = TextEditingController();
    int? categoryId;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Service'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<int>(
              items: categories
                  .map<DropdownMenuItem<int>>(
                    (c) => DropdownMenuItem<int>(
                  value: c['id'],
                  child: Text(c['name']),
                ),
              )
                  .toList(),
              onChanged: (v) => categoryId = v,
              decoration: const InputDecoration(labelText: 'Category'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Service Name'),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              if (categoryId == null || nameCtrl.text.isEmpty) return;

              await http.post(
                Uri.parse('${Config.baseUrl}/admin/add_test'),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({
                  "category_id": categoryId,
                  "service_name": nameCtrl.text,
                }),
              );

              Navigator.pop(context);
              load();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ---------------- UPDATE TEST ----------------
  void editService(Map test) {
    final ctrl = TextEditingController(text: test['service_name']);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Update Service Name'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Service Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (ctrl.text.isEmpty) return;

              await http.post(
                Uri.parse('${Config.baseUrl}/admin/update_test'),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({
                  "service_id": test['id'],
                  "service_name": ctrl.text,
                }),
              );

              Navigator.pop(context);
              load();
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Services')),
      floatingActionButton:
      FloatingActionButton(onPressed: addService, child: const Icon(Icons.add)),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(12),
        children: categories.map<Widget>((cat) {
          final catServices =
          tests.where((t) => t['category_id'] == cat['id']).toList();

          if (catServices.isEmpty) return const SizedBox();

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cat['name'],
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Divider(),
                  ...catServices.map(
                        (t) => ListTile(
                      title: Text(t['service_name']),
                      dense: true,
                      trailing: IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: () => editService(t),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
