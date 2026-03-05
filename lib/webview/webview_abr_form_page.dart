import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

class AbrFormWebviewPage extends StatefulWidget {
  const AbrFormWebviewPage({Key? key}) : super(key: key);

  @override
  State<AbrFormWebviewPage> createState() => _AbrFormWebviewPageState();
}

class _AbrFormWebviewPageState extends State<AbrFormWebviewPage> {
  late final WebViewController _controller;
  bool _isLoading = true;

  /// Direct Firebase Storage URL for abr_form_page.html.
  static const String _htmlUrl =
      'https://firebasestorage.googleapis.com/v0/b/doxs-42fe8.appspot.com/o/flowDB%2Fabr_form_page.html?alt=media&token=17b10fc7-6e46-462b-aa36-52c9cec371be';

  String _createdBy = '';

  @override
  void initState() {
    super.initState();
    _loadCreatedByFromPrefs();
    _initWebViewController();
    _loadRemoteHtml();
  }

  Future<void> _loadCreatedByFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final userEmail = prefs.getString('userEmail') ?? '';
    if (!mounted) return;
    setState(() {
      _createdBy = userEmail;
    });
  }

  Future<String> _getSanitizedUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final userEmail = prefs.getString('userEmail') ?? '';
    // Same sanitizer pattern as your original AbrFormPage
    return userEmail.replaceAll(RegExp(r'[.#\$\\\[\]/]'), '_');
  }

  void _initWebViewController() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'ABRBridge',
        onMessageReceived: (JavaScriptMessage message) async {
          debugPrint('ABRBridge received payload: ${message.message}');
          Map<String, dynamic> data;
          try {
            final decoded = jsonDecode(message.message);
            if (decoded is Map<String, dynamic>) {
              data = decoded;
            } else {
              throw const FormatException('Decoded JSON is not a Map');
            }
          } catch (e) {
            debugPrint('Error decoding ABR payload JSON: $e');
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error decoding form data: $e'),
              ),
            );
            return;
          }

          await _saveAbrFormToFirestore(data);
        },
      )
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            debugPrint('ABR WebView onPageStarted: $url');
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (url) {
            debugPrint('ABR WebView onPageFinished: $url');
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (error) {
            debugPrint('ABR WebView error: $error');
            setState(() {
              _isLoading = false;
            });
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error loading form: ${error.description}'),
              ),
            );
          },
        ),
      );
  }

  Future<void> _loadRemoteHtml() async {
    try {
      debugPrint('Loading ABR HTML from: $_htmlUrl');
      await _controller.loadRequest(Uri.parse(_htmlUrl));
      debugPrint('ABR HTML requested in WebView');
    } catch (e) {
      debugPrint('Error loading ABR remote HTML: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading form: $e'),
        ),
      );
    }
  }

  Future<void> _saveAbrFormToFirestore(Map<String, dynamic> data) async {
    try {
      final userKey = await _getSanitizedUserEmail();

      // Mirror original AbrFormPage field names and structure.
      final payloadToSave = <String, dynamic>{
        'agronomist': data['agronomist'] ?? '',
        'area': data['area'] ?? '',
        'cropFocus': data['cropFocus'] ?? '',
        'activityType': data['activityType'] ?? '',
        'plannedLocation': data['plannedLocation'] ?? '',
        'actualLocation': data['actualLocation'] ?? '',
        'plannedDate': data['plannedDate'] ?? '',
        'actualDate': data['actualDate'] ?? '',
        'targetAttendees': data['targetAttendees'] ?? '',
        'actualAttendees': data['actualAttendees'] ?? '',
        'budgetPerAttendee': data['budgetPerAttendee'] ?? '',
        'standardBudgetRequirement': data['standardBudgetRequirement'] ?? '',
        'additionalBudgetRequest': data['additionalBudgetRequest'] ?? '',
        'justificationAdditionalBudget':
            data['justificationAdditionalBudget'] ?? '',
        'totalBudgetRequested': data['totalBudgetRequested'] ?? '',
        'actualBudgetSpent': data['actualBudgetSpent'] ?? '',
        'productFocusRows': data['productFocusRows'] ?? <dynamic>[],
        'totalTargetMoveoutValue': data['totalTargetMoveoutValue'] ?? '',
        'totalActualMoveoutValue': data['totalActualMoveoutValue'] ?? '',
        'remarksActivityOutput': data['remarksActivityOutput'] ?? '',
        'otherProductsSoldBooked': data['otherProductsSoldBooked'] ?? '',
        'valueOtherProductsSoldBooked':
            data['valueOtherProductsSoldBooked'] ?? '',
        'productsDeliveredDealers': data['productsDeliveredDealers'] ?? '',
        'valueProductsDeliveredDealers':
            data['valueProductsDeliveredDealers'] ?? '',
        'createdBy': _createdBy,
        'timestamp': DateTime.now(),
      };

      await FirebaseFirestore.instance
          .collection('flowDB')
          .doc('users')
          .collection(userKey)
          .doc('abr_forms')
          .collection('abr_forms')
          .add(payloadToSave);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Activity Budget Request Form submitted.'),
        ),
      );

      Navigator.of(context).maybePop();
    } catch (e) {
      debugPrint('Error submitting ABR form to Firestore: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting form: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Budget Request Form'),
        backgroundColor: const Color(0xFF4e2f80),
        centerTitle: true,
        elevation: 4,
      ),
      body: Stack(
        children: [
          WebViewWidget(
            controller: _controller,
          ),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'reloadAbrFormWebView',
        onPressed: () async {
          setState(() {
            _isLoading = true;
          });
          await _loadRemoteHtml();
        },
        backgroundColor: const Color(0xFF5e1398),
        child: const Icon(
          Icons.refresh,
          color: Colors.white,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
