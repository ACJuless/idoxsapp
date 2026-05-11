import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class F2FVisitReadonlyPage extends StatelessWidget {
  final Map<String, dynamic> formData;
  final String docId;

  const F2FVisitReadonlyPage({
    Key? key,
    required this.formData,
    required this.docId,
  }) : super(key: key);

  // Colors and design tokens inspired by f2f_visit_form.html
  // --pd: #4A2371;
  // --p: #5958B2;
  // --surface: #F9F5FF;
  // --card: #FFFFFF;
  // --text: #000000;
  // --muted: #2B2B2B;
  // --border: #E9E3F5;
  static const Color _pd = Color(0xFF4A2371);
  static const Color _p = Color(0xFF5958B2);
  static const Color _surface = Color(0xFFF9F5FF);
  static const Color _card = Color(0xFFFFFFFF);
  static const Color _text = Color(0xFF000000);
  static const Color _muted = Color(0xFF2B2B2B);

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

    if (value is Timestamp) {
      dt = value.toDate();
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
      return fallback;
    }
    return '${monthNames[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  // Core "row" as in .erow, but read-only
  Widget _buildRow({
    required String label,
    required String value,
    int maxLines = 1,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFF0EBF9), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // .erow .lbl
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontFamily: 'Figtree',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _muted,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 5),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFECE7F7), // rgba(107,33,200,.04) approx
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: const Color(0xFFB39AD7), // rgba(107,33,200,.25) approx
                width: 1.5,
              ),
            ),
            child: Text(
              value.isEmpty ? '-' : value,
              maxLines: maxLines,
              overflow:
                  maxLines == 1 ? TextOverflow.ellipsis : TextOverflow.visible,
              style: const TextStyle(
                fontFamily: 'Figtree',
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: _text,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Row variant for disabled/select look (still read-only)
  Widget _buildDisabledRow({
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFF0EBF9), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontFamily: 'Figtree',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _muted,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 5),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: const Color(0xFFDDDDDD),
                width: 1.5,
              ),
              color: const Color(0xFFEFEFEF),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value.isEmpty ? '-' : value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Figtree',
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF777777),
                    ),
                  ),
                ),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: Color(0xFFAAAAAA),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Multiline textarea-like view
  Widget _buildTextAreaRow({
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFF0EBF9), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontFamily: 'Figtree',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _muted,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 5),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFECE7F7),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: const Color(0xFFB39AD7),
                width: 1.5,
              ),
            ),
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(
                fontFamily: 'Figtree',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: _text,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Section label (.sec-label)
  Widget _buildSectionLabel(String text, {bool first = false}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        8,
        first ? 4 : 20,
        8,
        8,
      ),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontFamily: 'Figtree',
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: _p,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  // Card container (.form-card)
  Widget _buildCard(Widget child) {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 14,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }

  // "Group row" (Hectarage, FBTS)
  Widget _buildGroupRow(String label) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 9, 16, 5),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFF0EBF9), width: 1),
        ),
      ),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontFamily: 'Figtree',
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: _p,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  // 2-column layout (.two-erow)
  Widget _buildTwoColumn(Widget left, Widget right) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFF0EBF9), width: 1),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 520) {
            // stack on small width (like media query in HTML)
            return Column(
              children: [
                left,
                right,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    border: Border(
                      right: BorderSide(color: Color(0xFFF0EBF9), width: 1),
                    ),
                  ),
                  child: left,
                ),
              ),
              Expanded(child: right),
            ],
          );
        },
      ),
    );
  }

  // 3-column layout (.three-erow)
  Widget _buildThreeColumn(Widget c1, Widget c2, Widget c3) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFF0EBF9), width: 1),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 520) {
            return Column(
              children: [c1, c2, c3],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    border: Border(
                      right: BorderSide(color: Color(0xFFF0EBF9), width: 1),
                    ),
                  ),
                  child: c1,
                ),
              ),
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    border: Border(
                      right: BorderSide(color: Color(0xFFF0EBF9), width: 1),
                    ),
                  ),
                  child: c2,
                ),
              ),
              Expanded(child: c3),
            ],
          );
        },
      ),
    );
  }

  // A simple "tag" chip row for activity tags DGA / Other
  Widget _buildActivityTagsRow(bool dga, bool other) {
    String selected = '';
    if (dga && other) {
      selected = 'DGA, Other Activity';
    } else if (dga) {
      selected = 'DGA';
    } else if (other) {
      selected = 'Other Activity';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFF0EBF9), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ACTIVITY TAGS',
            style: TextStyle(
              fontFamily: 'Figtree',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _muted,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 5),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildActivityChip('DGA', dga),
              _buildActivityChip('Other Activity', other),
            ],
          ),
          if (!dga && !other)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                '-',
                style: TextStyle(
                  fontFamily: 'Figtree',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF777777),
                ),
              ),
            ),
          if (selected.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                selected,
                style: const TextStyle(
                  fontFamily: 'Figtree',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF555555),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActivityChip(String label, bool selected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: selected
            ? const Color(0xFF4A2371).withOpacity(0.10)
            : const Color(0xFFE5E7EB),
        border: Border.all(
          color: selected ? const Color(0xFF4A2371) : const Color(0xFFD1D5DB),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selected)
            const Icon(
              Icons.check_rounded,
              size: 14,
              color: Color(0xFF4A2371),
            ),
          if (selected) const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Figtree',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? const Color(0xFF4A2371) : const Color(0xFF4B5563),
            ),
          ),
        ],
      ),
    );
  }

  // Build "Products to promote" list as bullet items
  Widget _buildProductsToPromote(List<dynamic> products) {
    if (products.isEmpty) {
      return _buildTextAreaRow(label: 'Products to Promote', value: '');
    }

    final String joined = products
        .map((p) {
          if (p is String) return p;
          if (p is Map && p['val'] != null) return p['val'].toString();
          return '';
        })
        .where((e) => e.trim().isNotEmpty)
        .join('\n• ');

    final String display =
        joined.isEmpty ? '' : '• $joined'; // show bullet at start

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFF0EBF9), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PRODUCTS TO PROMOTE',
            style: TextStyle(
              fontFamily: 'Figtree',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _muted,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 5),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFECE7F7),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: const Color(0xFFB39AD7),
                width: 1.5,
              ),
            ),
            child: Text(
              display.isEmpty ? '-' : display,
              style: const TextStyle(
                fontFamily: 'Figtree',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: _text,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Build "Standing crop" section (simplified, read-only summary)
  Widget _buildStandingCropSection(Map<String, dynamic> s) {
    final bool standingCrop = s['standingCrop'] == true;
    final String scDapDafi = (s['scDapDafi'] ?? '').toString().trim();
    final List<dynamic> scInfo = (s['scInfo'] as List<dynamic>? ?? []);

    if (!standingCrop && scDapDafi.isEmpty && scInfo.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0xFFF0EBF9), width: 1),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'WITH STANDING CROP?',
              style: TextStyle(
                fontFamily: 'Figtree',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _muted,
                letterSpacing: 0.5,
              ),
            ),
            SizedBox(height: 5),
            Text(
              '-',
              style: TextStyle(
                fontFamily: 'Figtree',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF555555),
              ),
            ),
          ],
        ),
      );
    }

    final List<Widget> cards = [];
    for (int i = 0; i < scInfo.length; i++) {
      final item = scInfo[i];
      if (item is! Map) continue;
      final crop = (item['crop'] ?? '').toString();
      final List<dynamic> products = item['products'] as List<dynamic>? ?? [];
      final String productsText = products
          .map((p) => p.toString())
          .where((p) => p.trim().isNotEmpty)
          .join(', ');

      cards.add(
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F0FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFCBC1EE),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Crop Entry ${i + 1}',
                    style: const TextStyle(
                      fontFamily: 'Figtree',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _p,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Crop',
                style: TextStyle(
                  fontFamily: 'Figtree',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: _muted,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 3),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFECE7F7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFB39AD7),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  crop.isEmpty ? '-' : crop,
                  style: const TextStyle(
                    fontFamily: 'Figtree',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _text,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Product / Vegetable Name',
                style: TextStyle(
                  fontFamily: 'Figtree',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: _muted,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 3),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFECE7F7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFB39AD7),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  productsText.isEmpty ? '-' : productsText,
                  style: const TextStyle(
                    fontFamily: 'Figtree',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _text,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Color(0xFFF0EBF9), width: 1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'WITH STANDING CROP?',
                style: TextStyle(
                  fontFamily: 'Figtree',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _muted,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                standingCrop ? 'Yes' : 'No',
                style: const TextStyle(
                  fontFamily: 'Figtree',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF555555),
                ),
              ),
            ],
          ),
        ),
        if (standingCrop)
          _buildRow(
            label: 'DAP / DAFI of Standing Crop',
            value: scDapDafi,
          ),
        if (standingCrop && cards.isNotEmpty)
          Container(
            padding:
                const EdgeInsets.fromLTRB(16, 10, 16, 10), // sc-info-list
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFF0EBF9), width: 1),
              ),
            ),
            child: Column(
              children: cards,
            ),
          ),
      ],
    );
  }

  // "Current crop protection" read-only summary
  Widget _buildCCPSection(List<dynamic> rows) {
    if (rows.isEmpty) {
      return _buildTextAreaRow(
        label: 'Current Crop Protection Used',
        value: '',
      );
    }

    final List<Widget> cards = [];
    for (int i = 0; i < rows.length; i++) {
      final r = rows[i];
      if (r is! Map) continue;
      final crop = (r['crop'] ?? '').toString();
      final stage = (r['stage'] ?? '').toString();
      final brand = (r['brand'] ?? '').toString();
      final category = (r['category'] ?? '').toString();

      cards.add(
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F0FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFCBC1EE),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                  color: const Color(0xFFEDE9FF),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Entry ${i + 1}',
                      style: const TextStyle(
                        fontFamily: 'Figtree',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _p,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Column(
                  children: [
                    _buildECField('Crop', crop),
                    const SizedBox(height: 8),
                    _buildECField('Crop Stage', stage),
                    const SizedBox(height: 8),
                    _buildECField('Brand Name', brand),
                    const SizedBox(height: 8),
                    _buildECField('Product Category', category),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFF0EBF9), width: 1),
        ),
      ),
      child: Column(
        children: cards,
      ),
    );
  }

  Widget _buildECField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontFamily: 'Figtree',
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: _muted,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 3),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFFECE7F7),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0xFFB39AD7),
              width: 1.5,
            ),
          ),
          child: Text(
            value.isEmpty ? '-' : value,
            style: const TextStyle(
              fontFamily: 'Figtree',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: _text,
            ),
          ),
        ),
      ],
    );
  }

  // Visit objectives: read-only list
  Widget _buildObjectives(List<dynamic> objs) {
    if (objs.isEmpty) {
      return _buildTextAreaRow(
        label: 'Visit Objectives',
        value: '',
      );
    }

    final List<Widget> rows = [];
    for (int i = 0; i < objs.length; i++) {
      final o = objs[i];
      if (o is! Map) continue;
      final String type = (o['type'] ?? '').toString();
      final String val = (o['value'] ?? o['objective'] ?? '').toString();
      final String custom = (o['customText'] ?? '').toString();
      final String notes = (o['notes'] ?? '').toString();

      final String mainText =
          type == 'custom' ? (custom.isNotEmpty ? custom : val) : val;

      rows.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: i == objs.length - 1
                    ? Colors.transparent
                    : const Color(0xFFF0EBF9),
                width: 1,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${i + 1}',
                style: const TextStyle(
                  fontFamily: 'Figtree',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _p,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mainText.isEmpty ? '-' : mainText,
                      style: const TextStyle(
                        fontFamily: 'Figtree',
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: _text,
                      ),
                    ),
                    if (notes.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        notes,
                        style: const TextStyle(
                          fontFamily: 'Figtree',
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF4B5563),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(children: rows);
  }

  // Actual sales order + rows (summary)
  Widget _buildSalesSection(Map<String, dynamic> s) {
    final String actual = (s['actualSalesOrder'] ?? '').toString();
    final List<dynamic> rows = (s['salesRows'] as List<dynamic>? ?? []);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Color(0xFFF0EBF9), width: 1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ACTUAL SALES ORDER?',
                style: TextStyle(
                  fontFamily: 'Figtree',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _muted,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                actual.isEmpty ? '-' : actual,
                style: const TextStyle(
                  fontFamily: 'Figtree',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF555555),
                ),
              ),
            ],
          ),
        ),
        if (rows.isNotEmpty)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFF0EBF9), width: 1),
              ),
            ),
            child: Column(
              children: [
                for (int i = 0; i < rows.length; i++)
                  _buildSalesCard(rows[i] as Map, i),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSalesCard(Map row, int index) {
    final String product = (row['product'] ?? '').toString();
    final String uom = (row['uom'] ?? '').toString();
    final String qty = (row['qty'] ?? '').toString();
    final String price = (row['price'] ?? '').toString();
    final String total = (row['total'] ?? '').toString();
    final String deliveryDate = (row['deliveryDate'] ?? '').toString();
    final String dealer1 = (row['dealer1'] ?? '').toString();
    final String dealer2 = (row['dealer2'] ?? '').toString();
    final String dist1 = (row['dist1'] ?? '').toString();
    final String dist2 = (row['dist2'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F0FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFCBC1EE),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              color: const Color(0xFFEDE9FF),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order Item ${index + 1}',
                  style: const TextStyle(
                    fontFamily: 'Figtree',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _p,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              children: [
                _buildECField('Product', product),
                const SizedBox(height: 8),
                _buildECField('UOM', uom),
                const SizedBox(height: 8),
                _buildECField('Quantity', qty),
                const SizedBox(height: 8),
                _buildECField('Unit Price (₱)', price),
                const SizedBox(height: 8),
                _buildECField('Total Value (₱)', total),
                const SizedBox(height: 8),
                _buildECField('Target Delivery Date', deliveryDate),
                const SizedBox(height: 8),
                _buildECField('Dealer 1', dealer1),
                const SizedBox(height: 8),
                _buildECField('Dealer 2', dealer2),
                const SizedBox(height: 8),
                _buildECField('Distributor 1', dist1),
                const SizedBox(height: 8),
                _buildECField('Distributor 2', dist2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Signature + consent as read-only info
  Widget _buildSignatureConsent(Map<String, dynamic> s) {
    final bool consent = s['consent'] == true;
    final String consentText = consent
        ? 'Consent given'
        : 'No consent recorded'; // descriptive text; signature image not shown here

    return Column(
      children: [
        _buildTextAreaRow(
          label: "Customer's Signature",
          value: s['signature'] != null &&
                  s['signature'].toString().trim().isNotEmpty
              ? 'Signature captured (image data stored)'
              : 'No signature captured',
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Color(0xFFF0EBF9), width: 1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CONSENT',
                style: TextStyle(
                  fontFamily: 'Figtree',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _muted,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                consentText,
                style: TextStyle(
                  fontFamily: 'Figtree',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: consent ? const Color(0xFF059669) : const Color(0xFFB91C1C),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // normalize data from Firestore payload produced by HTML form
    final Map<String, dynamic> s = Map<String, dynamic>.from(formData);

    final String name = (s['name'] ?? '').toString().trim();
    final String visitRefNo = (s['visitRefNo'] ?? '').toString().trim();
    final String districtCode =
        (s['districtCode'] ?? '').toString().trim();
    final String territoryCode =
        (s['territoryCode'] ?? '').toString().trim();

    final String province = (s['province'] ?? '').toString().trim();
    final String municipality =
        (s['municipality'] ?? '').toString().trim();
    final String barangay = (s['barangay'] ?? '').toString().trim();
    final String organizationName =
        (s['organizationName'] ?? '').toString().trim();
    final String customerName =
        (s['customerName'] ?? '').toString().trim();
    final String storeName = (s['storeName'] ?? '').toString().trim();
    final String mobileNumber =
        (s['mobileNumber'] ?? '').toString().trim();
    final String dob = (s['dob'] ?? '').toString().trim();
    final String gcimRating =
        (s['gcimRating'] ?? '').toString().trim();
    final String customerType =
        (s['customerType'] ?? '').toString().trim();
    final String customerProfile =
        (s['customerProfile'] ?? '').toString().trim();
    final String visitStatus =
        (s['visitStatus'] ?? '').toString().trim();
    final bool dgaCheck = s['dgaCheck'] == true;
    final bool otherActivityCheck = s['otherActivityCheck'] == true;

    final String focusCrop1 =
        (s['focusCrop1'] ?? '').toString().trim();
    final String focusCrop2 =
        (s['focusCrop2'] ?? '').toString().trim();
    final String focusCrop3 =
        (s['focusCrop3'] ?? '').toString().trim();
    final String aoa = (s['aoa'] ?? '').toString().trim();
    final String specVeg1 =
        (s['specVeg1'] ?? '').toString().trim();
    final String specVeg2 =
        (s['specVeg2'] ?? '').toString().trim();
    final String specVeg3 =
        (s['specVeg3'] ?? '').toString().trim();

    final String hectarageOwned =
        (s['hectarageOwned'] ?? '').toString().trim();
    final String hectarageFinanced =
        (s['hectarageFinanced'] ?? '').toString().trim();
    final String industryHectarage =
        (s['industryHectarage'] ?? '').toString().trim();
    final String fbtsOwned =
        (s['fbtsOwned'] ?? '').toString().trim();
    final String fbtsContracted =
        (s['fbtsContracted'] ?? '').toString().trim();
    final String industryFbts =
        (s['industryFbts'] ?? '').toString().trim();
    final String remarks = (s['remarks'] ?? '').toString().trim();

    final List<dynamic> productsToPromote =
        (s['productsToPromote'] as List<dynamic>? ?? []);
    final List<dynamic> ccpRows =
        (s['ccpRows'] as List<dynamic>? ?? []);
    final List<dynamic> visitObjectives =
        (s['visitObjectives'] as List<dynamic>? ??
            (s['visitObjectivesRaw'] as List<dynamic>? ??
                []));

    final String visitOutcome =
        (s['visitOutcome'] ?? '').toString().trim();

    final String visitDate = _formatReadableDate(
      s['visitDate'] ?? s['timestamp'],
      fallback: '',
    );
    final String visitTime =
        (s['visitTime'] ?? '').toString().trim();

    final String title = customerName.isNotEmpty
        ? customerName
        : (storeName.isNotEmpty
            ? storeName
            : 'F2F Visit Details');

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: 'Figtree',
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        elevation: 3,
        centerTitle: true,
        backgroundColor: _pd,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.fromLTRB(14, 14, 14, 32),
              child: Center(
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(maxWidth: 760),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      // GENERAL INFORMATION
                      _buildSectionLabel(
                        'General Information',
                        first: true,
                      ),
                      _buildCard(
                        Column(
                          children: [
                            _buildTwoColumn(
                              _buildDisabledRow(
                                label: 'Visit Reference Number',
                                value: visitRefNo,
                              ),
                              _buildRow(
                                label: 'Name of User',
                                value: name,
                              ),
                            ),
                            _buildTwoColumn(
                              _buildRow(
                                label: 'Date of Visit',
                                value: visitDate,
                              ),
                              _buildRow(
                                label: 'Time of Visit',
                                value: visitTime,
                              ),
                            ),
                            _buildTwoColumn(
                              _buildRow(
                                label: 'District Code',
                                value: districtCode,
                              ),
                              _buildRow(
                                label: 'Territory Code',
                                value: territoryCode,
                              ),
                            ),
                            _buildThreeColumn(
                              _buildRow(
                                label: 'Province',
                                value: province,
                              ),
                              _buildRow(
                                label: 'Municipality',
                                value: municipality,
                              ),
                              _buildRow(
                                label: 'Barangay',
                                value: barangay,
                              ),
                            ),
                            _buildTwoColumn(
                              _buildDisabledRow(
                                label: 'Customer Type',
                                value: customerType,
                              ),
                              _buildDisabledRow(
                                label: 'Customer Profile',
                                value: customerProfile,
                              ),
                            ),
                            _buildTwoColumn(
                              _buildRow(
                                label: 'Organization Name',
                                value: organizationName,
                              ),
                              _buildRow(
                                label: 'Customer Name',
                                value: customerName,
                              ),
                            ),
                            _buildTwoColumn(
                              _buildRow(
                                label: 'Store Name',
                                value: storeName,
                              ),
                              _buildRow(
                                label: 'Mobile Number',
                                value: mobileNumber,
                              ),
                            ),
                            _buildTwoColumn(
                              _buildRow(
                                label: 'Date of Birth',
                                value: dob.isEmpty
                                    ? '-'
                                    : _formatReadableDate(dob),
                              ),
                              _buildDisabledRow(
                                label: 'G-CIM Rating',
                                value: gcimRating,
                              ),
                            ),
                            _buildTwoColumn(
                              _buildRow(
                                label: 'Visit Status',
                                value: visitStatus,
                              ),
                              _buildActivityTagsRow(
                                dgaCheck,
                                otherActivityCheck,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // CROP PROFILE
                      _buildSectionLabel('Crop Profile'),
                      _buildCard(
                        Column(
                          children: [
                            _buildThreeColumn(
                              _buildDisabledRow(
                                label: 'Focus Crop 1',
                                value: focusCrop1,
                              ),
                              _buildDisabledRow(
                                label: 'Focus Crop 2',
                                value: focusCrop2,
                              ),
                              _buildDisabledRow(
                                label: 'Focus Crop 3',
                                value: focusCrop3,
                              ),
                            ),
                            _buildRow(
                              label: 'AOA',
                              value: aoa,
                            ),
                            _buildThreeColumn(
                              _buildRow(
                                label: 'Specific Vegetable 1',
                                value: specVeg1,
                              ),
                              _buildRow(
                                label: 'Specific Vegetable 2',
                                value: specVeg2,
                              ),
                              _buildRow(
                                label: 'Specific Vegetable 3',
                                value: specVeg3,
                              ),
                            ),
                            _buildGroupRow('Hectarage'),
                            _buildThreeColumn(
                              _buildRow(
                                label: 'Owned',
                                value: hectarageOwned,
                              ),
                              _buildRow(
                                label: 'Financed',
                                value: hectarageFinanced,
                              ),
                              _buildRow(
                                label: 'Industry',
                                value: industryHectarage,
                              ),
                            ),
                            _buildGroupRow('FBTS'),
                            _buildThreeColumn(
                              _buildRow(
                                label: 'Owned',
                                value: fbtsOwned,
                              ),
                              _buildRow(
                                label: 'Contracted',
                                value: fbtsContracted,
                              ),
                              _buildRow(
                                label: 'Industry',
                                value: industryFbts,
                              ),
                            ),
                            _buildTextAreaRow(
                              label: 'Remarks',
                              value: remarks,
                            ),
                          ],
                        ),
                      ),

                      // PRODUCTS TO PROMOTE
                      _buildSectionLabel('Products to Promote'),
                      _buildCard(
                        _buildProductsToPromote(productsToPromote),
                      ),

                      // STANDING CROP
                      _buildSectionLabel('Standing Crop'),
                      _buildCard(
                        _buildStandingCropSection(s),
                      ),

                      // CURRENT CROP PROTECTION
                      _buildSectionLabel(
                        'Current Crop Protection Used',
                      ),
                      _buildCard(
                        _buildCCPSection(ccpRows),
                      ),

                      // VISIT OBJECTIVES
                      _buildSectionLabel('Visit Objectives'),
                      _buildCard(
                        _buildObjectives(visitObjectives),
                      ),

                      // ACTUAL SALES ORDER
                      _buildSectionLabel('Actual Sales Order'),
                      _buildCard(
                        _buildSalesSection(s),
                      ),

                      // VISIT OUTCOME
                      _buildSectionLabel('Visit Outcome'),
                      _buildCard(
                        _buildTextAreaRow(
                          label: 'Visit Outcome / Other Remarks',
                          value: visitOutcome,
                        ),
                      ),

                      // SIGNATURE & CONSENT
                      _buildSectionLabel(
                        'Customer Signature & Consent',
                      ),
                      _buildCard(
                        _buildSignatureConsent(s),
                      ),

                      const SizedBox(height: 16),
                      // meta info
                      _buildCard(
                        Column(
                          children: [
                            _buildRow(
                              label: 'Document ID',
                              value: docId,
                            ),
                            _buildRow(
                              label: 'Created by (email)',
                              value: (s['createdBy'] ?? '').toString(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 9),
        ],
      ),
    );
  }
}