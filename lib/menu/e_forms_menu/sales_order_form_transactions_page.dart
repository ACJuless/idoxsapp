import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'sales_order_form_page.dart';

class SalesOrderFormTransactionsPage extends StatefulWidget {
  @override
  _SalesOrderFormTransactionsPageState createState() =>
      _SalesOrderFormTransactionsPageState();
}

class _SalesOrderFormTransactionsPageState
    extends State<SalesOrderFormTransactionsPage> {
  String userKey = '';

  @override
  void initState() {
    super.initState();
    _loadEmailKey();
  }

  Future<void> _loadEmailKey() async {
    final prefs = await SharedPreferences.getInstance();
    final userEmail = prefs.getString('userEmail') ?? '';
    setState(() {
      userKey = userEmail.replaceAll(RegExp(r'[.#\$\\\[\]/]'), '_');
    });
  }

  Future<void> _navigateToAddForm(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SalesOrderFormPage()),
    );
    if (result == true) setState(() {});
  }

  void _openDetail(BuildContext context, Map<String, dynamic> formData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            SalesOrderFormPage(formData: formData, readonly: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double cardWidth = (MediaQuery.of(context).size.width - 48) / 2;
    final double cardHeight = 170.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Sales Order Transactions"),
        backgroundColor: const Color(0xFF5958b2),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: "New Sales Order",
            onPressed: () => _navigateToAddForm(context),
          ),
        ],
      ),
      backgroundColor: Colors.white,
      body: userKey.isEmpty
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
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      "No sales order forms yet. Tap + to create a new.",
                      style: TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  child: GridView.builder(
                    itemCount: docs.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: cardWidth / cardHeight,
                    ),
                    itemBuilder: (context, idx) {
                      final data =
                          docs[idx].data() as Map<String, dynamic>;
                      final mrName = data["mrName"] ?? "";
                      final soldTo = data["soldTo"] ?? "";
                      final dateOfOrder = data["dateOfOrder"] ?? "-";

                      // Descending transaction number (first cell = highest)
                      final transactionNumber = docs.length - idx;
                      final transactionLabel =
                          "Transaction #$transactionNumber";

                      return SizedBox(
                        width: cardWidth,
                        height: cardHeight,
                        child: Card(
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => _openDetail(context, data),
                            child: Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF54479d),
                                    Color(0xFF826ca4),
                                  ],
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.receipt_long,
                                          color: Colors.white,
                                          size: 30,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            transactionLabel,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Expanded(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            mrName.isNotEmpty
                                                ? mrName
                                                : "Unnamed Sales Order",
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            "Sold to: $soldTo",
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            "Date: $dateOfOrder",
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12,
                                            ),
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
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
