import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:archive/archive.dart';
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

  /// Direct Firebase Storage URL for incidental_coverage_form_page.zip
  static const String _zipUrl =
      'https://firebasestorage.googleapis.com/v0/b/doxs-42fe8.appspot.com/o/flowDB%2Fincidental_coverage_form_page.zip?alt=media&token=19525e5f-8c10-4927-beeb-5e15e3aca52c';

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

    _loadZipAndExtractHtml();
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

  Future<void> _loadZipAndExtractHtml() async {
    try {
      debugPrint('Downloading Incidental ZIP from: $_zipUrl');
      setState(() {
        _isLoading = true;
      });

      // Download ZIP file
      final response = await http.get(Uri.parse(_zipUrl));
      if (response.statusCode != 200) {
        throw Exception('Failed to download ZIP: ${response.statusCode}');
      }

      // Decode ZIP bytes
      final bytes = response.bodyBytes;
      final archive = ZipDecoder().decodeBytes(bytes);

      // Find the HTML file in the ZIP
      String? htmlContent;
      for (final file in archive) {
        if (file is ArchiveFile &&
            file.name == 'incidental_coverage_form_page.html') {
          htmlContent = utf8.decode(file.content as List<int>);
          debugPrint('Found HTML file in ZIP: ${file.name}');
          break;
        }
      }

      if (htmlContent == null) {
        throw Exception('HTML file "webview_incidental_coverage_form_page.html" not found in ZIP');
      }

      // Load HTML content into WebView
      await _controller.loadHtmlString(htmlContent);
      debugPrint('Incidental HTML loaded from ZIP into WebView');

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading Incidental ZIP/HTML: $e');
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
              await _loadZipAndExtractHtml();
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
