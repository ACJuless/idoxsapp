import 'package:flutter/material.dart';

class CustomerLedgerReadonlyPage extends StatelessWidget {
  final Map<String, dynamic> formData;
  final String docId;

  const CustomerLedgerReadonlyPage({
    Key? key,
    required this.formData,
    required this.docId,
  }) : super(key: key);

  // Colors mapped from :root in HTML
  static const Color _colorPd = Color(0xFF4A2371);
  static const Color _colorP = Color(0xFF5958B2);
  static const Color _colorSurface = Color(0xFFF9F5FF);
  static const Color _colorCard = Color(0xFFFFFFFF);
  static const Color _colorText = Color(0xFF000000);
  static const Color _colorMuted = Color(0xFF2B2B2B);
  static const Color _colorBorder = Color(0xFFE9E3F5);
  static const Color _colorGreen = Color(0xFF059669);
  static const Color _colorRed = Color(0xFFDC2626);

  static const double _maxWidth = 760.0;

  LinearGradient get _grad => const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          _colorPd,
          _colorPd,
          _colorP,
        ],
        stops: [0.0, 0.55, 1.0],
      );

  // Utility to safely read string fields
  String _s(dynamic v) => (v ?? '').toString();

  String _formatPeso(num? n) {
    final value = (n ?? 0).toDouble();
    return '₱${value.toStringAsFixed(2)}';
  }

  List<Map<String, dynamic>> _getProducts() {
    final raw = formData['products'];
    if (raw is List) {
      return raw.map<Map<String, dynamic>>((e) {
        if (e is Map<String, dynamic>) return e;
        if (e is Map) {
          return Map<String, dynamic>.from(e);
        }
        return <String, dynamic>{};
      }).toList();
    }
    return <Map<String, dynamic>>[];
  }

  num _calcTotal(Map<String, dynamic> p) {
    final qRaw = p['quantity'];
    final uRaw = p['unitPrice'];
    final q = num.tryParse(_s(qRaw)) ?? 0;
    final u = num.tryParse(_s(uRaw)) ?? 0;
    return q * u;
  }

  num _grandTotal() {
    final explicit = formData['grandTotal'];
    if (explicit is num) return explicit;
    final prods = _getProducts();
    num sum = 0;
    for (final p in prods) {
      sum += _calcTotal(p);
    }
    return sum;
  }

  String _formatDateDisplay(dynamic raw) {
    // In your HTML, submittedDate is stored as datetime-local string "YYYY-MM-DDTHH:mm"
    // and displayed by replacing 'T' with space.
    final s = _s(raw);
    if (s.isEmpty) return '';
    if (s.contains('T')) return s.replaceFirst('T', ' ');
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final products = _getProducts();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Ledger Form'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: _colorPd,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: _grad,
          ),
        ),
      ),
      backgroundColor: _colorSurface,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Container(
            color: _colorSurface,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: _maxWidth,
                ),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 32),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildSectionLabel('Submission Details', first: true),
                        _buildSubmissionDetailsCard(),

                        _buildSectionLabel('Location Details'),
                        _buildLocationDetailsCard(),

                        _buildSectionLabel('Customer Information'),
                        _buildCustomerInfoCard(),

                        _buildSectionLabel('Source Information'),
                        _buildSourceInfoCard(),

                        _buildProductsSection(products),

                        _buildSectionLabel('Remarks'),
                        _buildRemarksCard(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // SECTION LABEL
  Widget _buildSectionLabel(String text, {bool first = false}) {
    return Padding(
      padding: EdgeInsets.only(
        top: first ? 4 : 20,
        bottom: 8,
        left: 8,
      ),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: _colorP,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  // CARD WRAPPER (same look as .form-card)
  Widget _formCard(Widget child) {
    return Container(
      decoration: BoxDecoration(
        color: _colorCard,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }

  // ROW FIELD – used for readonly value (like disabled input)
  Widget _erow({
    required String label,
    required String value,
    bool isLast = false,
    TextAlign textAlign = TextAlign.left,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isLast ? Colors.transparent : const Color(0xFFF0EBF9),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _erowLabel(label),
          const SizedBox(height: 3),
          _erowValue(value, textAlign: textAlign),
        ],
      ),
    );
  }

  Widget _erowLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: _colorMuted,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _erowValue(String text, {TextAlign textAlign = TextAlign.left}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0x1A6B21C8), // rgba(107,33,200,.1-ish)
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: const Color(0x406B21C8), // rgba(107,33,200,.25-ish)
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      child: Text(
        text.isEmpty ? '-' : text,
        textAlign: textAlign,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: _colorText,
        ),
      ),
    );
  }

  // TWO-COLUMN WRAPPER (equivalent to .two-erow-wrap + .two-erow)
  Widget _twoColumnRow({
    required List<Widget> children,
    bool wrapHasBottomBorder = true,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: wrapHasBottomBorder
                ? const Color(0xFFF0EBF9)
                : Colors.transparent,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(child: children[0]),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: Color(0xFFF0EBF9),
                    width: 1,
                  ),
                ),
              ),
              child: children[1],
            ),
          ),
        ],
      ),
    );
  }

  // SUBMISSION DETAILS CARD
  Widget _buildSubmissionDetailsCard() {
    final submittedBy = _s(formData['submittedBy']);
    final controlNumber = _s(formData['controlNumber']);

    final submittedDate =
        _formatDateDisplay(formData['submittedDate']); // disabled dt-local
    final documentDate = _s(formData['documentDate']);
    final documentNumber = _s(formData['documentNumber']);
    final documentType = _s(formData['documentType']);

    return _formCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _twoColumnRow(
            children: [
              _erow(
                label: 'Submitted By',
                value: submittedBy,
                isLast: false,
              ),
              _erow(
                label: 'Control Number',
                value: controlNumber,
                isLast: false,
              ),
            ],
            wrapHasBottomBorder: true,
          ),
          _twoColumnRow(
            children: [
              _erow(
                label: 'Submitted Date',
                value: submittedDate,
                isLast: false,
              ),
              _erow(
                label: 'Document Date',
                value: documentDate,
                isLast: false,
              ),
            ],
            wrapHasBottomBorder: true,
          ),
          _erow(
            label: 'Document Number',
            value: documentNumber,
            isLast: false,
          ),
          _erow(
            label: 'Document Type',
            value: documentType,
            isLast: true,
          ),
        ],
      ),
    );
  }

  // LOCATION DETAILS CARD
  Widget _buildLocationDetailsCard() {
    final province = _s(formData['province']);
    final municipality = _s(formData['municipality']);
    final barangay = _s(formData['barangay']);

    return _formCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _erow(
            label: 'Province',
            value: province,
            isLast: false,
          ),
          _twoColumnRow(
            children: [
              _erow(
                label: 'Municipality',
                value: municipality,
                isLast: false,
              ),
              _erow(
                label: 'Barangay',
                value: barangay,
                isLast: true,
              ),
            ],
            wrapHasBottomBorder: false,
          ),
        ],
      ),
    );
  }

  // CUSTOMER INFORMATION CARD
  Widget _buildCustomerInfoCard() {
    final customerName = _s(formData['customerName']);
    final customerClassification =
        _s(formData['customerClassification']);

    return _formCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _erow(
            label: 'Customer Name',
            value: customerName,
            isLast: false,
          ),
          _erow(
            label: 'Customer Classification',
            value: customerClassification,
            isLast: true,
          ),
        ],
      ),
    );
  }

  // SOURCE INFORMATION CARD
  Widget _buildSourceInfoCard() {
    final sourceType = _s(formData['sourceType']);
    final sourceName = _s(formData['sourceName']);

    return _formCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _twoColumnRow(
            children: [
              _erow(
                label: 'Source Type',
                value: sourceType,
                isLast: false,
              ),
              _erow(
                label: 'Source Name',
                value: sourceName,
                isLast: true,
              ),
            ],
            wrapHasBottomBorder: false,
          ),
        ],
      ),
    );
  }

  // PRODUCTS SECTION
  Widget _buildProductsSection(List<Map<String, dynamic>> products) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // pt-bar (without "Add Product" button since this is readonly)
        Padding(
          padding: const EdgeInsets.only(
            top: 20,
            left: 8,
            right: 8,
            bottom: 8,
          ),
          child: Row(
            children: const [
              Text(
                'PRODUCTS',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _colorP,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),

        // List of product cards
        ...List.generate(
          products.length,
          (index) => _buildProductCard(products[index], index),
        ),

        // Grand Total card
        _formCard(
          Container(
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Color(0xFFF0EBF9),
                  width: 2,
                ),
              ),
              color: Color(0x056B21C8), // rgba(107,33,200,.03)
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'GRAND TOTAL',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _colorMuted,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                Text(
                  _formatPeso(_grandTotal()),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _colorP,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product, int index) {
    final productName = _s(product['product']);
    final packaging =
        _s(product['packaging'] ?? product['productPackaging']);
    final category =
        _s(product['category'] ?? product['productCategory']);
    final quantity = _s(product['quantity']);
    final unit = _s(product['unit']);
    final unitPrice = _s(product['unitPrice']);
    final totalAmount = _calcTotal(product);

    final title = productName.isNotEmpty
        ? productName
        : 'Product ${index + 1}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _colorCard,
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
          // pt-head (readonly, no expand/collapse here – always open)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0x126B21C8), // rgba(107,33,200,.07)
                  const Color(0x089C40FF), // approx to your second color
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    gradient: _grad,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _colorP,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // pt-body (always open)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ptRow(
                  label: 'Product',
                  value: productName,
                ),
                _ptRowDisabled(
                  label: 'Packaging',
                  value: packaging,
                ),
                _ptRowDisabled(
                  label: 'Product Category',
                  value: category,
                ),
                _ptRow(
                  label: 'Quantity',
                  value: quantity,
                ),
                _ptRow(
                  label: 'Unit',
                  value: unit,
                ),
                _ptRowCurrency(
                  label: 'Unit Price',
                  value: unitPrice,
                ),
                _ptRowDisabled(
                  label: 'Total Amount',
                  value: _formatPeso(totalAmount),
                  emphasize: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // PRODUCT ROWS (pt-erow equivalents)

  Widget _ptRow({
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ptLabel(label),
          const SizedBox(height: 3),
          _ptValue(value),
        ],
      ),
    );
  }

  Widget _ptRowDisabled({
    required String label,
    required String value,
    bool emphasize = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ptLabel(label),
          const SizedBox(height: 3),
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0x105958B2), // rgba(89,88,178,.06)
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0x335958B2), // rgba(89,88,178,.2)
                width: 1.5,
              ),
            ),
            child: Text(
              value.isEmpty ? '-' : value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
                color: emphasize ? _colorP : _colorText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ptRowCurrency({
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ptLabel(label),
          const SizedBox(height: 3),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0x0D6B21C8), // rgba(107,33,200,.03)
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0x386B21C8), // rgba(107,33,200,.22)
                width: 1.5,
              ),
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                const Text(
                  '₱',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _colorMuted,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    value.isEmpty ? '-' : value,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: _colorText,
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

  Widget _ptLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        color: _colorMuted,
        letterSpacing: 0.4,
      ),
    );
  }

  Widget _ptValue(String text) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x0D6B21C8), // rgba(107,33,200,.03)
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0x386B21C8), // rgba(107,33,200,.22)
          width: 1.5,
        ),
      ),
      child: Text(
        text.isEmpty ? '-' : text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: _colorText,
        ),
      ),
    );
  }

  // REMARKS CARD
  Widget _buildRemarksCard() {
    final remarks = _s(formData['remarks']);

    return _formCard(
      _erow(
        label: 'Remarks',
        value: remarks,
        isLast: true,
      ),
    );
  }
}