import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Read-only Ending Inventory Report page that mirrors the HTML design.
///
/// Expects the Firestore payload created by `ending_inventory_report.html`:
/// - eiReferenceNumber, nameOfUser, date, purchaseYear, purchaseMonth
/// - accountType, accountName, province, municipality
/// - productRows: List<Map<String, dynamic>>
///     { productName, uom, quantity, manufacturingDateBatch, remarks, ... }
/// - nameOfAuthorizedStoreRepresentative, signatureData (optional), timestamp
class EndingInventoryReportPage extends StatelessWidget {
  final Map<String, dynamic> formData;
  final String docId;

  const EndingInventoryReportPage({
    Key? key,
    required this.formData,
    required this.docId,
  }) : super(key: key);

  // ----- Helpers -------------------------------------------------------------

  String _s(dynamic v) {
    if (v == null) return '';
    if (v is String) return v;
    return v.toString();
  }

  Uint8List? _decodeSignature(String? base64Data) {
    if (base64Data == null || base64Data.isEmpty) return null;
    try {
      final parts = base64Data.split(',');
      final b64 = parts.length > 1 ? parts.last : base64Data;
      return base64Decode(b64);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Map HTML payload -> local variables
    final String eiRef = _s(formData['eiReferenceNumber']).trim();
    final String nameOfUser = _s(formData['nameOfUser']).trim();
    final String date = _s(formData['date']).trim();
    final String purchaseYear = _s(formData['purchaseYear']).trim();
    final String purchaseMonth = _s(formData['purchaseMonth']).trim();
    final String accountType = _s(formData['accountType']).trim();
    final String accountName = _s(formData['accountName']).trim();
    final String province = _s(formData['province']).trim();
    final String municipality = _s(formData['municipality']).trim();
    final String authorizedRep =
        _s(formData['nameOfAuthorizedStoreRepresentative']).trim();
    final String signatureBase64 =
        _s(formData['signatureData']).trim();

    final Uint8List? signatureBytes =
        signatureBase64.isNotEmpty ? _decodeSignature(signatureBase64) : null;

    final List<dynamic> rawRows =
        (formData['productRows'] ?? []) as List<dynamic>;
    final List<Map<String, dynamic>> productRows = rawRows
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();

    // Color palette derived from CSS variables.
    const Color pd = Color(0xFF4A2371); // --pd
    const Color p = Color(0xFF5958B2); // --p
    const Color surface = Color(0xFFF9F5FF); // --surface
    const Color card = Color(0xFFFFFFFF); // --card
    const Color text = Colors.black; // --text
    const Color muted = Color(0xFF2B2B2B); // --muted
    const Color border = Color(0xFFE9E3F5); // --border
    const Color red = Color(0xFFDC2626); // --red
    const Color green = Color(0xFF059669); // --green
    const Gradient grad = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        pd,
        pd,
        p,
      ],
      stops: [0.0, 0.55, 1.0],
    );

    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(
        title: const Text('Ending Inventory Report'),
        centerTitle: true,
        elevation: 4,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF4E3385),
                Color(0xFF503282),
                Color(0xFF523584),
                Color(0xFF543887),
                Color(0xFF563B89),
                Color(0xFF593F8C),
                Color(0xFF5C438F),
                Color(0xFF5F4892),
                Color(0xFF634D96),
                Color(0xFF68529A),
                Color(0xFF6E589E),
                Color(0xFF7560A4),
                Color(0xFF8170AB),
                Color(0xFF9582B3),
              ],
              stops: [
                0.0,
                0.07,
                0.14,
                0.22,
                0.30,
                0.38,
                0.46,
                0.54,
                0.62,
                0.70,
                0.77,
                0.84,
                0.92,
                1.0
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(24),
            ),
          ),
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(24),
          ),
        ),
      ),
      body: Container(
        color: surface,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760), // --max-w
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top title to mimic HTML semantics
                  Text(
                    'Ending Inventory Report',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      fontFamily: 'Figtree',
                      color: text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (eiRef.isNotEmpty)
                    Text(
                      'EI Reference Number: $eiRef',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        fontFamily: 'Figtree',
                      ),
                    ),
                  const SizedBox(height: 14),

                  // --- Reference Information section ----------------------------------
                  const _SectionLabel(
                    text: 'Reference Information',
                    first: true,
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: card,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 14,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _TwoColumnRow(
                          borderColor: const Color(0xFFF0EBF9),
                          left: _FieldRowDisabled(
                            label: 'EI Reference Number',
                            value: eiRef,
                          ),
                          right: _FieldRowDisabled(
                            label: 'Name of User',
                            value: nameOfUser,
                          ),
                        ),
                        _DividerRow(borderColor: const Color(0xFFF0EBF9)),
                        _FieldRowDisabled(
                          label: 'Date',
                          value: date,
                        ),
                        _DividerRow(borderColor: const Color(0xFFF0EBF9)),
                        _TwoColumnRow(
                          borderColor: const Color(0xFFF0EBF9),
                          left: _FieldRowDisabled(
                            label: 'Purchase Year',
                            value: purchaseYear,
                          ),
                          right: _FieldRowDisabled(
                            label: 'Purchase Month',
                            value: purchaseMonth,
                          ),
                          isLast: true,
                        ),
                      ],
                    ),
                  ),

                  // --- Account Information ---------------------------------------------
                  const SizedBox(height: 20),
                  const _SectionLabel(text: 'Account Information'),
                  Container(
                    decoration: BoxDecoration(
                      color: card,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 14,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _FieldRowPlain(
                          label: 'Account Type',
                          value: accountType,
                          showRequiredStar: true,
                        ),
                        _DividerRow(borderColor: const Color(0xFFF0EBF9)),
                        _FieldRowPlain(
                          label: 'Account Name',
                          value: accountName,
                          showRequiredStar: true,
                          hint: 'e.g., Juan Dela Cruz Agri Supply',
                        ),
                        _DividerRow(borderColor: const Color(0xFFF0EBF9)),
                        _TwoColumnRow(
                          borderColor: const Color(0xFFF0EBF9),
                          left: _FieldRowPlain(
                            label: 'Province',
                            value: province,
                            showRequiredStar: true,
                            hint: 'e.g., Quezon',
                          ),
                          right: _FieldRowPlain(
                            label: 'Municipality',
                            value: municipality,
                            showRequiredStar: true,
                            hint: 'e.g., Lucena City',
                          ),
                          isLast: true,
                        ),
                      ],
                    ),
                  ),

                  // --- Product Inventory header bar ------------------------------------
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const _SectionLabel(text: 'Product Inventory', margin0: true),
                      Container(
                        decoration: BoxDecoration(
                          gradient: grad,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF9C40FF).withOpacity(0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(
                              Icons.add,
                              size: 14,
                              color: Colors.white,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Add Row',
                              style: TextStyle(
                                fontFamily: 'Figtree',
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // --- Product Inventory Cards (read-only) -----------------------------
                  if (productRows.isEmpty)
                    Container(
                      decoration: BoxDecoration(
                        color: card,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 14,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      child: Text(
                        'No product rows recorded.',
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: 'Figtree',
                          color: Colors.grey.shade700,
                        ),
                      ),
                    )
                  else
                    Column(
                      children: [
                        for (int i = 0; i < productRows.length; i++)
                          _ProductCard(
                            index: i,
                            data: productRows[i],
                            grad: grad,
                            pd: pd,
                            muted: muted,
                            borderColor: border,
                          ),
                      ],
                    ),

                  // --- Authorization card ---------------------------------------------
                  const SizedBox(height: 20),
                  const _SectionLabel(text: 'Authorization'),
                  Container(
                    decoration: BoxDecoration(
                      color: card,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 14,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FieldRowPlain(
                          label: 'Name of Authorized Store Representative',
                          value: authorizedRep,
                          showRequiredStar: true,
                          hint: 'e.g., Maria Santos',
                        ),
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: const [
                                  Text(
                                    'Signature',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.1,
                                      fontFamily: 'Figtree',
                                      color: muted,
                                    ),
                                  ),
                                  SizedBox(width: 2),
                                  Text(
                                    '*',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      fontFamily: 'Figtree',
                                      color: red,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(11),
                                  border: Border.all(
                                    color: border,
                                    width: 1,
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                height: 80,
                                width: double.infinity,
                                child: signatureBytes != null
                                    ? Image.memory(
                                        signatureBytes,
                                        fit: BoxFit.contain,
                                      )
                                    : Center(
                                        child: Text(
                                          'No signature captured.',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontFamily: 'Figtree',
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                      ),
                              ),
                              const SizedBox(height: 4),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  'Clear Signature',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontFamily: 'Figtree',
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // --- Footer like HTML toast / id display -----------------------------
                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      'Document ID: $docId',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                        fontFamily: 'Figtree',
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      'Read-only preview',
                      style: TextStyle(
                        fontSize: 11,
                        color: green.withOpacity(0.8),
                        fontFamily: 'Figtree',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ----- UI building blocks to mirror HTML styles -------------------------------

class _SectionLabel extends StatelessWidget {
  final String text;
  final bool first;
  final bool margin0;

  const _SectionLabel({
    Key? key,
    required this.text,
    this.first = false,
    this.margin0 = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 8,
        top: first ? 4 : (margin0 ? 0 : 20),
        bottom: 8,
      ),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: Color(0xFF5958B2),
          fontFamily: 'Figtree',
        ),
      ),
    );
  }
}

class _FieldRowDisabled extends StatelessWidget {
  final String label;
  final String value;

  const _FieldRowDisabled({
    Key? key,
    required this.label,
    required this.value,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Color borderColor = const Color(0xFF000000).withOpacity(0.09);
    final Color bgColor = const Color(0xFF000000).withOpacity(0.025);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: Color(0xFF2B2B2B),
              fontFamily: 'Figtree',
            ),
          ),
          const SizedBox(height: 3),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: borderColor,
                width: 1.5,
              ),
            ),
            child: Text(
              value.isNotEmpty ? value : '',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                fontFamily: 'Figtree',
                color: Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldRowPlain extends StatelessWidget {
  final String label;
  final String value;
  final bool showRequiredStar;
  final String? hint;

  const _FieldRowPlain({
    Key? key,
    required this.label,
    required this.value,
    this.showRequiredStar = false,
    this.hint,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const Color mainBorder = Color(0xFF6B21C8);
    final Color borderColor = mainBorder.withOpacity(0.25);
    final Color bgColor = mainBorder.withOpacity(0.04);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: Color(0xFF2B2B2B),
                  fontFamily: 'Figtree',
                ),
              ),
              if (showRequiredStar) ...const [
                SizedBox(width: 2),
                Text(
                  '*',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFDC2626),
                    fontFamily: 'Figtree',
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 3),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: borderColor,
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value.isNotEmpty ? value : '',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Figtree',
                    color: Colors.black,
                  ),
                ),
                if ((hint ?? '').isNotEmpty && value.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      hint!,
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'Figtree',
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Divider between rows to mimic `border-bottom`.
class _DividerRow extends StatelessWidget {
  final Color borderColor;

  const _DividerRow({
    Key? key,
    required this.borderColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: borderColor,
      indent: 0,
      endIndent: 0,
    );
  }
}

/// Two-column wrapper mirroring `.two-erow` behavior.
class _TwoColumnRow extends StatelessWidget {
  final Widget left;
  final Widget right;
  final Color borderColor;
  final bool isLast;

  const _TwoColumnRow({
    Key? key,
    required this.left,
    required this.right,
    required this.borderColor,
    this.isLast = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Flutter layout is simpler than HTML grid; we just split horizontally.
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: isLast
              ? BorderSide.none
              : BorderSide(color: borderColor, width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left side with right border
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(color: borderColor, width: 1),
                ),
              ),
              child: left,
            ),
          ),
          // Right side
          Expanded(child: right),
        ],
      ),
    );
  }
}

/// Single product card mirroring `.pr-card` / `.pr-head` / `.pr-body` layout,
/// but read-only (no expansion logic or delete buttons).
class _ProductCard extends StatelessWidget {
  final int index;
  final Map<String, dynamic> data;
  final Gradient grad;
  final Color pd;
  final Color muted;
  final Color borderColor;

  const _ProductCard({
    Key? key,
    required this.index,
    required this.data,
    required this.grad,
    required this.pd,
    required this.muted,
    required this.borderColor,
  }) : super(key: key);

  String _s(dynamic v) {
    if (v == null) return '';
    if (v is String) return v;
    return v.toString();
  }

  @override
  Widget build(BuildContext context) {
    final String productName = _s(data['productName']).trim();
    final String uom = _s(data['uom']).trim();
    final String qty = _s(data['quantity']).trim();
    final String mfgBatch =
        _s(data['manufacturingDateBatch']).trim();
    final String remarks = _s(data['remarks']).trim();

    final String labelText =
        productName.isNotEmpty ? productName : 'Product ${index + 1}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // pr-head (non-expandable, just static)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF6B21C8).withOpacity(0.07),
                  const Color(0xFF9C40FF).withOpacity(0.03),
                ],
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    gradient: grad,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      fontFamily: 'Figtree',
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    labelText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Figtree',
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: const Color(0xFF5958B2),
                    ),
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down,
                  size: 17,
                  color: const Color(0xFF5958B2),
                ),
              ],
            ),
          ),

          // pr-body (always visible here)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            decoration: const BoxDecoration(
              color: Colors.white,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ProductField(
                  label: 'Product Name',
                  value: productName,
                  requiredStar: true,
                ),
                const SizedBox(height: 9),
                _ProductField(
                  label: 'UOM',
                  value: uom,
                  requiredStar: true,
                ),
                const SizedBox(height: 9),
                _ProductField(
                  label: 'Quantity',
                  value: qty,
                  requiredStar: true,
                ),
                const SizedBox(height: 9),
                _ProductField(
                  label: 'Manufacturing Date / Batch #',
                  value: mfgBatch,
                  requiredStar: true,
                ),
                const SizedBox(height: 9),
                _ProductField(
                  label: 'Remarks',
                  value: remarks,
                  requiredStar: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductField extends StatelessWidget {
  final String label;
  final String value;
  final bool requiredStar;

  const _ProductField({
    Key? key,
    required this.label,
    required this.value,
    required this.requiredStar,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const Color mainBorder = Color(0xFF6B21C8);
    final Color borderColor = mainBorder.withOpacity(0.22);
    final Color bgColor = mainBorder.withOpacity(0.03);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                color: Color(0xFF2B2B2B),
                fontFamily: 'Figtree',
              ),
            ),
            if (requiredStar) ...const [
              SizedBox(width: 2),
              Text(
                '*',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Figtree',
                  color: Color(0xFFDC2626),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 3),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: borderColor,
              width: 1.5,
            ),
          ),
          child: Text(
            value.isNotEmpty ? value : '',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              fontFamily: 'Figtree',
              color: Colors.black,
            ),
          ),
        ),
      ],
    );
  }
}