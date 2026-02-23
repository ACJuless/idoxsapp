import 'package:flutter/material.dart';

class FaqPage extends StatelessWidget {
  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("LOGIN STEPS"),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("1. Tap iDoXs App"),
                SizedBox(height: 5),
                Text("2. Input username@client name"),
                SizedBox(height: 5),
                Text("3. Input password"),
                SizedBox(height: 5),
                Text("4. Make sure map is updated below the signature box to your current location"),
                SizedBox(height: 5),
                Text("5. Input signature"),
                SizedBox(height: 5),
                Text("6. Tap 'Time In' on first Log In as DTR and 'Done' on succeeding Log Ins for the day"),
                SizedBox(height: 5),
                Text(
                  "   (if in case users accidentally logged out their account or clear the iDoXs App on task manager and they need to log IN again just tap 'Done')"
                ),
                SizedBox(height: 10),
                Text(
                  "7. Note: Connect your iPad when Logging In and then send updates after to make sure transactions in iDoXs are uploaded in the database."
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: Text("Close"),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("iDoXs FAQs"),
        backgroundColor: Colors.indigo.shade600,
      ),
      body: ListView(
        children: [
          ListTile(
            leading: Icon(Icons.help_outline, color: Colors.indigo.shade600),
            title: Text(
              "How do I log in? How do I check in? Where do I record my Time In?",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            onTap: () => _showHelpDialog(context),
          ),
        ],
      ),
    );
  }
}
