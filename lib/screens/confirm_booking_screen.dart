import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/pdf_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  int _selectedQrIndex = 0;

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

    if (!isAgent && _txnController.text.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter valid Transaction ID (min 4 chars)')));
      return;
    }

    setState(() => loading = true);

    final bookingId = await ApiService.bookTest(
      name: _nameController.text,
      mobile: _mobileController.text,
      age: _ageController.text,
      gender: _gender,
      address: _addressController.text,
      centerId: widget.centerId,
      testId: widget.testId,
      price: widget.price,
      paymentStatus: isAgent ? widget.paymentStatus : "Pending Verification (Txn: ${_txnController.text})",
      paidAmount: isAgent 
          ? (double.tryParse(_amountController.text) ?? 0.0) 
          : widget.price,
    );
    
    // ... rest of method (showSuccessDialog)

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
              (!isAgent && _txnController.text.isNotEmpty)
                  ? 'Payment verification pending.\nPlease show this Booking ID at the center.'
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
                    : "Pending Verification (Txn: ${_txnController.text})",
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
             const Center(child: Text("Scan & Pay via UPI", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
             const SizedBox(height: 12),
             
             Row(
               mainAxisAlignment: MainAxisAlignment.center,
               children: [
                 ChoiceChip(
                   label: const Text("BharatPe"),
                   selected: _selectedQrIndex == 0,
                   onSelected: (v) => setState(() => _selectedQrIndex = 0),
                 ),
                 const SizedBox(width: 12),
                 ChoiceChip(
                   label: const Text("Paytm"),
                   selected: _selectedQrIndex == 1,
                   onSelected: (v) => setState(() => _selectedQrIndex = 1),
                 ),
               ],
             ),
             
             const SizedBox(height: 12),
             Center(
                child: Container(
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
                  child: Image.asset(
                    _selectedQrIndex == 0 ? "assets/qr_codes/bharatpe_qr.jpg" : "assets/qr_codes/paytm_qr.jpg",
                    height: 300, 
                    fit: BoxFit.contain,
                    errorBuilder: (_,__,___) => const SizedBox(height: 200, width: 200, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.broken_image, size: 50), Text("QR not found")])),
                  ),
                ),
             ),
             const SizedBox(height: 16),
             TextField(
               controller: _txnController,
               decoration: const InputDecoration(labelText: "Enter UPI Transaction ID", hintText: "Required", border: OutlineInputBorder()),
               onChanged: (v) => setState((){}),
             ),
             const SizedBox(height: 8),
             const Text("Booking will be 'Pending Verification'.", style: TextStyle(color: Colors.orange, fontSize: 12)),
          ],

          const SizedBox(height: 32),

          // 4. Submit Button
          ElevatedButton(
            onPressed: loading || (!isAgent && _txnController.text.length < 4) ? null : book,
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            child: loading ? const CircularProgressIndicator(color: Colors.white) : const Text('Confirm & Book', style: TextStyle(fontSize: 18)),
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
