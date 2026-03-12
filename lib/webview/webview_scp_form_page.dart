import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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

  /// Direct Firebase Storage URL for the ZIP file containing scp_form_page.html.
  static const String _zipUrl =
      'https://firebasestorage.googleapis.com/v0/b/doxs-42fe8.appspot.com/o/flowDB%2Fscp_form_page.zip?alt=media&token=0b06e88b-3d7c-4b09-afb1-2c5143459a2f';

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

  Future<String?> _extractHtmlFromZip(Uint8List zipBytes) async {
    try {
      final archive = ZipDecoder().decodeBytes(zipBytes);
      for (final file in archive) {
        if (file.isFile && file.name == 'scp_form_page.html') {
          return utf8.decode(file.content as List<int>);
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error extracting HTML from ZIP: $e');
      return null;
    }
  }

  Future<void> _loadZipAndHtml() async {
    try {
      debugPrint('Downloading SCP ZIP from: $_zipUrl');
      final response = await http.get(Uri.parse(_zipUrl));
      if (response.statusCode != 200) {
        throw Exception('Failed to download ZIP: ${response.statusCode}');
      }
      final zipBytes = response.bodyBytes;
      final htmlContent = await _extractHtmlFromZip(zipBytes);
      if (htmlContent == null) {
        throw Exception('scp_form_page.html not found in ZIP');
      }

      final sanitizedEmail = await _getSanitizedUserEmail();
      final injectedHtml = htmlContent.replaceAll(
        'const createdBy = "";',
        'const createdBy = "$sanitizedEmail";',
      );

      await _controller.loadHtmlString(injectedHtml);
      debugPrint('SCP HTML loaded from ZIP into WebView');
    } catch (e) {
      debugPrint('Error loading SCP ZIP/HTML: $e');
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
          await _loadZipAndHtml();
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
