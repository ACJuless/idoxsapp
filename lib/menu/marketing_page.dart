import 'package:flutter/material.dart';
import 'base_menu_page.dart';

class MarketingPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BaseMenuPage(
      title: 'Marketing Tools',
      icon: Icons.campaign,
      description: 'Promotional materials, campaigns, and marketing resources.',
      accentColor: Colors.indigo.shade600,
      additionalContent: [
        ListTile(
          leading: Icon(Icons.ads_click, color: Colors.indigo.shade600),
          title: Text('Campaigns'),
          subtitle: Text('Create and manage marketing campaigns'),
        ),
        ListTile(
          leading: Icon(Icons.share, color: Colors.indigo.shade600),
          title: Text('Social Media'),
          subtitle: Text('Share content across platforms'),
        ),
      ],
    );
  }
}