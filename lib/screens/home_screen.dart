import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'test_category_screen.dart';
import 'booking_history_screen.dart';
import 'about_us_screen.dart';
import '../center/center_login_screen.dart';
import '../admin/admin_login_screen.dart';
import '../config.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final nameController = TextEditingController();
  final mobileController = TextEditingController();

  List categories = [];
  bool loading = true;
  String? errorMessage;
  
  // Notice State
  String noticeText = "";
  bool noticeEnabled = false;


  @override
  void initState() {
    super.initState();
    loadCategories();
    _fetchNotice();
  }

  Future<void> _fetchNotice() async {
    try {
      final res = await http.get(Uri.parse('${Config.baseUrl}/get_notice'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            noticeText = data['text'] ?? "";
            noticeEnabled = data['enabled'] ?? false;
          });
        }
      }
    } catch (_) {}
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

  Future<void> _onRefresh() async {
    await Future.wait([
      loadCategories(),
      _fetchNotice(),
    ]);
  }

  @override
  void dispose() {
    nameController.dispose();
    mobileController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Book Diagnostic Test')),
      drawer: _buildDrawer(context),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            color: Colors.red, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              loading = true;
                              errorMessage = null;
                            });
                            loadCategories();
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _onRefresh,
                  child: SingleChildScrollView(

        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // NOTICE BOX
            if (noticeEnabled && noticeText.isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade800),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.campaign, color: Colors.amber),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        noticeText,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // HEADER

            // 🔵 HEADER CARD WITH HELPLINE
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.medical_services,
                      color: Color(0xFF1976D2),
                      size: 36,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Book Diagnostic Tests\n'
                            'Call Us for Assistance Anytime',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 10),

                          // 📞 HELPLINE
                          Row(
                            children: [
                              Icon(Icons.call, size: 16, color: Colors.green),
                              SizedBox(width: 6),
                              Text(
                                'Helpline Numbers',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 4),
                          Text(
                            '1800-889-9818,\n'
                                '90091-02672,\n'
                                '87709-05471,\n'
                                '97522-33328',
                            style: TextStyle(
                              fontSize: 23,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),


            const SizedBox(height: 20),

            const Text(
              'Patient Details',
              style:
              TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: nameController,
              decoration:
              const InputDecoration(labelText: 'Patient Name'),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: mobileController,
              keyboardType: TextInputType.phone,
              decoration:
              const InputDecoration(labelText: 'Mobile Number'),
            ),

            const SizedBox(height: 24),

            const Text(
              'Select Category',
              style:
              TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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

            const SizedBox(height: 30),

            ElevatedButton.icon(
              icon: const Icon(Icons.receipt_long),
              label: const Text('View Old Receipt'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const BookingHistoryScreen(),
                  ),
                );
              },
            ),

            
            const SizedBox(height: 40),
            
            // Developer Attribution
             Center(
                child: InkWell(
                  onTap: () async {
                     final Uri url = Uri.parse('https://bufferworks.in/');
                     if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                       debugPrint('Could not launch $url');
                     }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Developed by",
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              "Bufferworks",
                              style: TextStyle(
                                color: Color(0xFF1976D2), // Primary Blue
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.open_in_new,
                              size: 12,
                              color: Colors.grey.shade600,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
          ],
        ),
       ),
      ),
    );
  }

  // ================= CATEGORY CARD =================
  Widget _categoryCard(Map category) {
    return GestureDetector(
      onTap: () {
        final name = nameController.text.trim();
        final mobile = mobileController.text.trim();

        if (name.isEmpty || mobile.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Enter name & mobile')),
          );
          return;
        }

        // Clear fields AFTER validation
        nameController.clear();
        mobileController.clear();

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TestCategoryScreen(
              categoryId: category['id'],
              categoryName: category['name'],
              patientName: name,
              mobile: mobile,
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

  // ================= DRAWER =================
  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Color(0xFF1976D2)),
            child: Text(
              'SE Booking',
              style: TextStyle(color: Colors.white, fontSize: 22),
            ),
          ),

          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Book Test'),
            onTap: () => Navigator.pop(context),
          ),

          ListTile(
            leading: const Icon(Icons.receipt),
            title: const Text('Old Receipts'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const BookingHistoryScreen(),
                ),
              );
            },
          ),

          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About Us'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AboutUsScreen(),
                ),
              );
            },
          ),

          const Divider(),

          ListTile(
            leading: const Icon(Icons.local_hospital),
            title: const Text('Center Login'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CenterLoginScreen(),
                ),
              );
            },
          ),

          ListTile(
            leading: const Icon(Icons.admin_panel_settings),
            title: const Text('Admin Login'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AdminLoginScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
