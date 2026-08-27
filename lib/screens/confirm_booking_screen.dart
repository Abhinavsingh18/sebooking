import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/pdf_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:js' as js;

class ConfirmBookingScreen extends StatefulWidget {
  final int testId;
  final String testName;
  final int centerId;
  final String centerName;
  final double price;
  final String patientName;
  final String mobile;
  final String age; 
  final String gender; 
  final String address; 
  final String paymentStatus;

  const ConfirmBookingScreen({
    super.key,
    required this.testId,
    required this.testName,
    required this.centerId,
    required this.centerName,
    required this.price,
    required this.patientName,
    required this.mobile,
    required this.age,
    required this.gender,
    required this.address,
    this.paymentStatus = "Unpaid",
  });

  @override
  State<ConfirmBookingScreen> createState() => _ConfirmBookingScreenState();
}

class _ConfirmBookingScreenState extends State<ConfirmBookingScreen> {
  bool loading = false;
  bool isAgent = false;
  bool _userPaid = false; 
  final _amountController = TextEditingController();
  final _txnController = TextEditingController();
  
  late TextEditingController _nameController;
  late TextEditingController _mobileController;
  final _ageController = TextEditingController();
  final _addressController = TextEditingController();
  String _gender = 'Male';
  Razorpay? _razorpay;
  String _currentBookingId = "";

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.patientName);
    _mobileController = TextEditingController(text: widget.mobile);
    _ageController.text = widget.age;
    _addressController.text = widget.address;
    if (['Male', 'Female', 'Other'].contains(widget.gender)) {
       _gender = widget.gender;
    }

    _checkAgent();
    if (widget.paymentStatus == 'Paid') {
      _amountController.text = widget.price.toStringAsFixed(0);
    } else {
      _amountController.text = "0";
    }

    if (!kIsWeb) {
      _razorpay = Razorpay();
      _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccessMobile);
      _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentErrorMobile);
      _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWalletMobile);
    }
  }

  @override
  void dispose() {
    if (!kIsWeb && _razorpay != null) {
      _razorpay!.clear();
    }
    super.dispose();
  }

  Future<void> _checkAgent() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        isAgent = prefs.getBool('agent_logged_in') ?? false;
        if (isAgent) {
          _amountController.text = widget.price.toStringAsFixed(0);
        }
      });
    }
  }

  Future<void> book() async {
    // Validation
    if (_nameController.text.isEmpty ||
        _mobileController.text.isEmpty ||
        _ageController.text.isEmpty ||
        _addressController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all required fields')));
      return;
    }

    if (!RegExp(r'^\d{10,12}$').hasMatch(_mobileController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mobile number must be 10-12 digits')));
      return;
    }

    if (!isAgent && _mobileController.text.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter valid Mobile Number')));
      return;
    }

    setState(() => loading = true);

    try {
      final bookingId = await ApiService.bookTest(
        name: _nameController.text,
        mobile: _mobileController.text,
        age: _ageController.text,
        gender: _gender,
        address: _addressController.text,
        centerId: widget.centerId,
        testId: widget.testId,
        price: widget.price,
        paymentStatus: isAgent ? widget.paymentStatus : "Pending Payment",
        paidAmount: isAgent 
            ? (double.tryParse(_amountController.text) ?? 0.0) 
            : 0.0,
      );
      
      _currentBookingId = bookingId;

      if (!isAgent) {
        // Razorpay Flow
        final orderResponse = await ApiService.createPaymentOrder(bookingId);
        final orderId = orderResponse["order_id"];
        final amount = orderResponse["amount"];
        
        if (kIsWeb) {
          _openRazorpayWeb(orderId, amount);
        } else {
          var options = {
            'key': 'rzp_test_TUf5qpKwVrX0md', // Razorpay Key ID
            'amount': amount,
            'name': 'Mahakal Events',
            'description': 'Booking for ${widget.testName}',
            'order_id': orderId,
            'prefill': {
              'contact': _mobileController.text,
              'email': 'customer@example.com'
            },
            'theme': {'color': '#11612b'}
          };
          _razorpay!.open(options);
        }
      } else {
        setState(() => loading = false);
        _showSuccessDialog(_currentBookingId, false);
      }
    } catch (e) {
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _openRazorpayWeb(String orderId, int amount) {
    try {
      var options = {
        'key': 'rzp_test_TUf5qpKwVrX0md',
        'amount': amount,
        'name': 'Mahakal Events',
        'description': 'Booking for ${widget.testName}',
        'order_id': orderId,
        'prefill': {
          'contact': _mobileController.text,
          'email': 'customer@example.com'
        },
        'theme': {'color': '#11612b'},
        'handler': js.allowInterop((response) {
          final paymentId = response['razorpay_payment_id'] ?? '';
          final signature = response['razorpay_signature'] ?? '';
          final respOrderId = response['razorpay_order_id'] ?? orderId;
          _verifyPaymentOnline(respOrderId, paymentId, signature);
        }),
        'modal': {
          'ondismiss': js.allowInterop(() {
            setState(() => loading = false);
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Payment cancelled by user")));
          })
        }
      };

      var rzp = js.JsObject(js.context['Razorpay'], [js.JsObject.jsify(options)]);
      rzp.callMethod('open');
    } catch (e) {
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error opening Razorpay: $e")));
    }
  }

  void _verifyPaymentOnline(String orderId, String paymentId, String signature) async {
    try {
      await ApiService.verifyPayment(
        bookingId: _currentBookingId,
        orderId: orderId,
        paymentId: paymentId,
        signature: signature,
      );
      
      setState(() => loading = false);
      _showSuccessDialog(_currentBookingId, true);
    } catch (e) {
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment verification failed: $e')));
    }
  }

  void _handlePaymentSuccessMobile(PaymentSuccessResponse response) {
    _verifyPaymentOnline(response.orderId!, response.paymentId!, response.signature!);
  }

  void _handlePaymentErrorMobile(PaymentFailureResponse response) {
    setState(() => loading = false);
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Payment failed: ${response.message}")));
  }

  void _handleExternalWalletMobile(ExternalWalletResponse response) {
    setState(() => loading = false);
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("External Wallet Selected: ${response.walletName}")));
  }

  void _showSuccessDialog(String bookingId, bool isOnlinePaid) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Booking Confirmed'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 48,
            ),
            const SizedBox(height: 12),

            const Text(
              'Your Booking ID',
              style: TextStyle(fontSize: 14),
            ),

            const SizedBox(height: 8),

            Container(
              padding: const EdgeInsets.symmetric(
                vertical: 10,
                horizontal: 16,
              ),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.green),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                bookingId,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),

            const SizedBox(height: 12),

            Text(
              isOnlinePaid
                  ? 'Payment successful.\nPlease show this Booking ID at the center.'
                  : 'Please show this receipt at the center.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              // Generate PDF
              final bookingData = {
                'booking_id': bookingId,
                'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
                'patient_name': _nameController.text,
                'age': _ageController.text,
                'gender': _gender,
                'mobile': _mobileController.text,
                'address': _addressController.text,
                'test_name': widget.testName,
                'center_name': widget.centerName,
                'price': widget.price,
                'payment_status': isAgent 
                    ? widget.paymentStatus 
                    : (isOnlinePaid ? "Paid" : "Pending Payment"),
              };
              debugPrint("Generating PDF with data: $bookingData");
              PdfService.generateAndOpenPdf(context, bookingData);
            },
            child: const Text('Download Receipt'),
          ),
          TextButton(
            onPressed: () {
              Navigator.popUntil(context, (r) => r.isFirst);
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );

    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Confirm Booking')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Patient Details Form
          TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Patient Name *', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _mobileController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Mobile Number *', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: TextField(controller: _ageController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Age *', border: OutlineInputBorder()))),
              const SizedBox(width: 12),
              Expanded(child: DropdownButtonFormField<String>(
                value: _gender,
                decoration: const InputDecoration(labelText: 'Gender *', border: OutlineInputBorder()),
                items: ['Male', 'Female', 'Other'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() => _gender = v!),
              )),
            ],
          ),
          const SizedBox(height: 12),
          TextField(controller: _addressController, maxLines: 2, decoration: const InputDecoration(labelText: 'Address *', border: OutlineInputBorder())),
          
          const SizedBox(height: 24),
          
          // 2. Test Information
          const Text("Test Information", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const Divider(),
          ListTile(
            title: Text(widget.testName),
            subtitle: const Text("Test Name"),
            dense: true,
          ),
          ListTile(
            title: Text(widget.centerName),
            subtitle: const Text("Center"),
            dense: true,
          ),
          ListTile(
            title: Text("₹${widget.price.toStringAsFixed(0)}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
            subtitle: const Text("Price"),
            dense: true,
          ),
          const Divider(),
          const SizedBox(height: 16),

          // 3. Payment Logic (Agent vs User)
          if (isAgent) ...[
             Container(
               padding: const EdgeInsets.all(12),
               decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue)),
               child: const Text("Agent Collection: Collect full amount from patient.", style: TextStyle(color: Colors.blue)),
             ),
             const SizedBox(height: 12),
             TextField(controller: _amountController, readOnly: true, decoration: const InputDecoration(labelText: 'Amount Collected (₹)', border: OutlineInputBorder())),
          ] else ...[
             const Center(child: Text("Pay Securely Online", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
             const SizedBox(height: 12),
             const Text("You will be securely redirected to Razorpay to complete your payment.", style: TextStyle(color: Colors.grey, fontSize: 13), textAlign: TextAlign.center),
             const SizedBox(height: 16),
           ],

           const SizedBox(height: 32),

           // 4. Submit Button
           ElevatedButton(
             onPressed: loading ? null : book,
             style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
             child: loading ? const CircularProgressIndicator(color: Colors.white) : Text(isAgent ? 'Confirm & Book' : 'Pay ₹${widget.price.toStringAsFixed(0)} & Book', style: const TextStyle(fontSize: 18)),
           ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _row(String k, String v, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k),
          Text(
            v,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
