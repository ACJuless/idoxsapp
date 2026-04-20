import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'sales_order_form_page.dart';

const Color _kPrimary     = Color(0xFF5958B2);
const Color _kPrimaryDark = Color(0xFF4A2371);
const Color _kSurface     = Color(0xFFF9F5FF);

class SalesOrderFormTransactionsPage extends StatefulWidget {
  const SalesOrderFormTransactionsPage({Key? key}) : super(key: key);

  @override
  State<SalesOrderFormTransactionsPage> createState() =>
      _SalesOrderFormTransactionsPageState();
}

class _SalesOrderFormTransactionsPageState
    extends State<SalesOrderFormTransactionsPage> {
  String userKey = '';

  @override
  void initState() {
    super.initState();
    _loadKey();
  }

  Future<void> _loadKey() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('userEmail') ?? '';
    setState(() {
      userKey = email.replaceAll(RegExp(r'[.#\$\\\[\]/]'), '_');
    });
  }

  void _openView(Map<String, dynamic> data, String docId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SalesOrderFormPage(
          formData: data,
          docId: docId,
          readonly: true,
        ),
      ),
    ).then((res) { if (res == true) setState(() {}); });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kSurface,
      body: Column(
        children: [
          _buildAppBar(context),
          Expanded(
            child: userKey.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('flowDB')
                        .doc('users')
                        .collection(userKey)
                        .doc('sales_orders')
                        .collection('sales_orders')
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                    builder: (ctx, snap) {
                      if (!snap.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final docs = snap.data!.docs;
                      if (docs.isEmpty) return _buildEmpty();
                      return _buildGrid(docs);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_kPrimaryDark, _kPrimaryDark, _kPrimary],
            stops: [0, 0.55, 1],
          ),
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(22),
            bottomRight: Radius.circular(22),
          ),
          boxShadow: [
            BoxShadow(
                color: Color(0x4D4A2371),
                blurRadius: 28,
                offset: Offset(0, 6)),
          ],
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            child: Row(
              children: [
                _appBarBtn(
                  icon: Icons.chevron_left,
                  size: 22,
                  onTap: () => Navigator.pop(context),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text('Sales Order',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.white60,
                              fontWeight: FontWeight.w400)),
                      Text('Transactions',
                          style: TextStyle(
                              fontSize: 17,
                              color: Colors.white,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _appBarBtn({
    required IconData icon,
    double size = 18,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: Colors.white, size: size),
        ),
      );

  Widget _buildEmpty() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text('No sales orders yet.',
                style: TextStyle(fontSize: 16, color: Color(0xFF9CA3AF))),
            const SizedBox(height: 6),
            const Text('Tap "+ New Order" to create one.',
                style: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF))),
          ],
        ),
      );

  Widget _buildGrid(List<QueryDocumentSnapshot> docs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: GridView.builder(
        itemCount: docs.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.88,
        ),
        itemBuilder: (ctx, idx) {
          final doc  = docs[idx];
          final data = doc.data() as Map<String, dynamic>;
          return _transactionCard(data, doc.id, docs.length - idx);
        },
      ),
    );
  }

  Widget _transactionCard(Map<String, dynamic> data, String docId, int txNum) {
    final mrName      = data['mrName']      ?? '';
    final soldTo      = data['soldTo']      ?? '';
    final dateOfOrder = data['dateOfOrder'] ?? '—';
    final netAmount   = (data['netAmount'] as num?)?.toDouble() ?? 0.0;

    return GestureDetector(
      onTap: () => _openView(data, docId),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_kPrimaryDark, Color(0xFF6B4BAD), _kPrimary],
            stops: [0, 0.55, 1],
          ),
          boxShadow: [
            BoxShadow(
                color: _kPrimaryDark.withValues(alpha: 0.30),
                blurRadius: 14,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: receipt icon + tx number + edit button
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.receipt_long, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Transaction #$txNum',
                      style: const TextStyle(
                          color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _openView(data, docId),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.edit_outlined, color: Colors.white, size: 11),
                          SizedBox(width: 3),
                          Text('Edit',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      mrName.isNotEmpty ? mrName : 'Unnamed',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          height: 1.2),
                    ),
                    const SizedBox(height: 6),
                    _cardMeta(Icons.store_outlined,
                        soldTo.isNotEmpty ? soldTo : '—'),
                    const SizedBox(height: 3),
                    _cardMeta(Icons.calendar_today_outlined, dateOfOrder),
                  ],
                ),
              ),
              if (netAmount > 0) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '₱ ${netAmount.toStringAsFixed(2).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',')}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _cardMeta(IconData icon, String text) => Row(
        children: [
          Icon(icon, color: Colors.white54, size: 11),
          const SizedBox(width: 4),
          Expanded(
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white60, fontSize: 11)),
          ),
        ],
      );
}