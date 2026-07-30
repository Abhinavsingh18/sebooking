import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'centers_screen.dart';
import 'categories_screen.dart';
import 'tests_screen.dart';
import 'pricing_centers_screen.dart';
import 'admin_all_bookings_screen.dart';
import 'manage_notice_screen.dart';
import 'manage_agents_screen.dart';
import 'admin_stats_screen.dart';
import '../screens/home_screen.dart';



class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear(); // Or remove specific keys
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _item(context, 'Centers & Logins', const CentersScreen()),
          _item(context, 'Categories', const CategoriesScreen()),
          _item(context, 'Tests', const TestsScreen()),
          _item(context, 'Pricing (Center Wise)', const PricingCentersScreen()),
          _item(context, 'All Center Bookings', const AdminAllBookingsScreen()),
          _item(context, 'Manage Home Notice', const ManageNoticeScreen()),
          _item(context, 'Manage Agents', const ManageAgentsScreen()),
          _item(context, 'Report (Center Wise Stats)', const AdminStatsScreen()),


        ],
      ),
    );
  }

  Widget _item(BuildContext context, String title, Widget page) {
    return Card(
      child: ListTile(
        title: Text(title),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => page),
        ),
      ),
    );
  }
}
