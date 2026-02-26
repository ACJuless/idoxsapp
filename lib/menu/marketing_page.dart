import 'package:flutter/material.dart';
import 'faq_page.dart';
import 'pdf_view_page.dart';

class MarketingPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Marketing Tools'),
        backgroundColor: Colors.indigo.shade600,
      ),
      body: ListView(
        children: [
          // --- FAQs section ---
          ListTile(
            leading: Icon(Icons.ads_click, color: Colors.indigo.shade600),
            title: Text('iDoXs FAQs'),
            subtitle: Text('V.1.2'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => FaqPage()),
              );
            },
          ),

          // --- Existing PDFs ---
          ListTile(
            leading: Icon(Icons.picture_as_pdf, color: Colors.indigo),
            title: Text('New EDA Besins'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PDFViewPage(
                    assetPath: 'assets/NEW_EDA_BESINS_R2.pdf',
                    title: 'New EDA Besins',
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.picture_as_pdf, color: Colors.indigo),
            title: Text('Full Detailer'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PDFViewPage(
                    assetPath: 'assets/2023_Full_Detailer_03292023.pdf',
                    title: 'Full Detailer',
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.picture_as_pdf, color: Colors.indigo),
            title: Text('Care of every woman'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PDFViewPage(
                    assetPath: 'assets/16_36_GAME.pdf',
                    title: 'Care of every woman',
                  ),
                ),
              );
            },
          ),

          ListTile(
            leading: Icon(Icons.picture_as_pdf, color: Colors.indigo),
            title: Text('2023 Full Detailer (Alternative Version)'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PDFViewPage(
                    assetPath: 'assets/2023_Full_Detailer.pdf',
                    title: '2023 Full Detailer (Alt.)',
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.picture_as_pdf, color: Colors.indigo),
            title: Text('Detailer 1: Full Detailer'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PDFViewPage(
                    assetPath: 'assets/Detailer_1_Full_Detailer.pdf',
                    title: 'Detailer 1: Full Detailer',
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.picture_as_pdf, color: Colors.indigo),
            title: Text('Detailer 2: 16-36'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PDFViewPage(
                    assetPath: 'assets/Detailer_2_16_36.pdf',
                    title: 'Detailer 2: 16-36',
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.picture_as_pdf, color: Colors.indigo),
            title: Text('Electronic Detailing Aid (Interactive)'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PDFViewPage(
                    assetPath: 'assets/BH_ELECTRONIC_DETAILING_AID_INTERACTIVE_011822.pdf',
                    title: 'Electronic Detailing Aid',
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.picture_as_pdf, color: Colors.indigo),
            title: Text('Utrogestan'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PDFViewPage(
                    assetPath: 'assets/Utrogestan.pdf',
                    title: 'Utrogestan',
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.picture_as_pdf, color: Colors.indigo),
            title: Text('16-36 Interactive Detailer'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PDFViewPage(
                    assetPath: 'assets/Interactive_16_36_Detailer.pdf',
                    title: '16-36 Interactive Detailer',
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
