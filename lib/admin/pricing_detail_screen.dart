import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:se_booking/config.dart';

class PricingDetailScreen extends StatefulWidget {
  final int centerId;
  final String centerName;

  const PricingDetailScreen({
    super.key,
    required this.centerId,
    required this.centerName,
  });

  @override
  State<PricingDetailScreen> createState() => _PricingDetailScreenState();
}

class _PricingDetailScreenState extends State<PricingDetailScreen> {
  List categories = [];
  List tests = [];
  bool loading = true;

  final Map<int, TextEditingController> priceCtrls = {};

  Future<void> load() async {
    try {
      final catRes = await http.get(
        Uri.parse('${Config.baseUrl}/admin/categories'),
      );

      final testRes = await http.get(
        Uri.parse(
          '${Config.baseUrl}/admin/pricing?center_id=${widget.centerId}',
        ),
      );

      categories = jsonDecode(catRes.body);
      tests = jsonDecode(testRes.body);

      for (var t in tests) {
        final int testId = t['test_id'];
        priceCtrls.putIfAbsent(
          testId,
              () => TextEditingController(
            text: t['price']?.toString() ?? '',
          ),
        );
      }

      setState(() => loading = false);
    } catch (e) {
      setState(() => loading = false);
      debugPrint('Pricing load error: $e');
    }
  }

  Future<void> save(int testId, bool enabled) async {
    await http.post(
      Uri.parse('${Config.baseUrl}/admin/set_price'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "center_id": widget.centerId,
        "test_id": testId,
        "price": double.tryParse(priceCtrls[testId]?.text ?? '') ?? 0,
        "enabled": enabled,
      }),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved')),
    );
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.centerName)),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(12),
        children: categories.map<Widget>((cat) {
          final catTests = tests
              .where((t) => t['category_id'] == cat['id'])
              .toList();

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
                  ...catTests.map((t) {
                    final int testId = t['test_id'];
                    final bool enabled = t['enabled'] ?? false;

                    return Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(t['test_name'])),
                            Switch(
                              value: enabled,
                              onChanged: (v) {
                                setState(() {
                                  t['enabled'] = v;
                                });
                              },
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: priceCtrls[testId],
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Price',
                                  prefixText: '₹ ',
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 90, // ✅ FIXED WIDTH
                              child: ElevatedButton(
                                onPressed: () => save(testId, t['enabled'] ?? false),
                                child: const Text('Save'),
                              ),
                            ),
                          ],
                        ),

                        const Divider(),
                      ],
                    );
                  }).toList(),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
