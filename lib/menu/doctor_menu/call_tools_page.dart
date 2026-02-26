import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, AssetManifest;
import 'package:pdfx/pdfx.dart';

class CallToolsPage extends StatefulWidget {
  const CallToolsPage({Key? key}) : super(key: key);

  @override
  State<CallToolsPage> createState() => _CallToolsPageState();
}

class _CallToolsPageState extends State<CallToolsPage> {
  List<String> _pdfAssets = [];
  bool _manifestLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadPdfAssets();
  }

  Future<void> _loadPdfAssets() async {
    try {
      // Use the AssetManifest API to read the list of assets that Flutter bundled. [web:78][web:86]
      final AssetManifest manifest =
          await AssetManifest.loadFromAssetBundle(rootBundle);
      final List<String> allAssets = manifest.listAssets().toList();

      // Keep only PDFs under assets/marketing_tools
      final List<String> pdfs = allAssets
          .where((assetPath) =>
              assetPath.startsWith('assets/marketing_tools/') &&
              assetPath.toLowerCase().endsWith('.pdf'))
          .toList()
        ..sort();

      setState(() {
        _pdfAssets = pdfs;
        _manifestLoaded = true;
      });
    } catch (e) {
      // Fallback for older Flutter versions that still generate AssetManifest.json
      try {
        final manifestContent =
            await rootBundle.loadString('AssetManifest.json');
        final Map<String, dynamic> manifestMap =
            jsonDecode(manifestContent) as Map<String, dynamic>;

        final List<String> pdfs = manifestMap.keys
            .where((String key) =>
                key.startsWith('assets/marketing_tools/') &&
                key.toLowerCase().endsWith('.pdf'))
            .toList()
          ..sort();

        setState(() {
          _pdfAssets = pdfs;
          _manifestLoaded = true;
        });
      } catch (_) {
        // If both methods fail, mark as loaded but empty so UI can show a message.
        setState(() {
          _pdfAssets = [];
          _manifestLoaded = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_manifestLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_pdfAssets.isEmpty) {
      return const Center(
        child: Text(
          'No PDF files found in assets/marketing_tools/',
          textAlign: TextAlign.center,
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.3,
      ),
      itemCount: _pdfAssets.length,
      itemBuilder: (context, index) {
        final String pdfPath = _pdfAssets[index];
        final String pdfName = pdfPath
            .split('/')
            .last
            .replaceAll('.pdf', '')
            .replaceAll('_', ' ');

        return FutureBuilder<PdfPageImage?>(
          future: _getPdfThumbnail(pdfPath, thumbW: 140, thumbH: 100),
          builder: (context, snapshot) {
            Widget cardBackground;
            if (snapshot.hasData && snapshot.data != null) {
              cardBackground = Image.memory(
                snapshot.data!.bytes,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              );
            } else {
              cardBackground = Container(color: Colors.grey.shade300);
            }

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        PdfViewerPage(assetPath: pdfPath, title: pdfName),
                  ),
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    Positioned.fill(child: cardBackground),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.black.withOpacity(0.33),
                      ),
                    ),
                    Positioned(
                      left: 6,
                      right: 6,
                      bottom: 12,
                      child: Text(
                        pdfName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          shadows: [
                            Shadow(
                              offset: Offset(0, 1),
                              blurRadius: 5,
                              color: Colors.black54,
                            ),
                          ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<PdfPageImage?> _getPdfThumbnail(
  String assetPath, {
  int thumbW = 140,
  int thumbH = 100,
}) async {
  try {
    final PdfDocument pdfDoc = await PdfDocument.openAsset(assetPath);
    final PdfPage page = await pdfDoc.getPage(1);

    // MAKE THIS NULLABLE
    final PdfPageImage? pageImage = await page.render(
      width: thumbW.toDouble(),
      height: thumbH.toDouble(),
      backgroundColor: '#ffffff',
    );

    await page.close();
    await pdfDoc.close();

    // Return null safely if render failed
    if (pageImage == null) return null;
    return pageImage;
  } catch (e) {
    return null;
  }
}

}

class PdfViewerPage extends StatelessWidget {
  final String assetPath;
  final String title;

  const PdfViewerPage({
    Key? key,
    required this.assetPath,
    required this.title,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final PdfController controller = PdfController(
      document: PdfDocument.openAsset(assetPath),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.deepPurple,
      ),
      body: PdfView(controller: controller),
    );
  }
}
