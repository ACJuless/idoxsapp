import 'package:flutter/material.dart';
import 'base_menu_page.dart';

class SalesPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BaseMenuPage(
      title: 'Sales',
      icon: Icons.trending_up,
      description: 'Sales tracking, analytics, and performance metrics.',
      accentColor: Colors.pink.shade600,
      additionalContent: [
        ListTile(
          leading: Icon(Icons.bar_chart, color: Colors.pink.shade600),
          title: Text('Sales Analytics'),
          subtitle: Text('Track performance and revenue'),
        ),
        ListTile(
          leading: Icon(Icons.people, color: Colors.pink.shade600),
          title: Text('Customer Management'),
          subtitle: Text('Manage client relationships'),
        ),
      ],
    );
  }
}