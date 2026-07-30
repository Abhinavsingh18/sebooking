import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

import 'package:se_booking/config.dart';

class ApiService {
  static String get baseUrl => Config.baseUrl;

  static Future<List> getTests(String category) async {
    final res = await http.get(
      Uri.parse('$baseUrl/get_tests?category=$category'),
    );
    return json.decode(res.body);
  }

  static Future<List> getCenters(int testId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/get_centers?test_id=$testId'),
    );
    return json.decode(res.body);
  }

  static Future<String> bookTest({
    required String name,
    required String mobile,
    required String age,
    required String gender,
    required String address,
    required int centerId,
    required int testId,
    required double price,
    String paymentStatus = "Unpaid",
    double paidAmount = 0.0,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final isAgent = prefs.getBool('agent_logged_in') ?? false;
    final agentName = prefs.getString('agent_name') ?? "Agent";

    final body = {
      "name": name,
      "mobile": mobile,
      "age": age,
      "gender": gender,
      "address": address,
      "center_id": centerId,
      "test_id": testId,
      "price": price,
      "booked_by": isAgent ? agentName : "Customer",
      "payment_status": paymentStatus,
      "paid_amount": paidAmount,
    };
    
    debugPrint("DEBUG: Sending booking request: $body");

    final res = await http.post(
      Uri.parse('${Config.baseUrl}/add_booking'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );
    
    debugPrint("DEBUG: Booking response: ${res.body}");

    final bookingId = json.decode(res.body)["booking_id"];
    
    // Save locally to support receipt details since backend doesn't store age/address
    await updateLocalBooking(bookingId, body);

    return bookingId;
  }

  static Future<void> updateLocalBooking(String bookingId, Map data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localDataStr = prefs.getString('local_bookings_v1');
      Map<String, dynamic> localData = {};
      if (localDataStr != null) {
        localData = Map<String, dynamic>.from(json.decode(localDataStr));
      }
      
      localData[bookingId] = {
        'age': data['age'],
        'gender': data['gender'],
        'address': data['address'],
        'mobile': data['mobile'] 
      };
      
      await prefs.setString('local_bookings_v1', json.encode(localData));
    } catch (e) {
      // ignore
    }
  }

  static Future<List> getHistory(String mobile) async {
    final res = await http.get(
      Uri.parse('${Config.baseUrl}/bookings_by_mobile?mobile=$mobile'),
    );
    List<dynamic> history = json.decode(res.body);

    // Sort descending by date
    history.sort((a, b) {
      final dateA = a['created_at'] ?? a['date'] ?? 0;
      final dateB = b['created_at'] ?? b['date'] ?? 0;
      return dateB.compareTo(dateA); 
    });

    // Merge with local data
    try {
      history = await _mergeWithLocalDetails(history);
    } catch(e) {
      // ignore
    }

    return history;
  }

  static Future<List> _mergeWithLocalDetails(List history) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localDataStr = prefs.getString('local_bookings_v1');
      
      if (localDataStr == null) return history;
      
      final localData = Map<String, dynamic>.from(json.decode(localDataStr));
      
      for (var booking in history) {
        final bId = booking['booking_id'];
        if (localData.containsKey(bId)) {
          final local = localData[bId];
          // Update the booking map in place
          booking['age'] = booking['age'] ?? local['age'];
          booking['gender'] = booking['gender'] ?? local['gender'];
          booking['address'] = booking['address'] ?? local['address'];
        }
      }
    } catch (e) {
      // ignore
    }
    return history;
  }

  static Future<void> updatePaymentDetails({
    required String bookingId,
    required double agentCollected,
    required double centerCollected,
    double adminCollected = 0.0,
    required String updatedByName,
  }) async {
    await http.post(
      Uri.parse('${Config.baseUrl}/update_payment_details'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        "booking_id": bookingId,
        "agent_collected": agentCollected,
        "center_collected": centerCollected,
        "admin_collected": adminCollected,
        "updated_by_name": updatedByName,
      }),
    );
  }

  static Future<List> getCenterStats({int? startTs, int? endTs}) async {
    String url = '${Config.baseUrl}/admin/center_stats';
    if (startTs != null && endTs != null) {
      url += '?start_ts=$startTs&end_ts=$endTs';
    }
    
    final res = await http.get(Uri.parse(url));
    return json.decode(res.body);
  }
}
