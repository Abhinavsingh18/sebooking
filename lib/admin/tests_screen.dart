import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:se_booking/config.dart';

class TestsScreen extends StatefulWidget {
  const TestsScreen({super.key});

  @override
  State<TestsScreen> createState() => _TestsScreenState();
}

class _TestsScreenState extends State<TestsScreen> {
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
  void addTest() {
    final nameCtrl = TextEditingController();
    int? categoryId;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Test'),
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
              decoration: const InputDecoration(labelText: 'Test Name'),
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
                  "test_name": nameCtrl.text,
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
  void editTest(Map test) {
    final ctrl = TextEditingController(text: test['test_name']);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Update Test Name'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Test Name'),
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
                  "test_id": test['id'],
                  "test_name": ctrl.text,
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
      appBar: AppBar(title: const Text('Tests')),
      floatingActionButton:
      FloatingActionButton(onPressed: addTest, child: const Icon(Icons.add)),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(12),
        children: categories.map<Widget>((cat) {
          final catTests =
          tests.where((t) => t['category_id'] == cat['id']).toList();

          if (catTests.isEmpty) return const SizedBox();

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
                  ...catTests.map(
                        (t) => ListTile(
                      title: Text(t['test_name']),
                      dense: true,
                      trailing: IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: () => editTest(t),
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
