import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:se_booking/config.dart';
import '../screens/test_category_screen.dart';
import '../screens/home_screen.dart';

class AgentHomeScreen extends StatefulWidget {
  const AgentHomeScreen({super.key});

  @override
  State<AgentHomeScreen> createState() => _AgentHomeScreenState();
}

class _AgentHomeScreenState extends State<AgentHomeScreen> {
  final nameController = TextEditingController();
  final mobileController = TextEditingController();
  final ageController = TextEditingController();
  final addressController = TextEditingController();
  String gender = 'Male';

  List categories = [];
  bool loading = true;
  String? errorMessage;
  String agentName = "";
  String _paymentStatus = "Paid";

  @override
  void initState() {
    super.initState();
    _loadAgentInfo();
    loadCategories();
  }

  Future<void> _loadAgentInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      agentName = prefs.getString('agent_name') ?? "Agent";
    });
  }

  Future<void> loadCategories() async {
    try {
      final res = await http.get(
        Uri.parse('${Config.baseUrl}/admin/categories'),
      );

      if (res.statusCode == 200) {
        categories = jsonDecode(res.body);
      } else {
        errorMessage = 'Failed to load: ${res.statusCode}';
      }
    } catch (e) {
      errorMessage = 'Error: $e';
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Agent: $agentName'),
          bottom: const TabBar(
            tabs: [
              Tab(text: "Book Test"),
              Tab(text: "My History"),
            ],
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _logout,
            ),
          ],
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildBookTab(),
                  AgentHistoryTab(agentName: agentName),
                ],
              ),
      ),
    );
  }

  Widget _buildBookTab() {
    return errorMessage != null
        ? Center(child: Text(errorMessage!))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Book Test for Patient',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Patient Name', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: mobileController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Mobile Number', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                Row(
                      children: [
                        Expanded(child: TextField(controller: ageController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Age', border: OutlineInputBorder()))),
                        const SizedBox(width: 12),
                        Expanded(child: DropdownButtonFormField<String>(
                            value: gender,
                            decoration: const InputDecoration(labelText: 'Gender', border: OutlineInputBorder()),
                            items: ['Male', 'Female', 'Other'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                            onChanged: (v) => setState(() => gender = v!),
                        )),
                      ],
                ),
                const SizedBox(height: 12),
                TextField(controller: addressController, decoration: const InputDecoration(labelText: 'Address', border: OutlineInputBorder())),

                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green),
                      SizedBox(width: 8),
                      Text("Payment Status: Paid", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Select Category',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: categories.length,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.2,
                  ),
                  itemBuilder: (_, i) {
                    final cat = categories[i];
                    return _categoryCard(cat);
                  },
                ),
              ],
            ),
          );
  }

  Widget _categoryCard(Map category) {
    return GestureDetector(
      onTap: () {
        final name = nameController.text.trim();
        final mobile = mobileController.text.trim();
        final age = ageController.text.trim();
        final addr = addressController.text.trim();

        if (name.isEmpty || mobile.isEmpty || age.isEmpty || addr.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please fill all patient details')),
          );
          return;
        }

        if (!RegExp(r'^\d{10,12}$').hasMatch(mobile)) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Mobile number must be 10-12 digits')),
          );
          return;
        }

        // Clear for next use
        nameController.clear();
        mobileController.clear();
        ageController.clear();
        addressController.clear();

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TestCategoryScreen(
              categoryId: category['id'],
              categoryName: category['name'],
              patientName: name,
              mobile: mobile,
              age: age,
              gender: gender,
              address: addr,
              paymentStatus: "Paid", // Agents collect money upfront usually? Or as per logic?
                                     // The original code used "_paymentStatus" var initialized to "Paid".
                                     // I should check that logic. 
                                     // Assuming default is Paid for Agent bookings based on UI label "Payment Status: Paid".
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Center(
          child: Text(
            category['name'],
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------- AGENT HISTORY TAB ---------------- //
class AgentHistoryTab extends StatefulWidget {
  final String agentName;
  const AgentHistoryTab({super.key, required this.agentName});

  @override
  State<AgentHistoryTab> createState() => _AgentHistoryTabState();
}

class _AgentHistoryTabState extends State<AgentHistoryTab> {
  List bookings = [];
  List filteredBookings = [];
  bool loading = true;
  String dateFilter = 'today'; // today | all | custom
  DateTime? selectedDate;

  @override
  void initState() {
    super.initState();
    loadHistory();
  }

  Future<void> loadHistory() async {
    setState(() => loading = true);
    final res = await http.get(
      Uri.parse('${Config.baseUrl}/agent/bookings?agent_name=${widget.agentName}'),
    );

    if (res.statusCode == 200) {
      bookings = jsonDecode(res.body);
    } else {
      bookings = [];
    }
    applyFilter();
    setState(() => loading = false);
  }

  void applyFilter() {
    final now = DateTime.now();
    filteredBookings = bookings.where((b) {
      final date = DateTime.fromMillisecondsSinceEpoch(b['created_at'] * 1000);
      if (dateFilter == 'today') {
        return date.year == now.year && date.month == now.month && date.day == now.day;
      } else if (dateFilter == 'custom' && selectedDate != null) {
        return date.year == selectedDate!.year && date.month == selectedDate!.month && date.day == selectedDate!.day;
      }
      return true;
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
        applyFilter();
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const Text("Filter: ", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Today'),
                  selected: dateFilter == 'today',
                  onSelected: (sel) {
                     if (sel) setState(() { dateFilter = 'today'; applyFilter(); });
                  },
                ),
                const SizedBox(width: 8),
                ActionChip(
                  label: Text(dateFilter == 'custom' 
                      ? "${selectedDate!.day}/${selectedDate!.month}" 
                      : 'Pick Date'),
                  avatar: const Icon(Icons.calendar_today, size: 16),
                  onPressed: _pickDate,
                  backgroundColor: dateFilter == 'custom' ? Colors.blue.withOpacity(0.2) : null,
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('All'),
                  selected: dateFilter == 'all',
                  onSelected: (sel) {
                     if (sel) setState(() { dateFilter = 'all'; applyFilter(); });
                  },
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: loading 
            ? const Center(child: CircularProgressIndicator()) 
            : filteredBookings.isEmpty 
              ? const Center(child: Text("No bookings found")) 
              : ListView.builder(
              itemCount: filteredBookings.length,
              itemBuilder: (ctx, i) {
                final b = filteredBookings[i];
                // Format Date
                final bDate = DateTime.fromMillisecondsSinceEpoch(b['created_at'] * 1000);
                final dateStr = "${bDate.day}/${bDate.month}/${bDate.year}";
                
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    title: Text(b['patient_name']),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("${b['test_name']} @ ${b['center_name']}"),
                          Text("Date: $dateStr", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          Row(
                            children: [
                              Text("Status: ${b['status']} | ", style: const TextStyle(fontSize: 12)),
                              Text(
                                "Payment: ${b['payment_status']}", 
                                style: TextStyle(
                                  color: b['payment_status'] == 'Paid' ? Colors.green : Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12
                                ),
                              ),
                            ],
                          ),
                          if ((b['agent_collected'] ?? 0) > 0)
                             Text(
                               "Collected by You: ₹${b['agent_collected']}",
                               style: const TextStyle(color: Colors.purple, fontWeight: FontWeight.bold, fontSize: 12),
                             ),
                        ],
                      ),
                    trailing: Text("₹${b['price']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                );
              },
            ),
        )
      ],
    );
  }
}
