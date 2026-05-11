import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

class DemoLiquidationFormPage extends StatelessWidget {
  final Map<String, dynamic> formData;
  final String docId;

  const DemoLiquidationFormPage({
    Key? key,
    required this.formData,
    required this.docId,
  }) : super(key: key);

  // ====== HELPERS (same backend behavior) ======

  String _formatReadableDate(dynamic value, {String fallback = '-'}) {
    const monthNames = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    DateTime? dt;

    if (value is DateTime) {
      dt = value;
    } else if (value is String && value.isNotEmpty) {
      dt = DateTime.tryParse(value);
      if (dt == null) {
        final parts = value.split(RegExp(r'[/\-]'));
        if (parts.length == 3) {
          final a = int.tryParse(parts[0]);
          final b = int.tryParse(parts[1]);
          final c = int.tryParse(parts[2]);
          if (a != null && b != null && c != null) {
            if (c > 31) {
              dt = DateTime.tryParse(
                '$c-${a.toString().padLeft(2, '0')}-${b.toString().padLeft(2, '0')}',
              );
            } else {
              dt = DateTime.tryParse(
                '${a.toString().padLeft(4, '0')}-${b.toString().padLeft(2, '0')}-${c.toString().padLeft(2, '0')}',
              );
            }
          }
        }
      }
    }

    if (dt == null) {
      return fallback.isNotEmpty ? fallback : '-';
    }
    return '${monthNames[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  Uint8List? _decodeSignature(String? dataUrl) {
    if (dataUrl == null || dataUrl.isEmpty) return null;
    try {
      final commaIndex = dataUrl.indexOf(',');
      final base64Part =
          commaIndex >= 0 ? dataUrl.substring(commaIndex + 1) : dataUrl;
      return base64Decode(base64Part);
    } catch (_) {
      return null;
    }
  }

  List<Map<String, dynamic>> _extractProducts() {
    final raw = formData['products'];
    if (raw is List) {
      return raw.map<Map<String, dynamic>>((e) {
        if (e is Map<String, dynamic>) return e;
        if (e is Map) {
          return e.map(
            (k, v) => MapEntry(k.toString(), v),
          );
        }
        return <String, dynamic>{};
      }).toList();
    }
    return const [];
  }

  // ====== UI PIECES (HTML-like styling) ======

  Widget _buildFormShell(BuildContext context, List<Widget> children) {
    // Mimic an HTML form centered in the viewport (max-width like 960px).
    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxWidth = constraints.maxWidth > 960
            ? 960
            : constraints.maxWidth;
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
            ),
            child: Container(
              margin: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color(0xFFE3DDF5),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFormHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title row similar to an HTML header bar
        Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFF4A2371).withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.description_outlined,
                color: Color(0xFF4A2371),
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Demo Liquidation Form',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                  color: Color(0xFF24174B),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Review the demo liquidation details submitted by the user.',
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF6B6D7E),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        Divider(
          color: const Color(0xFFE3DDF5),
          height: 1,
          thickness: 1,
        ),
        const SizedBox(height: 14),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 10, 2, 6),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: Color(0xFF8B75C9),
        ),
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: Color(0xFF6C6C7B),
        letterSpacing: 0.9,
      ),
    );
  }

  Widget _buildValueText(String value) {
    return Text(
      value.isEmpty ? '-' : value,
      style: const TextStyle(
        fontSize: 14.5,
        fontWeight: FontWeight.w500,
        color: Color(0xFF151624),
        height: 1.35,
      ),
    );
  }

  Widget _buildFieldCard({
    required String label,
    required String value,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F7FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFE3DDF5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel(label),
          const SizedBox(height: 3),
          _buildValueText(value),
        ],
      ),
    );
  }

  Widget _buildTwoColFields({
    required String label1,
    required String value1,
    required String label2,
    required String value2,
  }) {
    return Row(
      children: [
        Expanded(
          child: _buildFieldCard(
            label: label1,
            value: value1,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildFieldCard(
            label: label2,
            value: value2,
          ),
        ),
      ],
    );
  }

  Widget _buildProductsSection(List<Map<String, dynamic>> products) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F7FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE3DDF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row like in HTML table
          Row(
            children: const [
              Expanded(
                flex: 3,
                child: Text(
                  'PRODUCT',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.9,
                    color: Color(0xFF4A2371),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'CATEGORY',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.9,
                    color: Color(0xFF4A2371),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'CROP',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.9,
                    color: Color(0xFF4A2371),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Divider(
            height: 1,
            color: const Color(0xFFE3DDF5),
          ),
          const SizedBox(height: 4),
          if (products.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text(
                'No products recorded.',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF9B9BB3),
                ),
              ),
            )
          else
            ...products.asMap().entries.map((entry) {
              final idx = entry.key;
              final p = entry.value;

              final product = (p['product'] ?? '').toString();
              final category = (p['category'] ?? '').toString();
              final crop = (p['crop'] ?? '').toString();
              final qty = (p['quantity'] ?? '').toString();
              final uom = (p['uom'] ?? '').toString();
              final demoType = (p['demoType'] ?? '').toString();
              final targetDate =
                  _formatReadableDate(p['targetApplicationDate'] ?? '');

              final metaLine = [
                if (qty.isNotEmpty || uom.isNotEmpty) 'Qty: $qty $uom',
                if (demoType.isNotEmpty) 'Demo type: $demoType',
                if (targetDate.isNotEmpty && targetDate != '-') 'Target app date: $targetDate',
              ].join(' • ');

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (idx > 0)
                    Divider(
                      height: 10,
                      color: const Color(0xFFE3DDF5),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            product.isEmpty ? '-' : product,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A1A2E),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            category.isEmpty ? '-' : category,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF303247),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            crop.isEmpty ? '-' : crop,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF303247),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (metaLine.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 2, bottom: 5),
                      child: Text(
                        metaLine,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF8C8DA4),
                        ),
                      ),
                    ),
                ],
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildRemarksBox(String remarks) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F7FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE3DDF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel('Remarks'),
          const SizedBox(height: 3),
          Text(
            remarks.isEmpty ? '-' : remarks,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Color(0xFF151624),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignature(Uint8List? sigBytes) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F7FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE3DDF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel('Signature of recipient'),
          const SizedBox(height: 6),
          Container(
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFFF3EEFF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFD7CCF5)),
            ),
            child: Center(
              child: sigBytes == null
                  ? const Text(
                      'No signature captured',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF9B9BB3),
                      ),
                    )
                  : Image.memory(
                      sigBytes,
                      fit: BoxFit.contain,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgreeRow(bool agree) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F7FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE3DDF5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: agree,
            onChanged: null,
            activeColor: const Color(0xFF4A2371),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'I agree to receive products or promo communications from Wert.',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF151624),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ====== MAIN BUILD ======

  @override
  Widget build(BuildContext context) {
    // Map fields from Firestore, keeping same keys as HTML saved.
    final seedBatchNumber =
        (formData['seedBatchNumber'] ?? '').toString();
    final receiptNumber =
        (formData['receiptNumber'] ?? '').toString();
    final recipient =
        (formData['recipient'] ?? '').toString();

    final firstName =
        (formData['firstName'] ?? '').toString();
    final lastName =
        (formData['lastName'] ?? '').toString();
    final mobileNumber =
        (formData['mobileNumber'] ?? '').toString();

    final recipientProvince =
        (formData['recipientProvince'] ?? '').toString();
    final recipientMunicipal =
        (formData['recipientMunicipal'] ?? '').toString();
    final recipientBarangay =
        (formData['recipientBarangay'] ?? '').toString();

    final demoSiteProvince =
        (formData['demoSiteProvince'] ?? '').toString();
    final demoSiteMunicipality =
        (formData['demoSiteMunicipality'] ?? '').toString();
    final demoSiteBarangay =
        (formData['demoSiteBarangay'] ?? '').toString();

    final aoa = (formData['aoa'] ?? '').toString();
    final dateReceived =
        _formatReadableDate(formData['dateReceived']);
    final nameOfUser =
        (formData['nameOfUser'] ?? '').toString();
    final district =
        (formData['district'] ?? '').toString();
    final territory =
        (formData['territory'] ?? '').toString();

    final remarks = (formData['remarks'] ?? '').toString();
    final agreePromo = (formData['agreePromo'] ?? false) == true;

    final signatureBase64 =
        (formData['signatureBase64'] ?? '').toString();
    final sigBytes = _decodeSignature(signatureBase64);

    final products = _extractProducts();

    return Scaffold(
      backgroundColor: const Color(0xFFF3F0FF),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF4A2371),
        centerTitle: true,
        title: const Text(
          'Demo Liquidation',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 32),
        child: _buildFormShell(
          context,
          [
            _buildFormHeader(),

            // Reference section
            _buildSectionTitle('Reference details'),
            _buildFieldCard(
              label: 'Seed batch number',
              value: seedBatchNumber,
            ),
            _buildFieldCard(
              label: 'Receipt number',
              value: receiptNumber,
            ),
            _buildFieldCard(
              label: 'Recipient',
              value: recipient,
            ),

            const SizedBox(height: 12),

            // Products section
            _buildSectionTitle('Products received'),
            _buildProductsSection(products),

            const SizedBox(height: 12),

            // Recipient information
            _buildSectionTitle('Recipient information'),
            _buildTwoColFields(
              label1: 'First name',
              value1: firstName,
              label2: 'Last name',
              value2: lastName,
            ),
            _buildFieldCard(
              label: 'Mobile number',
              value: mobileNumber,
            ),
            _buildTwoColFields(
              label1: "Recipient's province",
              value1: recipientProvince,
              label2: "Recipient's municipal",
              value2: recipientMunicipal,
            ),
            _buildFieldCard(
              label: "Recipient's barangay",
              value: recipientBarangay,
            ),

            const SizedBox(height: 12),

            // Demo site information
            _buildSectionTitle('Demo site information'),
            _buildTwoColFields(
              label1: 'Demo site province',
              value1: demoSiteProvince,
              label2: 'Demo site municipality',
              value2: demoSiteMunicipality,
            ),
            _buildFieldCard(
              label: 'Demo site barangay',
              value: demoSiteBarangay,
            ),

            const SizedBox(height: 12),

            // Additional details
            _buildSectionTitle('Additional details'),
            _buildFieldCard(
              label: 'AOA',
              value: aoa,
            ),
            _buildFieldCard(
              label: 'Date received',
              value: dateReceived,
            ),
            _buildFieldCard(
              label: 'Name of user',
              value: nameOfUser,
            ),
            _buildTwoColFields(
              label1: 'District',
              value1: district,
              label2: 'Territory',
              value2: territory,
            ),
            _buildRemarksBox(remarks),

            const SizedBox(height: 12),

            // Signature & consent
            _buildSectionTitle('Signature & consent'),
            _buildSignature(sigBytes),
            _buildAgreeRow(agreePromo),
          ],
        ),
      ),
    );
  }
}