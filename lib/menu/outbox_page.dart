import 'package:flutter/material.dart';
import 'base_menu_page.dart';

class OutboxPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BaseMenuPage(
      title: 'Outbox',
      icon: Icons.outbox,
      description: 'Manage outgoing documents, signatures, and pending items.',
      accentColor: Colors.brown.shade600,
      additionalContent: [
        ListTile(
          leading: Icon(Icons.send, color: Colors.brown.shade600),
          title: Text('Pending Documents'),
          subtitle: Text('Items waiting to be sent'),
        ),
        ListTile(
          leading: Icon(Icons.history, color: Colors.brown.shade600),
          title: Text('Send History'),
          subtitle: Text('Track sent documents'),
        ),
      ],
    );
  }
}