import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

class ScpFormWebviewPage extends StatefulWidget {
  const ScpFormWebviewPage({Key? key}) : super(key: key);

  @override
  State<ScpFormWebviewPage> createState() => _ScpFormWebviewPageState();
}

class _ScpFormWebviewPageState extends State<ScpFormWebviewPage> {
  late final WebViewController _controller;
  bool _isLoading = true;

  /// Direct Firebase Storage URL for scp_form_page.html.
  static const String _htmlUrl =
      'https://firebasestorage.googleapis.com/v0/b/doxs-42fe8.appspot.com/o/flowDB%2Fscp_form_page.html?alt=media&token=ff748d29-ae30-4bd7-ac1e-5986ccb17843';

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
    return userEmail.replaceAll(RegExp(r'\.'), '_');
  }

  void _initWebViewController() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'SCPBridge',
        onMessageReceived: (JavaScriptMessage message) async {
          // message.message is a JSON string coming from the HTML
          debugPrint('SCPBridge received payload: ${message.message}');
          Map<String, dynamic> data;
          try {
            final decoded = jsonDecode(message.message);
            if (decoded is Map<String, dynamic>) {
              data = decoded;
            } else {
              throw const FormatException('Decoded JSON is not a Map');
            }
          } catch (e) {
            debugPrint('Error decoding SCP payload JSON: $e');
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error decoding form data: $e'),
              ),
            );
            return;
          }

          await _saveScpFormToFirestore(data);
        },
      )
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            debugPrint('SCP WebView onPageStarted: $url');
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (url) {
            debugPrint('SCP WebView onPageFinished: $url');
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (error) {
            debugPrint('SCP WebView error: $error');
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
      debugPrint('Loading SCP HTML from: $_htmlUrl');
      await _controller.loadRequest(Uri.parse(_htmlUrl));
      debugPrint('SCP HTML requested in WebView');
    } catch (e) {
      debugPrint('Error loading SCP remote HTML: $e');
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

  Future<void> _saveScpFormToFirestore(Map<String, dynamic> data) async {
    try {
      final userKey = await _getSanitizedUserEmail();

      // Ensure createdBy and timestamp match your previous Dart implementation.
      final payloadToSave = <String, dynamic>{
        'farmerName': data['farmerName'] ?? '',
        'farmAddress': data['farmAddress'] ?? '',
        'cellphoneNumber': data['cellphoneNumber'] ?? '',
        'dateOfEvent': data['dateOfEvent'] ?? '',
        'typeOfEvent': data['typeOfEvent'] ?? '',
        'venueOfEvent': data['venueOfEvent'] ?? '',
        'cropsPlanted': data['cropsPlanted'] ?? '',
        'advisoryDetails': data['advisoryDetails'] ?? <dynamic>[],
        'cropAdvisorName': data['cropAdvisorName'] ?? '',
        'cropAdvisorContact': data['cropAdvisorContact'] ?? '',
        'products': data['products'] ?? <dynamic>[],
        'farmerNameSecond': data['farmerNameSecond'] ?? '',
        'farmerSignaturePoints': data['farmerSignaturePoints'],
        'dateNeeded': data['dateNeeded'] ?? '',
        'preferredDealer': data['preferredDealer'] ?? '',
        'createdBy': _createdBy,
        'timestamp': DateTime.now(),
      };

      await FirebaseFirestore.instance
          .collection('flowDB')
          .doc('users')
          .collection(userKey)
          .doc('scp_forms')
          .collection('scp_forms')
          .add(payloadToSave);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sample Crop Prescription Form submitted.'),
        ),
      );

      // Optionally pop back after successful submit to mirror old page behavior.
      Navigator.of(context).maybePop();
    } catch (e) {
      debugPrint('Error submitting SCP form to Firestore: $e');
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
        title: const Text('Sample Crop Prescription Form'),
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
        heroTag: 'reloadScpFormWebView',
        onPressed: () async {
          setState(() {
            _isLoading = true;
          });
          await _loadRemoteHtml();
        },
        backgroundColor: const Color(0xFF5958b2),
        child: const Icon(
          Icons.refresh,
          color: Colors.white,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
