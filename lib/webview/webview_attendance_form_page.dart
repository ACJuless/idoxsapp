import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

class AttendanceFormWebviewPage extends StatefulWidget {
  const AttendanceFormWebviewPage({Key? key}) : super(key: key);

  @override
  State<AttendanceFormWebviewPage> createState() =>
      _AttendanceFormWebviewPageState();
}

class _AttendanceFormWebviewPageState extends State<AttendanceFormWebviewPage> {
  late final WebViewController _controller;
  bool _isLoading = true;

  /// Direct Firebase Storage URL for attendance_form_page.zip.
  /// Make sure this points to your ZIP file and has a valid token.
  ///
  /// NOTE: Replace the token below with the actual token of your
  /// attendance_form_page.zip file in Firebase Storage.
  static const String _zipUrl =
      'https://firebasestorage.googleapis.com/v0/b/doxs-42fe8.appspot.com/o/flowDB%2Fattendance_form_page.zip?alt=media&token=532871f5-2390-402f-b92d-55b2dec6678a';

  /// Name of the HTML file inside the ZIP.
  static const String _innerHtmlFileName = 'attendance_form_page.html';

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
    // Same sanitizer pattern as other pages.
    return userEmail.replaceAll(RegExp(r'[.#\$\\\[\]/]'), '_');
  }

  void _initWebViewController() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'ATTENDANCEBridge',
        onMessageReceived: (JavaScriptMessage message) async {
          debugPrint('ATTENDANCEBridge received payload: ${message.message}');
          Map<String, dynamic> data;
          try {
            final decoded = jsonDecode(message.message);
            if (decoded is Map<String, dynamic>) {
              data = decoded;
            } else {
              throw const FormatException('Decoded JSON is not a Map');
            }
          } catch (e) {
            debugPrint('Error decoding Attendance payload JSON: $e');
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error decoding form data: $e'),
              ),
            );
            return;
          }

          await _saveAttendanceFormToFirestore(data);
        },
      )
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            debugPrint('Attendance WebView onPageStarted: $url');
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (url) {
            debugPrint('Attendance WebView onPageFinished: $url');
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (error) {
            debugPrint('Attendance WebView error: $error');
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

  /// Downloads the ZIP from Firebase Storage, extracts `attendance_form_page.html`,
  /// and loads the HTML string into the WebView.
  Future<void> _loadZipAndHtml() async {
    try {
      debugPrint('Downloading Attendance ZIP from: $_zipUrl');
      setState(() {
        _isLoading = true;
      });

      final response = await http.get(Uri.parse(_zipUrl));
      if (response.statusCode != 200) {
        throw Exception(
            'Failed to download ZIP (status: ${response.statusCode})');
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

      debugPrint('Attendance HTML extracted from ZIP, loading into WebView...');
      await _controller.loadHtmlString(htmlContent);
      debugPrint('Attendance HTML loaded into WebView from ZIP');

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading Attendance HTML from ZIP: $e');
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

  /// Saves Attendance Form data coming from the HTML/JS bridge into Firestore.
  ///
  /// The `data` Map is expected to mirror the structure emitted by
  /// `attendance_form_page.html` when it calls:
  ///   window.ATTENDANCEBridge.postMessage(JSON.stringify(formData));
  Future<void> _saveAttendanceFormToFirestore(
      Map<String, dynamic> data) async {
    try {
      final userKey = await _getSanitizedUserEmail();

      // Map incoming web form fields to Firestore payload.
      // These keys should match what your HTML page sends.
      final payloadToSave = <String, dynamic>{
        'eventName': data['eventName'] ?? '',
        'cropFocus': data['cropFocus'] ?? '',
        'cropStatus': data['cropStatus'] ?? '',
        'date': data['date'] ?? '',
        'location': data['location'] ?? '',
        'createdBy': _createdBy,
        'deviceLat': data['deviceLat'],
        'deviceLng': data['deviceLng'],
        'deviceAddress': data['deviceAddress'] ?? '',
        'timestamp': DateTime.now(),
        'remarks': data['remarks'] ?? '',
        'attendees': data['attendees'] ?? <dynamic>[],
        'attendeeSignatures': data['attendeeSignatures'] ?? <dynamic>[],
        'dealers': data['dealers'] ?? <dynamic>[],
        'focusProducts': data['focusProducts'] ?? <dynamic>[],
      };

      await FirebaseFirestore.instance
          .collection('flowDB')
          .doc('users')
          .collection(userKey)
          .doc('attendance_forms')
          .collection('attendance_forms')
          .add(payloadToSave);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Attendance Form submitted.'),
        ),
      );

      Navigator.of(context).maybePop();
    } catch (e) {
      debugPrint('Error submitting Attendance form to Firestore: $e');
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
        title: const Text('Attendance Form'),
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
        heroTag: 'reloadAttendanceFormWebView',
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
