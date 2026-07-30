import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:se_booking/config.dart';
import 'center_selection_screen.dart';

class TestCategoryScreen extends StatefulWidget {
  final int categoryId;
  final String categoryName;
  final String patientName;
  final String mobile;
  final String age;
  final String gender;
  final String address;
  final String paymentStatus;

  const TestCategoryScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
    required this.patientName,
    required this.mobile,
    required this.age,
    required this.gender,
    required this.address,
    this.paymentStatus = "Unpaid",
  });

  @override
  State<TestCategoryScreen> createState() => _TestCategoryScreenState();
}

class _TestCategoryScreenState extends State<TestCategoryScreen> {
  bool loading = true;

  List allTests = [];        // 🔹 All tests from API
  List filteredTests = [];  // 🔹 Filtered tests for search

  String searchText = '';

  @override
  void initState() {
    super.initState();
    loadTests();
  }

  Future<void> loadTests() async {
    final res = await http.get(
      Uri.parse(
        '${Config.baseUrl}/get_tests?category_id=${widget.categoryId}',
      ),
    );

    if (res.statusCode == 200) {
      allTests = jsonDecode(res.body);
      filteredTests = allTests;
    } else {
      allTests = [];
      filteredTests = [];
    }

    setState(() => loading = false);
  }

  void applySearch(String value) {
    searchText = value;

    if (value.isEmpty) {
      filteredTests = allTests;
    } else {
      filteredTests = allTests.where((t) {
        return t['test_name']
            .toString()
            .toLowerCase()
            .contains(value.toLowerCase());
      }).toList();
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.categoryName)),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // 🔍 SEARCH BAR
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search test name',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: applySearch,
            ),
          ),

          // 📋 TEST LIST
          Expanded(
            child: filteredTests.isEmpty
                ? const Center(
              child: Text(
                'No tests found',
                style: TextStyle(fontSize: 16),
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: filteredTests.length,
              itemBuilder: (_, i) {
                final t = filteredTests[i];

                return Card(
                  child: ListTile(
                    contentPadding:
                    const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFF1976D2),
                      child: Icon(
                        Icons.science,
                        color: Colors.white,
                      ),
                    ),
                    title: Text(
                      t['test_name'],
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: const Text(
                      'Tap to view available centers',
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CenterSelectionScreen(
                            testId: t['id'],
                            testName: t['test_name'],
                            patientName: widget.patientName,
                            mobile: widget.mobile,
                            age: widget.age,
                            gender: widget.gender,
                            address: widget.address,
                            paymentStatus: widget.paymentStatus,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
