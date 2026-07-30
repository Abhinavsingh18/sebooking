import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/material.dart'; // Added for BuildContext, ScaffoldMessenger, SnackBar, Text

class PdfService {
  static Future<void> generateAndOpenPdf(BuildContext context, Map booking) async {
    try {
      pw.ImageProvider? netImage;
      try {
        netImage = await imageFromAssetBundle('assets/logo.png');
      } catch (e) {
        debugPrint('Error loading logo: $e');
      }

      final bookingId = booking['booking_id'] ?? 'N/A';
      final dateTs = booking['created_at'] ?? booking['date'];
      // Handle date
      final date = dateTs != null
          ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.fromMillisecondsSinceEpoch(dateTs * 1000))
          : 'N/A';

      final patientName = booking['patient_name'] ?? booking['name'] ?? 'N/A';
      final age = booking['age'] ?? 'N/A';
      final gender = booking['gender'] ?? 'N/A';
      final mobile = booking['mobile'] ?? 'N/A';
      final address = booking['address'] ?? 'N/A';

      final testName = booking['test_name'] ?? 'N/A';
      final centerName = booking['center_name'] ?? 'N/A';
      final price = booking['price']?.toString() ?? '0';

      final paymentStatus = booking['payment_status'] ?? 'Unpaid';
      final isPaid = paymentStatus == 'Paid';

      final pdf = pw.Document(); // Added this line

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Stack(
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // --- HEADER ---
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('SE Booking',
                                style: pw.TextStyle(
                                    fontSize: 24,
                                    fontWeight: pw.FontWeight.bold,
                                    color: PdfColors.blue900)),
                            pw.Text('Diagnostic Test Booking',
                                style: const pw.TextStyle(
                                    fontSize: 12, color: PdfColors.grey700)),
                          ],
                        ),
                        if (netImage != null)
                          pw.Container(
                            width: 60,
                            height: 60,
                            child: pw.Image(netImage),
                          ),
                      ],
                    ),
                    pw.SizedBox(height: 20),
                    pw.Divider(),
                    pw.SizedBox(height: 20),

                    // --- TITLE ---
                    pw.Center(
                      child: pw.Text(
                        'BOOKING RECEIPT',
                        style: pw.TextStyle(
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                            decoration: pw.TextDecoration.underline),
                      ),
                    ),
                    pw.SizedBox(height: 30),

                    // --- BOOKING INFO ---
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Booking ID: $bookingId',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text('Date: $date'),
                      ],
                    ),
                    pw.SizedBox(height: 20),

                    // --- PATIENT DETAILS ---
                    pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey400),
                        borderRadius: pw.BorderRadius.circular(5),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Patient Details',
                              style: pw.TextStyle(
                                  fontSize: 14,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.blue800)),
                          pw.Divider(color: PdfColors.grey300),
                          _buildRow('Name', patientName),
                          _buildRow('Age / Gender', '$age Y / $gender'),
                          _buildRow('Mobile', mobile),
                          _buildRow('Address', address),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 20),

                    // --- TEST DETAILS ---
                    pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey400),
                        borderRadius: pw.BorderRadius.circular(5),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Test Information',
                              style: pw.TextStyle(
                                  fontSize: 14,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.blue800)),
                          pw.Divider(color: PdfColors.grey300),
                          _buildRow('Test Name', testName),
                          _buildRow('Center Name', centerName),
                          pw.SizedBox(height: 5),
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('Amount to Pay:'),
                              pw.Text('INR $price',
                                  style: pw.TextStyle(
                                      fontSize: 16,
                                      fontWeight: pw.FontWeight.bold,
                                      color: PdfColors.green900)),
                            ],
                          ),
                        ],
                      ),
                    ),

                    pw.Spacer(),

                    // --- FOOTER ---
                    pw.Center(
                      child: pw.Text('Thank you for choosing SE Booking!',
                          style: const pw.TextStyle(color: PdfColors.grey600)),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Center(
                      child: pw.Text('For support, call: 1800-889-9818',
                          style: const pw.TextStyle(
                              fontSize: 10, color: PdfColors.grey600)),
                    ),
                  ],
                ),

                // --- WATERMARK STAMP ---
                pw.Positioned(
                  bottom: 150,
                  right: 50,
                  child: pw.Transform.rotate(
                    angle: -0.5,
                    child: pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(
                          color: isPaid ? PdfColors.green : PdfColors.red,
                          width: 5,
                        ),
                        borderRadius: pw.BorderRadius.circular(10),
                      ),
                      child: pw.Text(
                        isPaid ? 'PAID' : 'UNPAID',
                        style: pw.TextStyle(
                          color: isPaid ? PdfColors.green : PdfColors.red,
                          fontSize: 40,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    } on MissingPluginException {
      debugPrint("PDF Generation Error: MissingPluginException");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Plugin missing. Please restart the app completely.'),
          duration: Duration(seconds: 4),
        ),
      );
    } catch (e) {
      debugPrint("PDF Generation Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate PDF: $e')),
      );
    }
  }

  static pw.Widget _buildRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(color: PdfColors.grey700)),
          pw.Expanded(
            child: pw.Text(value, textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
