// 

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DeductionInputPage extends StatefulWidget {
  final DateTime selectedDate;
  const DeductionInputPage({Key? key, required this.selectedDate}) : super(key: key);

  @override
  State<DeductionInputPage> createState() => _DeductionInputPageState();
}

class _DeductionInputPageState extends State<DeductionInputPage> {
  static const deductionOptions = [
    "Leave w/o pay",
    "Sick Leave",
    "Service Incentive Leave",
    "Emergency Leave",
    "No Clinic / Clinic Closed",
    "Meeting",
    "Marketing Program Implementation",
    "Training",
    "Business Review / Performance Review",
    "National Conference",
    "Holiday",
    "Others"
  ];
  int selectedIdx = 0;
  TextEditingController extraInputController = TextEditingController();
  bool isHalfDay = false;

  bool needsExtraInput(String val) {
    return val == "Meeting" ||
        val == "Marketing Program Implementation" ||
        val == "Training" ||
        val == "Others";
  }

  String? getExtraLabel(String val) {
    switch (val) {
      case "Meeting": return "Specify meeting type";
      case "Marketing Program Implementation": return "Specify program";
      case "Training": return "Specify training";
      case "Others": return "Please specify";
      default: return null;
    }
  }

  String get dateKey {
    final d = widget.selectedDate;
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _saveDeduction() async {
    final deductionType = deductionOptions[selectedIdx];
    final extraInput = needsExtraInput(deductionType) ? extraInputController.text.trim() : "";
    await FirebaseFirestore.instance
      .collection('deductions')
      .doc(dateKey)
      .collection('items')
      .add({
        'deductionType': deductionType,
        'extraInput': extraInput,
        'isHalfDay': isHalfDay,
        'date': dateKey,
        'timestamp': FieldValue.serverTimestamp(),
      });
  }

  @override
  Widget build(BuildContext context) {
    final selectedDeduction = deductionOptions[selectedIdx];

    return Scaffold(
      appBar: AppBar(
        title: Text("Call Target Deduction"),
        backgroundColor: Colors.green.shade600,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Select Deduction",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.green.shade600),
              ),
              SizedBox(height: 18),
              Expanded(
                child: ListView.builder(
                  itemCount: deductionOptions.length,
                  itemBuilder: (context, i) {
                    bool isSelected = (i == selectedIdx);
                    return ListTile(
                      title: Text(
                        deductionOptions[i],
                        style: TextStyle(
                          color: isSelected ? Colors.green.shade800 : Colors.black,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      onTap: () { setState(() { selectedIdx = i; }); },
                      selected: isSelected,
                      selectedTileColor: Colors.green.shade50,
                    );
                  },
                ),
              ),
              if (needsExtraInput(selectedDeduction)) ...[
                SizedBox(height: 12),
                TextField(
                  controller: extraInputController,
                  decoration: InputDecoration(
                    labelText: getExtraLabel(selectedDeduction),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Half-Day?", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.green.shade700)),
                  Switch(
                    activeColor: Colors.green,
                    value: isHalfDay,
                    onChanged: (val) { setState(() { isHalfDay = val; }); },
                  ),
                ],
              ),
              SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[300]),
                    onPressed: () => Navigator.pop(context),
                    child: Text("Cancel", style: TextStyle(color: Colors.black)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600),
                    onPressed: () async {
                      await _saveDeduction();
                      Navigator.pop(context);
                    },
                    child: Text("Done", style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
