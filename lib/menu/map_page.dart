import 'package:flutter/material.dart';
import 'base_menu_page.dart';

class MapPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BaseMenuPage(
      title: 'Map/GPS',
      icon: Icons.map,
      description: 'Location services, GPS tracking, and geographical features.',
      accentColor: Colors.teal.shade600,
      additionalContent: [
        ListTile(
          leading: Icon(Icons.location_on, color: Colors.teal.shade600),
          title: Text('Current Location'),
          subtitle: Text('View your current position'),
        ),
        ListTile(
          leading: Icon(Icons.navigation, color: Colors.teal.shade600),
          title: Text('Navigation'),
          subtitle: Text('Get directions and routes'),
        ),
      ],
    );
  }
}