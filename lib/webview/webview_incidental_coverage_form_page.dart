import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

class IncidentalCoverageFormWebviewPage extends StatefulWidget {
  const IncidentalCoverageFormWebviewPage({Key? key}) : super(key: key);

  @override
  State<IncidentalCoverageFormWebviewPage> createState() =>
      _IncidentalCoverageFormWebviewPageState();
}

class _IncidentalCoverageFormWebviewPageState
    extends State<IncidentalCoverageFormWebviewPage> {
  late final WebViewController _controller;
  bool _isLoading = true;

  /// Direct Firebase Storage URL for incidental_coverage_form_page.html
  static const String _htmlUrl =
      'https://firebasestorage.googleapis.com/v0/b/doxs-42fe8.appspot.com/o/flowDB%2Fincidental_coverage_form_page.html?alt=media&token=d9d27655-2e72-4df1-bf98-92c19cf154aa';

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'IncidentalBridge',
        onMessageReceived: (JavaScriptMessage message) async {
          debugPrint(
              'IncidentalBridge received payload from HTML: ${message.message}');
          Map<String, dynamic> data;
          try {
            final decoded = jsonDecode(message.message);
            if (decoded is Map<String, dynamic>) {
              data = decoded;
            } else {
              throw const FormatException('Decoded JSON is not a Map');
            }
          } catch (e) {
            debugPrint('Error decoding incidental payload JSON: $e');
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error decoding form data: $e'),
              ),
            );
            return;
          }

          await _saveIncidentalFormToFirestore(data);
        },
      )
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            debugPrint('Incidental WebView onPageStarted: $url');
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (url) {
            debugPrint('Incidental WebView onPageFinished: $url');
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (error) {
            debugPrint('Incidental WebView error: $error');
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

    _loadRemoteHtml();
  }

  Future<String> _getSanitizedUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final userEmail = prefs.getString('userEmail') ?? '';
    return userEmail.replaceAll(RegExp(r'[.#\$\\\[\]/]'), '_');
  }

  Future<void> _saveIncidentalFormToFirestore(
      Map<String, dynamic> data) async {
    try {
      final userKey = await _getSanitizedUserEmail();

      // Same structure as original IncidentalCoverageFormPage._submitForm
      final payloadToSave = <String, dynamic>{
        'lastName': data['lastName'] ?? '',
        'firstName': data['firstName'] ?? '',
        'middleName': data['middleName'] ?? '',
        'specialty': data['specialty'] ?? '',
        'hospitalPharmacyName': data['hospitalPharmacyName'] ?? '',
        'dateOfCover': data['dateOfCover'] ?? '',
        'preCallNotes': data['preCallNotes'] ?? '',
        'postCallNotes': data['postCallNotes'] ?? '',
        'timestamp': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('flowDB')
          .doc('users')
          .collection(userKey)
          .doc('inc_cov_forms')
          .collection('inc_cov_forms')
          .add(payloadToSave);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Incidental Coverage Form submitted successfully.'),
        ),
      );

      Navigator.of(context).maybePop(true);
    } catch (e) {
      debugPrint('Error submitting incidental form to Firestore: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit form. Please try again. ($e)'),
        ),
      );
    }
  }

  Future<void> _loadRemoteHtml() async {
    try {
      debugPrint('Loading incidental HTML from: $_htmlUrl');
      await _controller.loadRequest(Uri.parse(_htmlUrl));
      debugPrint('Incidental HTML requested in WebView');
    } catch (e) {
      debugPrint('Error loading incidental remote HTML: $e');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Incidental Coverage Form'),
        backgroundColor: const Color(0xFF4e2f80),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              setState(() {
                _isLoading = true;
              });
              await _loadRemoteHtml();
            },
          ),
        ],
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
    );
  }
}
