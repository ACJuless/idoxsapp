import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

// New imports for downloading and unzipping the ZIP file.
import 'package:http/http.dart' as http;
import 'package:archive/archive.dart';

class AbrFormWebviewPage extends StatefulWidget {
  const AbrFormWebviewPage({Key? key}) : super(key: key);

  @override
  State<AbrFormWebviewPage> createState() => _AbrFormWebviewPageState();
}

class _AbrFormWebviewPageState extends State<AbrFormWebviewPage> {
  late final WebViewController _controller;
  bool _isLoading = true;

  /// Direct Firebase Storage URL for abr_form_page.zip.
  /// Make sure this points to your ZIP file and has a valid token.
  static const String _zipUrl =
      'https://firebasestorage.googleapis.com/v0/b/doxs-42fe8.appspot.com/o/flowDB%2Fabr_form_page.zip?alt=media&token=24527d87-da38-4e64-9c49-23064fbe9362';

  /// Name of the HTML file inside the ZIP.
  static const String _innerHtmlFileName = 'abr_form_page.html';

  String _createdBy = '';

  @override
  void initState() {
    super.initState();
    _loadCreatedByFromPrefs();
    _initWebViewController();
    _loadZipAndHtml();
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
    // Same sanitizer pattern as previous AbrFormPage.
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

  /// Downloads the ZIP from Firebase Storage, extracts `abr_form_page.html`,
  /// and loads the HTML string into the WebView.
  Future<void> _loadZipAndHtml() async {
    try {
      debugPrint('Downloading ABR ZIP from: $_zipUrl');
      setState(() {
        _isLoading = true;
      });

      final response = await http.get(Uri.parse(_zipUrl));
      if (response.statusCode != 200) {
        throw Exception('Failed to download ZIP (status: ${response.statusCode})');
      }

      final bytes = response.bodyBytes;

      // Decode the ZIP archive.
      final archive = ZipDecoder().decodeBytes(bytes);

      String? htmlContent;

      for (final file in archive) {
        if (file is ArchiveFile && file.name == _innerHtmlFileName) {
          final contentBytes = file.content as List<int>;
          htmlContent = utf8.decode(contentBytes);
          break;
        }
      }

      if (htmlContent == null) {
        throw Exception('HTML file $_innerHtmlFileName not found in ZIP');
      }

      debugPrint('ABR HTML extracted from ZIP, loading into WebView...');
      await _controller.loadHtmlString(htmlContent);
      debugPrint('ABR HTML loaded into WebView from ZIP');

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading ABR HTML from ZIP: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading form from ZIP: $e'),
        ),
      );
    }
  }

  Future<void> _saveAbrFormToFirestore(Map<String, dynamic> data) async {
    try {
      final userKey = await _getSanitizedUserEmail();

      // Mirror previous AbrFormPage field names and structure.
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
          await _loadZipAndHtml();
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
