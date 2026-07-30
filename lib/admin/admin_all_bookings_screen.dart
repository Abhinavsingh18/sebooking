import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import 'package:se_booking/config.dart';
import '../services/api_service.dart';

class AdminAllBookingsScreen extends StatefulWidget {
  const AdminAllBookingsScreen({super.key});

  @override
  State<AdminAllBookingsScreen> createState() =>
      _AdminAllBookingsScreenState();
}

class _AdminAllBookingsScreenState extends State<AdminAllBookingsScreen> {
  List allBookings = [];
  List filteredBookings = [];
  bool loading = true;

  String searchText = '';
  String dateFilter = 'today'; // today | all | custom
  DateTime? selectedDate;
  String? agentFilter;
  String? centerFilter;

  List<String> uniqueAgents = [];
  List<String> uniqueCenters = [];

  @override
  void initState() {
    super.initState();
    loadBookings();
  }

  Future<void> loadBookings() async {
    setState(() => loading = true);

    final res = await http.get(
      Uri.parse('${Config.baseUrl}/admin/bookings'),
    );

    if (res.statusCode == 200) {
      allBookings = jsonDecode(res.body);
      
      uniqueAgents = allBookings
          .map((e) => e['booked_by'].toString())
          .toSet()
          .toList();
      uniqueCenters = allBookings
          .map((e) => e['center_name'].toString())
          .toSet()
          .toList();
    } else {
      allBookings = [];
    }

    applyFilters();
    setState(() => loading = false);
  }

  void applyFilters() {
    final now = DateTime.now();

    filteredBookings = allBookings.where((b) {
      final bookingTime =
      DateTime.fromMillisecondsSinceEpoch(b['created_at'] * 1000);

      bool matchesDate = false;
      if (dateFilter == 'today') {
        matchesDate = bookingTime.year == now.year &&
            bookingTime.month == now.month &&
            bookingTime.day == now.day;
      } else if (dateFilter == 'all') {
        matchesDate = true;
      } else if (dateFilter == 'custom' && selectedDate != null) {
        matchesDate = bookingTime.year == selectedDate!.year &&
            bookingTime.month == selectedDate!.month &&
            bookingTime.day == selectedDate!.day;
      }

      final matchesSearch = searchText.isEmpty ||
          b['patient_name']
              .toString()
              .toLowerCase()
              .contains(searchText.toLowerCase()) ||
          b['mobile']
              .toString()
              .toLowerCase()
              .contains(searchText.toLowerCase()) ||
          b['booking_id']
              .toString()
              .toLowerCase()
              .contains(searchText.toLowerCase());

      final matchesAgent = agentFilter == null || b['booked_by'] == agentFilter;
      final matchesCenter = centerFilter == null || b['center_name'] == centerFilter;

      return matchesDate && matchesSearch && matchesAgent && matchesCenter;
    }).toList();
  }
  
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2025),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        selectedDate = picked;
        dateFilter = 'custom';
        applyFilters();
      });
    }
  }

  Future<void> _verifyPayment(Map b) async {
    final price = double.tryParse(b['price'].toString()) ?? 0;
    
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Verify Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min, 
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             const Text('Has the full amount been received in the company account (Admin)?'),
             const SizedBox(height: 12),
             Text('Tracking ID / Status:\n${b['payment_status']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey)),
             const SizedBox(height: 12),
             Text('Amount to Verify: ₹${price.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              // Mark as collected by Admin (Company Account)
              await ApiService.updatePaymentDetails(
                  bookingId: b['booking_id'],
                  agentCollected: 0.0,
                  centerCollected: 0.0,
                  adminCollected: price,
                  updatedByName: "Admin (Verified Online)",
              );
              if (mounted) Navigator.pop(ctx);
              loadBookings();
            },
            child: const Text('Confirm Received', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Center Bookings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: loadBookings,
          ),
        ],
      ),
      body: Column(
        children: [
          // 🔍 SEARCH
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search by name / mobile / booking ID',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) {
                searchText = v;
                setState(() => applyFilters());
              },
            ),
          ),

          // 📅 DATE FILTER
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
              children: [
                ChoiceChip(
                  label: const Text('Today'),
                  selected: dateFilter == 'today',
                  onSelected: (_) {
                    setState(() {
                      dateFilter = 'today';
                      applyFilters();
                    });
                  },
                ),
                const SizedBox(width: 8),
                ActionChip(
                  label: Text(dateFilter == 'custom' 
                      ? DateFormat('dd MMM').format(selectedDate!) 
                      : 'Pick Date'),
                  avatar: const Icon(Icons.calendar_today, size: 16),
                  onPressed: _pickDate,
                  backgroundColor: dateFilter == 'custom' ? Colors.blue.withOpacity(0.2) : null,
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('All'),
                  selected: dateFilter == 'all',
                  onSelected: (_) {
                    setState(() {
                      dateFilter = 'all';
                      applyFilters();
                    });
                  },
                ),
              ],
            ),
          ),
        ),
          
          const SizedBox(height: 12),

          // 🧹 ADDITIONAL FILTERS (Agent & Center)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _buildDropdown(
                    "Agent",
                    agentFilter,
                    uniqueAgents,
                    (v) => setState(() {
                      agentFilter = v;
                      applyFilters();
                    })),
                const SizedBox(width: 8),
                _buildDropdown(
                    'Center',
                    centerFilter,
                    uniqueCenters,
                    (v) => setState(() {
                      centerFilter = v;
                      applyFilters();
                    })),
                if (agentFilter != null || centerFilter != null)
                  IconButton(
                      onPressed: () {
                        setState(() {
                          agentFilter = null;
                          centerFilter = null;
                          applyFilters();
                        });
                      },
                      icon: const Icon(Icons.clear, color: Colors.red)),
              ],
            ),
          ),

          
          const SizedBox(height: 12),

          // 📊 SUMMARY CARD
          if (!loading)
            Builder(
              builder: (_) {
                int total = filteredBookings.length;
                int paidByAgent = 0;
                int paidByCenter = 0;
                int unpaid = 0;

                for (var b in filteredBookings) {
                  String status = b['payment_status'] ?? 'Unpaid';
                  
                  double agentColl = double.tryParse(b['agent_collected'].toString()) ?? 0;
                  double centerColl = double.tryParse(b['center_collected'].toString()) ?? 0;
                  double adminColl = double.tryParse(b['admin_collected'].toString()) ?? 0;

                  // Pending verification counts as Unpaid until verified
                  if (status == 'Unpaid' || status.contains('Pending')) {
                    unpaid++;
                  } else {
                    if (centerColl > 0 || adminColl > 0) {
                      paidByCenter++;
                    } else {
                      paidByAgent++;
                    }
                  }
                }

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      _summaryCard('Total', '$total', Colors.blue),
                      _summaryCard('Paid (Agent)', '$paidByAgent', Colors.purple),
                      _summaryCard('Paid (Admin/Online)', '$paidByCenter', Colors.green),
                      _summaryCard('Unpaid', '$unpaid', Colors.orange),
                    ],
                  ),
                );
              },
            ),

          const SizedBox(height: 8),

          // 📋 BOOKINGS
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : filteredBookings.isEmpty
                ? const Center(child: Text('No bookings found'))
                : ListView.builder(
              itemCount: filteredBookings.length,
              itemBuilder: (_, i) {
                final b = filteredBookings[i];
                final date = DateFormat('dd MMM yyyy, hh:mm a')
                    .format(
                  DateTime.fromMillisecondsSinceEpoch(
                      b['created_at'] * 1000),
                );

                return Card(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        // 🏥 CENTER
                        Text(
                          b['center_name'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const Divider(),

                        // 👤 PATIENT
                        Text(
                          b['patient_name'],
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'Mobile: ${b['mobile']}',
                          style: const TextStyle(fontSize: 13),
                        ),

                        const SizedBox(height: 6),

                        // 🧪 TEST
                        Text(
                          b['test_name'],
                          style: const TextStyle(fontSize: 13),
                        ),

                        const SizedBox(height: 6),

                        // 🆔 BOOKING ID + DATE
                        Text(
                          'Booking ID: ${b['booking_id']}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey),
                        ),
                        Text(
                          date,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        // 🆕 New Patient Details
                        if (b['age'] != null || b['address'] != null) ...[
                          Text(
                            '${b['age'] ?? 'N/A'} Yrs | ${b['gender'] ?? 'N/A'}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                          const SizedBox(height: 2),
                           Text(
                            '${b['address'] ?? 'No Address'}',
                             style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                             maxLines: 2, 
                             overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                        ],
                                                      // 🆕 Booked By & Payment Details
                            Builder(
                              builder: (context) {
                                final price = double.tryParse(b['price'].toString()) ?? 0;
                                final agentColl = double.tryParse(b['agent_collected'].toString()) ?? 0;
                                final centerColl = double.tryParse(b['center_collected'].toString()) ?? 0;
                                final adminColl = double.tryParse(b['admin_collected'].toString()) ?? 0;
                                final totalPaid = agentColl + centerColl + adminColl;
                                final due = price - totalPaid;
                                final payStatus = b['payment_status'] ?? 'Unpaid';
                                final isPending = payStatus.toString().contains('Pending');

                                return Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isPending ? Colors.orange.shade50 : Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: isPending ? Colors.orange.shade200 : Colors.grey.shade200),
                                  ),
                                  child: Column(
                                    children: [
                                      _infoRow('Booked By', b['booked_by'] ?? 'Customer'),
                                      
                                      if (isPending) ...[
                                         Container(
                                           padding: const EdgeInsets.all(8),
                                           decoration: BoxDecoration(
                                             color: Colors.white,
                                             borderRadius: BorderRadius.circular(6),
                                             border: Border.all(color: Colors.orange.shade100),
                                           ),
                                           child: Column(
                                             children: [
                                               Row(children: [
                                                  const Icon(Icons.warning_amber, color: Colors.deepOrange, size: 18),
                                                  const SizedBox(width: 8),
                                                  Expanded(child: Text(payStatus, style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold, fontSize: 13))),
                                               ]),
                                               const SizedBox(height: 8),
                                               const Text("User claims to have paid full amount via UPI.", style: TextStyle(fontSize: 12, color: Colors.grey)),
                                               const SizedBox(height: 8),
                                               SizedBox(
                                                 width: double.infinity,
                                                 height: 36,
                                                 child: ElevatedButton.icon(
                                                   style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                                   icon: const Icon(Icons.check_circle, size: 16),
                                                   label: const Text('Verify & Mark Paid'),
                                                   onPressed: () => _verifyPayment(b),
                                                 ),
                                               ),
                                             ],
                                           ),
                                         ),
                                      ] else ...[
                                          const Divider(height: 12),
                                          _infoRow('Price', '₹${price.toStringAsFixed(0)}'),
                                          const SizedBox(height: 4),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Text('Paid', style: TextStyle(color: Colors.green, fontSize: 13)),
                                              Text(
                                                '₹${totalPaid.toStringAsFixed(0)} (Ag: ${agentColl.toInt()} | Ctr: ${centerColl.toInt()} | Adm: ${adminColl.toInt()})',
                                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 12),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text('Due', style: TextStyle(color: due > 0 ? Colors.red : Colors.grey, fontSize: 13)),
                                              Text(
                                                '₹${due.toStringAsFixed(0)}',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold, 
                                                  color: due > 0 ? Colors.red : Colors.grey,
                                                  fontSize: 13
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          SizedBox(
                                            width: double.infinity,
                                            height: 32,
                                            child: OutlinedButton.icon(
                                              icon: const Icon(Icons.edit, size: 14),
                                              label: const Text('Update Payment', style: TextStyle(fontSize: 12)),
                                              onPressed: () => _openPaymentDialog(b),
                                            ),
                                          ),
                                      ],
                                    ],
                                  ),
                                );
                              }
                            ),

                        const SizedBox(height: 8),

                        // ✅ STATUS
                        Text(
                          'Status: ${b['status']}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: b['status'] == 'Done'
                                ? Colors.green
                                : Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildDropdown(String label, String? value, List<String> items, Function(String?) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          hint: Text(label),
          value: value,
          isDense: true,
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Future<void> _openPaymentDialog(Map b) async {
    final price = double.tryParse(b['price'].toString()) ?? 0;
    final agentColl = double.tryParse(b['agent_collected'].toString()) ?? 0;
    final centerColl = double.tryParse(b['center_collected'].toString()) ?? 0;
    final adminColl = double.tryParse(b['admin_collected'].toString()) ?? 0;

    final agentController = TextEditingController(text: agentColl.toStringAsFixed(0));
    final centerController = TextEditingController(text: centerColl.toStringAsFixed(0));
    final adminController = TextEditingController(text: adminColl.toStringAsFixed(0));

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Update Payment (Admin Override)'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _infoRow('Total Price', '₹${price.toStringAsFixed(0)}'),
                const Divider(),
                const SizedBox(height: 10),
                TextField(
                  controller: agentController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Agent Collection',
                    helperText: 'Collected by Agent',
                    prefixText: '₹ ',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: centerController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Center Collection',
                     helperText: 'Collected by Center',
                    prefixText: '₹ ',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: adminController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Admin/Online Collection',
                     helperText: 'Collected by Company',
                    prefixText: '₹ ',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final ac = double.tryParse(agentController.text) ?? 0;
                final cc = double.tryParse(centerController.text) ?? 0;
                final admc = double.tryParse(adminController.text) ?? 0;

                await ApiService.updatePaymentDetails(
                  bookingId: b['booking_id'],
                  agentCollected: ac,
                  centerCollected: cc,
                  adminCollected: admc,
                  updatedByName: "Admin",
                );
                if (mounted) Navigator.pop(ctx);
                loadBookings();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Widget _infoRow(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(k), Text(v, style: const TextStyle(fontWeight: FontWeight.bold))],
      ),
    );
  }

  Widget _summaryCard(String title, String count, Color color) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(right: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: color, width: 3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(title, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(count, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
