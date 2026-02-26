import 'package:flutter/material.dart';

class CallPostCallPage extends StatefulWidget {
  final String doctorId;
  final String scheduledVisitId;
  const CallPostCallPage({
    Key? key,
    required this.doctorId,
    required this.scheduledVisitId
  }) : super(key: key);

  @override
  State<CallPostCallPage> createState() => _CallPostCallPageState();
}

class _CallPostCallPageState extends State<CallPostCallPage> {
  final TextEditingController _contactPersonController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  bool _isRemoteCall = false;
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: SingleChildScrollView(
        child: Column(
          children: [
            TextFormField(
              controller: _contactPersonController,
              decoration: InputDecoration(
                labelText: "Contact Person",
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 18),
            TextFormField(
              controller: _noteController,
              minLines: 5,
              maxLines: 10,
              decoration: InputDecoration(
                labelText: "Post Call Note",
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 18),
            if (_isSubmitting)
              CircularProgressIndicator()
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white
                  ),
                  child: Text("Submit", style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    FocusScope.of(context).unfocus();
                    setState(() => _isSubmitting = true);
                    await Future.delayed(Duration(seconds: 1));
                    // TODO: Save to Firestore here if you want!
                    setState(() => _isSubmitting = false);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Post-Call Submitted!")));
                  }
                ),
              )
          ],
        ),
      ),
    );
  }
}
