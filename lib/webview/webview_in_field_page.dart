import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:archive/archive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebviewInFieldPage extends StatefulWidget {
  const WebviewInFieldPage({Key? key}) : super(key: key);

  @override
  State<WebviewInFieldPage> createState() => _WebviewInFieldPageState();
}

class _WebviewInFieldPageState extends State<WebviewInFieldPage> {
  late final WebViewController _controller;
  bool _isLoading = true;

  /// Direct Firebase Storage URL for the In-Field Coaching ZIP file.
  static const String _zipUrl =
      'https://firebasestorage.googleapis.com/v0/b/doxs-42fe8.appspot.com/o/flowDB%2Fin_field_coaching_form_page.zip?alt=media&token=6008a747-70e8-48fb-9938-c1d752c6fda7';

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'InFieldBridge',
        onMessageReceived: (JavaScriptMessage message) async {
          debugPrint(
              'InFieldBridge received payload from HTML: ${message.message}');
          Map<String, dynamic> data;
          try {
            final decoded = jsonDecode(message.message);
            if (decoded is Map<String, dynamic>) {
              data = decoded;
            } else {
              throw const FormatException('Decoded JSON is not a Map');
            }
          } catch (e) {
            debugPrint('Error decoding In-Field payload JSON: $e');
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error decoding form data: $e'),
              ),
            );
            return;
          }

          await _saveInFieldFormToFirestore(data);
        },
      )
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            debugPrint('WebView (InField) onPageStarted: $url');
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (url) {
            debugPrint('WebView (InField) onPageFinished: $url');
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (error) {
            debugPrint('WebView (InField) error: $error');
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
    return userEmail.replaceAll(RegExp(r'[.#\\$\\[\\]/]'), '_');
  }

  Future<void> _saveInFieldFormToFirestore(Map<String, dynamic> data) async {
    try {
      final userKey = await _getSanitizedUserEmail();

      // Map HTML payload -> Firestore fields, same as original InFieldCoachingFormPage.
      final payloadToSave = <String, dynamic>{
        'evaluator': data['evaluator'] ?? '',
        'position': data['position'] ?? '',
        'date': data['date'] ?? '',
        'medrepName': data['medrepName'] ?? '',
        'mdName': data['mdName'] ?? '',
        'improvementComment': data['improvementComment'] ?? '',
        'ratings': data['ratings'] ?? <dynamic>[],
        'timestamp': DateTime.now(),
      };

      await FirebaseFirestore.instance
          .collection('flowDB')
          .doc('users')
          .collection(userKey)
          .doc('coaching_forms')
          .collection('coaching_forms')
          .add(payloadToSave);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('In-Field Coaching Form submitted successfully from WebView'),
        ),
      );

      Navigator.of(context).maybePop();
    } catch (e) {
      debugPrint('Error submitting In-Field form to Firestore: $e');
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
      debugPrint('Downloading In-Field ZIP from: $_zipUrl');
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
            file.name == 'in_field_coaching_form_page.html') {
          htmlContent = utf8.decode(file.content as List<int>);
          debugPrint('Found HTML file in ZIP: ${file.name}');
          break;
        }
      }

      if (htmlContent == null) {
        throw Exception('HTML file "in_field_coaching_form_page.html" not found in ZIP');
      }

      // Load HTML content into WebView
      await _controller.loadHtmlString(htmlContent);
      debugPrint('In-Field HTML loaded from ZIP into WebView');

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading In-Field ZIP/HTML: $e');
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
        title: const Text('In-Field Coaching Form'),
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
