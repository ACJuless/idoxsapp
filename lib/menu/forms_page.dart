import 'package:flutter/material.dart';
import 'base_menu_page.dart';

class FormsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BaseMenuPage(
      title: 'Electronic Forms',
      icon: Icons.description,
      description: 'Digital forms, templates, and document management.',
      accentColor: Colors.cyan.shade600,
      additionalContent: [
        ListTile(
          leading: Icon(Icons.assignment, color: Colors.cyan.shade600),
          title: Text('Form Templates'),
          subtitle: Text('Access pre-built form templates'),
        ),
        ListTile(
          leading: Icon(Icons.edit_document, color: Colors.cyan.shade600),
          title: Text('Custom Forms'),
          subtitle: Text('Create your own digital forms'),
        ),
      ],
    );
  }
}