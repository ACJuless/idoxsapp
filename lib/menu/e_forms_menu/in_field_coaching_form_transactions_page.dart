import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'in_field_coaching_form_page.dart';

class InFieldCoachingFormReadonlyPage extends StatelessWidget {
  final Map<String, dynamic> formData;

  InFieldCoachingFormReadonlyPage({required this.formData, Key? key})
      : super(key: key);

  final List<String> questionTexts = const [
    "Key Message Delivery",
    "Key Value Delivery",
    "Objective Delivery",
    "Result Delivery",
    "Conclusion Delivery",
    "Attractive Selling Skill",
    "Closing Statement",
    "Prescription Deal",
    "Relationship Capital",
  ];

  final List<String> ratingLabels = const [
    "Unsatisfactory",
    "Needs Improvement",
    "Satisfactory",
    "Good",
    "Excellent",
  ];

  Color _ratingBg(int idx) {
    switch (idx) {
      case 0:
        return const Color(0xFFFEE2E2);
      case 1:
        return const Color(0xFFFEF3C7);
      case 2:
        return const Color(0xFFDBEAFE);
      case 3:
        return const Color(0xFFDCFCE7);
      case 4:
        return const Color(0xFFF3E8FF);
      default:
        return const Color(0xFFF3F4F6);
    }
  }

  Color _ratingDot(int idx) {
    switch (idx) {
      case 0:
        return const Color(0xFFDC2626);
      case 1:
        return const Color(0xFFD97706);
      case 2:
        return const Color(0xFF2563EB);
      case 3:
        return const Color(0xFF16A34A);
      case 4:
        return const Color(0xFF7C3AED);
      default:
        return const Color(0xFF9CA3AF);
    }
  }

  Color _ratingText(int idx) {
    switch (idx) {
      case 0:
        return const Color(0xFF991B1B);
      case 1:
        return const Color(0xFF92400E);
      case 2:
        return const Color(0xFF1E40AF);
      case 3:
        return const Color(0xFF166534);
      case 4:
        return const Color(0xFF6B21A8);
      default:
        return const Color(0xFF4B5563);
    }
  }

  String _safeString(dynamic v) => (v ?? '').toString();

  @override
  Widget build(BuildContext context) {
    final List<dynamic>? ratingsRaw = formData['ratings'] as List<dynamic>?;
    final List<int?> ratings = List<int?>.generate(
      questionTexts.length,
      (i) =>
          (ratingsRaw != null && i < ratingsRaw.length && ratingsRaw[i] != null)
              ? (ratingsRaw[i] as int)
              : null,
    );

    final evaluator = _safeString(formData['evaluator']);
    final position = _safeString(formData['position']);
    final date = _safeString(formData['date']);
    final medrepName = _safeString(formData['medrepName'] ?? formData['mdName']);
    final doctorName = _safeString(formData['doctorName']);
    final improvementComment = _safeString(formData['improvementComment']);

    final titleText = evaluator.isNotEmpty ? evaluator : 'In-Field Coaching';

    return Scaffold(
      backgroundColor: const Color(0xFFF9F5FF),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(72),
        child: AppBar(
          elevation: 6,
          automaticallyImplyLeading: false,
          backgroundColor: Colors.transparent,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(22),
              ),
              gradient: LinearGradient(
                colors: [Color(0xFF4A2371), Color(0xFF4A2371), Color(0xFF5958B2)],
                stops: [0, 0.55, 1],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Color.fromRGBO(76, 29, 149, 0.3),
                  blurRadius: 28,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    color: Colors.white,
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'In-Field Coaching',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color.fromRGBO(255, 255, 255, 0.65),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          titleText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _sectionLabel('Evaluator Details', first: true),
                _card(
                  Column(
                    children: [
                      _viewRow('Name of Evaluator', evaluator),
                      _viewRow('Position', position),
                      _viewRow('Date', date),
                      _viewRow('Medrep Name', medrepName),
                      _viewRow('Doctor Name', doctorName),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _sectionLabel('Rating'),
                _card(
                  Column(
                    children: List.generate(questionTexts.length, (idx) {
                      final ratingIdx = ratings[idx];
                      return _ratingViewRow(
                        index: idx,
                        question: questionTexts[idx],
                        ratingIdx: ratingIdx,
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 16),
                _sectionLabel('Comments'),
                _card(
                  Column(
                    children: [
                      _viewRow('Things to be Improved', improvementComment),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text, {bool first = false}) {
    return Padding(
      padding:
          EdgeInsets.fromLTRB(8, first ? 6 : 20, 8, 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Color(0xFF5958B2),
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _card(Widget child) {
    return Card(
      elevation: 3,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: child,
    );
  }

  Widget _viewRow(String label, String value) {
    final trimmed = value.trim();
    final isEmpty = trimmed.isEmpty;
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
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2B2B2B),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            isEmpty ? 'No data' : trimmed,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: isEmpty ? const Color(0xFF9CA3AF) : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _ratingViewRow({
    required int index,
    required String question,
    required int? ratingIdx,
  }) {
    final bool empty = ratingIdx == null;
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
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '${index + 1}. ',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF5958B2),
                  ),
                ),
                TextSpan(
                  text: question,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 7),
          if (empty)
            const Text(
              'No data',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF9CA3AF),
              ),
            )
          else
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
              decoration: BoxDecoration(
                color: _ratingBg(ratingIdx!),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _ratingDot(ratingIdx),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    ratingLabels[ratingIdx],
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: _ratingText(ratingIdx),
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

class InFieldCoachingFormTransactionsPage extends StatefulWidget {
  @override
  State<InFieldCoachingFormTransactionsPage> createState() =>
      _InFieldCoachingFormTransactionsPageState();
}

class _InFieldCoachingFormTransactionsPageState
    extends State<InFieldCoachingFormTransactionsPage> {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("In-Field Coaching Form Transactions"),
        backgroundColor: const Color(0xFF5958B2),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => InFieldCoachingFormPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: userKey.isEmpty
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('flowDB')
                  .doc('users')
                  .collection(userKey)
                  .doc('coaching_forms')
                  .collection('coaching_forms')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting ||
                    !snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final docs = snapshot.data!.docs;

                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      "No coaching forms yet. Tap '+' to create a new.",
                      style: TextStyle(
                        fontSize: 16,
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, idx) {
                    final QueryDocumentSnapshot doc = docs[idx];
                    final Map<String, dynamic> dat =
                        doc.data() as Map<String, dynamic>;

                    final String evaluator = dat['evaluator'] ?? '';
                    final String position = dat['position'] ?? '';
                    final String date = dat['date'] ?? '';

                    final String title = '$evaluator - $position';

                    return Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 2,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        title: Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(date),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  InFieldCoachingFormReadonlyPage(
                                formData: dat,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
