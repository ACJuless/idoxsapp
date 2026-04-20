import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'incidental_coverage_form_page.dart';

const _kGrad = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF4A2371), Color(0xFF4A2371), Color(0xFF5958B2)],
  stops: [0.0, 0.55, 1.0],
);

class IncidentalCoverageFormTransactionsPage extends StatefulWidget {
  @override
  _IncidentalCoverageFormTransactionsPageState createState() =>
      _IncidentalCoverageFormTransactionsPageState();
}

class _IncidentalCoverageFormTransactionsPageState
    extends State<IncidentalCoverageFormTransactionsPage> {
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

  Future<void> _navigateToAddForm() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => IncidentalCoverageFormTransactionsPage()),
    );
    if (result == true) setState(() {});
  }

  void _openFormDetail(Map<String, dynamic> data, String docId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => IncidentalCoverageFormPage(
          formData: data,
          // readonly: true,
          docId:    docId,
          userKey:  userKey,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double cardWidth  = (MediaQuery.of(context).size.width - 48) / 2;
    const double cardHeight = 170.0;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(68),
        child: AppBar(
          automaticallyImplyLeading: false,
          elevation: 0,
          backgroundColor: Colors.transparent,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
              gradient: _kGrad,
              boxShadow: [BoxShadow(
                color: Color.fromRGBO(76, 29, 149, 0.3),
                blurRadius: 28, offset: Offset(0, 6),
              )],
            ),
          ),
          titleSpacing: 0,
          title: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(children: [
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      size: 18, color: Colors.white),
                  padding: EdgeInsets.zero,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.18),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9)),
                    minimumSize: const Size(34, 34),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Incidental Coverage Forms',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700, 
                        color: Colors.white
                      )
                  ),
                ),
                IconButton(
                  onPressed: _navigateToAddForm,
                  icon: const Icon(Icons.add, color: Colors.white, size: 22),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                    minimumSize: const Size(34, 34),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),

      body: userKey.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('flowDB').doc('users')
                  .collection(userKey).doc('inc_cov_forms')
                  .collection('inc_cov_forms')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData ||
                    snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;

                if (docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.assignment_outlined,
                              size: 56, color: Colors.grey.shade300),
                          const SizedBox(height: 14),
                          const Text(
                            'No coverage forms yet.\nTap + to create a new one.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 16, 
                                color: Color(0xFF9CA3AF)
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 14),
                  child: GridView.builder(
                    itemCount: docs.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: cardWidth / cardHeight,
                    ),
                    itemBuilder: (context, index) {
                      final doc    = docs[index];
                      final data   = doc.data() as Map<String, dynamic>;
                      final first  = (data['firstName']  as String? ?? '').trim();
                      final middle = (data['middleName'] as String? ?? '').trim();
                      final last   = (data['lastName']   as String? ?? '').trim();
                      final name   = [first, middle, last]
                          .where((s) => s.isNotEmpty).join(' ');
                      final date   = data['dateOfCover'] as String? ?? '-';
                      final txNum  = docs.length - index;

                      return SizedBox(
                        width: cardWidth,
                        height: cardHeight,
                        child: Card(
                          elevation: 3,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => _openFormDetail(data, doc.id),
                            child: Container(
                              decoration: const BoxDecoration(gradient: _kGrad),
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    const Icon(Icons.assignment,
                                        color: Colors.white, size: 26),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text('Transaction #$txNum',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600)),
                                    ),
                                  ]),
                                  const SizedBox(height: 6),
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name.isNotEmpty
                                              ? name : 'Unnamed Coverage',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: Colors.white),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(date,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                ],
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