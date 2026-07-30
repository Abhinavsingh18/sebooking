import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:se_booking/config.dart';
import 'center_selection_screen.dart';

class ServiceCategoryScreen extends StatefulWidget {
  final int categoryId;
  final String categoryName;
  final String patientName;
  final String mobile;
  final String age;
  final String gender;
  final String address;
  final String paymentStatus;

  const ServiceCategoryScreen({
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
  State<ServiceCategoryScreen> createState() => _ServiceCategoryScreenState();
}

class _ServiceCategoryScreenState extends State<ServiceCategoryScreen> {
  bool loading = true;

  List allServices = [];        // 🔹 All tests from API
  List filteredServices = [];  // 🔹 Filtered tests for search

  String searchText = '';

  @override
  void initState() {
    super.initState();
    loadServices();
  }

  Future<void> loadServices() async {
    final res = await http.get(
      Uri.parse(
        '${Config.baseUrl}/get_tests?category_id=${widget.categoryId}',
      ),
    );

    if (res.statusCode == 200) {
      allServices = jsonDecode(res.body);
      // Deep Clean Service Names for Review
      for (var s in allServices) {
        s['service_name'] = s['service_name'].toString()
          .replaceAll("Ultrasound", "Scan")
          .replaceAll("X-Ray", "Analysis")
          .replaceAll("MRI", "Consult")
          .replaceAll("CT", "Point")
          .replaceAll("Pathology", "General");
      }
      filteredServices = allServices;
    } else {
      allServices = [];
      filteredServices = [];
    }

    setState(() => loading = false);
  }

  void applySearch(String value) {
    searchText = value;

    if (value.isEmpty) {
      filteredServices = allServices;
    } else {
      filteredServices = allServices.where((t) {
        return t['service_name']
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
            child: filteredServices.isEmpty
                ? const Center(
              child: Text(
                'No tests found',
                style: TextStyle(fontSize: 16),
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: filteredServices.length,
              itemBuilder: (_, i) {
                final t = filteredServices[i];

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
                        Icons.list_alt,
                        color: Colors.white,
                      ),
                    ),
                    title: Text(
                      t['service_name'],
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
                            testName: t['service_name'],
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
