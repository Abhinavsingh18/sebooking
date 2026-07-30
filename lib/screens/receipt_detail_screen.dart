import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/pdf_service.dart';
import '../services/api_service.dart';

class ReceiptDetailScreen extends StatelessWidget {
  final Map receipt;

  const ReceiptDetailScreen({super.key, required this.receipt});

  @override
  Widget build(BuildContext context) {
    // Format Date
    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(
        DateTime.fromMillisecondsSinceEpoch((receipt['date'] ?? 0) * 1000));

    return Scaffold(
      appBar: AppBar(title: const Text('Receipt Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Icon(
                      Icons.receipt,
                      size: 48,
                      color: Colors.green,
                    ),
                    const SizedBox(height: 12),

                    _rowDisplay('Date', dateStr),
                    _rowDisplay('Booking ID', receipt['booking_id']),
                    const Divider(),
                    _rowDisplay('Patient', receipt['patient_name'] ?? 'N/A'),
                    _rowDisplay('Age/Gender', '${receipt['age'] ?? 'N/A'} / ${receipt['gender'] ?? 'N/A'}'),
                    _rowDisplay('Mobile', receipt['mobile'] ?? 'N/A'),
                    _rowDisplay('Address', receipt['address'] ?? 'N/A'),
                    const Divider(),
                    _rowDisplay('Test', receipt['test_name']),
                    _rowDisplay('Center', receipt['center_name']),
                    _rowDisplay('Amount', '₹${receipt['price']}'),
                    _rowDisplay('Status', receipt['status']),
                    _rowDisplay('Payment', receipt['payment_status'] ?? 'Unpaid'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              'Please show this receipt at the center.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),

            const SizedBox(height: 30),

            ElevatedButton.icon(
              onPressed: () {
                debugPrint("Generating PDF from history: $receipt");
                PdfService.generateAndOpenPdf(context, receipt);
              },
              icon: const Icon(Icons.download),
              label: const Text('Download Receipt PDF'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rowDisplay(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: const TextStyle(color: Colors.black54)),
          Flexible(
            child: Text(
              v,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
