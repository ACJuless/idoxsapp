import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebviewSalesOrderFormPage extends StatefulWidget {
  const WebviewSalesOrderFormPage({Key? key}) : super(key: key);

  @override
  State<WebviewSalesOrderFormPage> createState() =>
      _WebviewSalesOrderFormPageState();
}

class _WebviewSalesOrderFormPageState extends State<WebviewSalesOrderFormPage> {
  late final WebViewController _controller;
  bool _isLoading = true;

  /// Direct Firebase Storage URL for sales_order_form_page.html.
  static const String _htmlUrl =
      'https://firebasestorage.googleapis.com/v0/b/doxs-42fe8.appspot.com/o/flowDB%2Fsales_order_form_page.html?alt=media&token=fd58d732-fe76-4bb4-b98c-269b3f092327';

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'SalesOrderBridge',
        onMessageReceived: (JavaScriptMessage message) async {
          debugPrint(
              'SalesOrderBridge received payload from HTML: ${message.message}');
          Map<String, dynamic> data;
          try {
            final decoded = jsonDecode(message.message);
            if (decoded is Map<String, dynamic>) {
              data = decoded;
            } else {
              throw const FormatException('Decoded JSON is not a Map');
            }
          } catch (e) {
            debugPrint('Error decoding Sales Order payload JSON: $e');
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error decoding form data: $e'),
              ),
            );
            return;
          }

          await _saveSalesOrderToFirestore(data);
        },
      )
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            debugPrint('SalesOrder WebView onPageStarted: $url');
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (url) {
            debugPrint('SalesOrder WebView onPageFinished: $url');
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (error) {
            debugPrint('SalesOrder WebView error: $error');
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

  Future<void> _saveSalesOrderToFirestore(Map<String, dynamic> data) async {
    try {
      final userKey = await _getSanitizedUserEmail();

      final payloadToSave = <String, dynamic>{
        "mrName": data["mrName"] ?? "",
        "soldTo": data["soldTo"] ?? "",
        "dateOfOrder": data["dateOfOrder"] ?? "",
        "salesOrderNo": data["salesOrderNo"] ?? "",
        "address": data["address"] ?? "",
        "shipTo": data["shipTo"] ?? "",
        "telNo": data["telNo"] ?? "",
        "terms": data["terms"] ?? "",
        "specialNote": data["specialNote"] ?? "",
        "specialInstruction": data["specialInstruction"] ?? "",
        "notedBy1": data["notedBy1"] ?? "",
        "notedBy2": data["notedBy2"] ?? "",
        "discount": data["discount"] ?? "",
        "pharmaRows": data["pharmaRows"] ?? <dynamic>[],
        "dermaRows": data["dermaRows"] ?? <dynamic>[],
        "grossAmount": (data["grossAmount"] ?? 0).toDouble(),
        "netAmount": (data["netAmount"] ?? 0).toDouble(),
        "timestamp": FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('flowDB')
          .doc('users')
          .collection(userKey)
          .doc('sales_orders')
          .collection('sales_orders')
          .add(payloadToSave);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sales Order Form submitted successfully.'),
        ),
      );

      Navigator.of(context).maybePop(true);
    } catch (e) {
      debugPrint('Error submitting Sales Order form to Firestore: $e');
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
      debugPrint('Loading Sales Order HTML from: $_htmlUrl');
      await _controller.loadRequest(Uri.parse(_htmlUrl));
      debugPrint('Sales Order HTML requested in WebView');
    } catch (e) {
      debugPrint('Error loading Sales Order remote HTML: $e');
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
        title: const Text('Sales Order Form'),
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
