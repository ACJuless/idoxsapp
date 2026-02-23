import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SalesOrderFormPage extends StatefulWidget {
  final Map<String, dynamic>? formData;
  final bool readonly;
  SalesOrderFormPage({this.formData, this.readonly = false});

  @override
  _SalesOrderFormPageState createState() => _SalesOrderFormPageState();
}

class _SalesOrderFormPageState extends State<SalesOrderFormPage> {
  String mrName = "",
      soldTo = "",
      dateOfOrder = "",
      salesOrderNo = "",
      address = "",
      shipTo = "",
      telNo = "",
      terms = "";
  String specialNote = '',
      specialInstruction = '',
      notedBy1 = '',
      notedBy2 = '',
      discount = '';
  double grossAmount = 0.0;
  double netAmount = 0.0;
  final List<String> termsOptions = [
    "COD CASH",
    "COD-CHECK",
    "I.S. 60DAYS",
    "NET 30 DAYS",
    "PDC 30 DAYS",
    "PDC 60 DAYS"
  ];
  final Map<String, List<String>> pharmaMapping = {
        "Indofil 800 WP": ["800WP", "Vitamin B1 + B6 + B12", "1 kg", "1500.00"],
        "Indofil 600 OS": ["600 OS", "Vitamin B1 + B6 + B12", "60L Drum", "2500.00"],
        "Indofil 455 F": ["455 F", "Mancozeb 455 g/L", "100L Drum", "3500.00"],
        "Indofil 750 WDG": ["750 WDG", "Mancozeb 750g/Kg", "25Kg bag", "1500.00"],
        "Proviso 250 EC": ["250 EC", "Propiconazole 250 g/L", "100 L Drum", "3500.00"],
        "Moximate 505 WP": ["505 WP", "Cymoxanil 40 g/Kg + Mancozeb 465 g/Kg", "500 g and 1 kg pouch", "2500.00"],
        "Matco 720 WP": ["720 WP", "Metalaxyl 80 g/Kg + Mancozeb 640 g/Kg WP", "100 g pouch and 25 Kg bag", "1500.00"],
        "Nexa 250 EC": ["250 EC", "Difenoconazole 250 g/L", "250 ml & 500 ml bottle and 200 L drum", "1500.00"],
        "Grifon SC": ["SC", "Copper hydroxide 223 g/L + Copper oxychloride 239 g/L", "500 ml Bottle", "2500.00"],

// ============================================================================================

    // "Cramin Forte Caps": ["CRA1", "Vitamin B1 + B6 + B12", "100pcs", "1500.00"],
    // "Dayzinc Drops": [
    //   "DAZ1",
    //   "Ascorbic Acid + Ascorbic Acid (as Sodium Ascorbate) + Zinc",
    //   "30mL",
    //   "121.00"
    // ],
    // "Dayzinc Syrup (120ml)": [
    //   "DAZ2",
    //   "Ascorbic Acid + Ascorbic Acid (as Sodium Ascorbate) + Zinc",
    //   "120mL",
    //   "130"
    // ],
    // "Dayzinc Syrup (250ml)": [
    //   "DAZ6",
    //   "Ascorbic Acid + Ascorbic Acid (as Sodium Ascorbate) + Zinc",
    //   "250mL",
    //   "240"
    // ],
    // "Dayzinc Chew Tabs (30pcs)": [
    //   "DAZ7",
    //   "Ascorbic Acid + Ascorbic Acid (as Sodium Ascorbate) + Zinc",
    //   "30pcs",
    //   "195"
    // ],
    // "Dayzinc Chew Tabs 10+2": [
    //   "DAZ5",
    //   "Ascorbic Acid + Ascorbic Acid (as Sodium Ascorbate) + Zinc",
    //   "12pcs",
    //   "65"
    // ],
    // "Dayzinc Chew Tabs 24+6": [
    //   "DAZ12",
    //   "Ascorbic Acid + Ascorbic Acid (as Sodium Ascorbate) + Zinc",
    //   "30pcs",
    //   "156"
    // ],
    // "Dayzinc Cap": [
    //   "DAZ3",
    //   "Ascorbic Acid + Ascorbic Acid (as Sodium Ascorbate) + Zinc",
    //   "30pcs",
    //   "232.5"
    // ],
    // "Dayzinc Cap 10+2": [
    //   "DAZ8",
    //   "Ascorbic Acid + Ascorbic Acid (as Sodium Ascorbate) + Zinc",
    //   "12pcs",
    //   "77.5"
    // ],
    // "Dayzinc Cap 24+6": [
    //   "DAZ11",
    //   "Ascorbic Acid + Ascorbic Acid (as Sodium Ascorbate) + Zinc",
    //   "30pcs",
    //   "186"
    // ],
    // "Nutri 10 Plus Drops": [
    //   "NUR1",
    //   "Vitamins A-E + CGF + Taurine + Lysine + Zinc",
    //   "30mL",
    //   "145"
    // ],
    // "Nutri 10 Plus Syrup (120ml)": [
    //   "NUR2",
    //   "Vitamins A-E + CGF + Taurine + Lysine + Zinc",
    //   "120mL",
    //   "200"
    // ],
    // "Nutri 10 Plus Syrup (250ml)": [
    //   "NUR5",
    //   "Vitamins A-E + CGF + Taurine + Lysine + Zinc",
    //   "250mL",
    //   "345"
    // ],
    // "Nutri 10 Excel Cap": [
    //   "NUR3",
    //   "Vitamins A-E + CGF + Taurine + Lysine + Zinc",
    //   "30pcs",
    //   "210"
    // ],
    // "Nutri 10 Plus OB Cap": [
    //   "NUR4",
    //   "Vitamins A-D + Iron, Folic Acid",
    //   "30pcs",
    //   "210"
    // ],
    // "Nutrigrow Syrup": [
    //   "NUG2",
    //   "Vitamins + CGF + Taurine",
    //   "120mL",
    //   "155"
    // ],
    // "Nutrigrow Syrup B1G1": [
    //   "NUG3",
    //   "Vitamins + CGF + Taurine",
    //   "120mL",
    //   "155"
    // ],
    // "Aplhabetic Tablet": [
    //   "ABCD",
    //   "Ampalaya + Banaba + Camote + Duhat",
    //   "30pcs",
    //   "330"
    // ],
    // "Daycee Syrup": [
    //   "DAY3",
    //   "Ascorbic Acid (as Sodium Ascorbate)",
    //   "120mL",
    //   "125"
    // ],
    // "Daycee Syrup B1G1": [
    //   "PRM05",
    //   "Ascorbic Acid (as Sodium Ascorbate)",
    //   "120mL",
    //   "125"
    // ],
    // "Daycee Cap": ["DAY6", "Sodium Ascorbate", "30pcs", "180"],
    // "Daycee Cap Buy 60 Cap Save 150": [
    //   "PRM09",
    //   "Sodium Ascorbate",
    //   "30pcs",
    //   "180"
    // ],
    // "Calciday Tab": [
    //   "CAL1",
    //   "Calcium Carbonate + Vitamin D3",
    //   "30pcs",
    //   "210"
    // ],
    // "Calciday Tab 10+2": [
    //   "CAL2",
    //   "Calcium Carbonate + Vitamin D3",
    //   "12pcs",
    //   "70"
    // ],
    // "Perispa 50 Tab": ["PER1", "Eperisone HCI", "30pcs", "540"],
    // "Zefaxim 100PFS": ["ZEF1", "Cefixime", "60mL", "528"],
    // "Maximmune Syrup": ["MAX1", "CM-Glucan", "120mL", "360"],
    // "C2Zinc Drops": [
    //   "C2Z2",
    //   "Ascorbic Acid + Sodium Ascorbate + Zinc",
    //   "30mL",
    //   "100"
    // ],
    // "C2Zinc Syrup": [
    //   "C2Z4",
    //   "Ascorbic Acid + Sodium Ascorbate + Zinc",
    //   "120mL",
    //   "120"
    // ],
    // "SGX Cap": ["SGX2", "Salbutamol + Guaifanesin", "100pcs", "650"],
    // "CFC 50 PFOD": ["CFC1", "Cefactor", "20mL", "200"],
  };
  final Map<String, List<String>> dermaMapping = {
    "Akostar 480 SL": ["480 SL", "Glyphosate as Isopropylamine salt 480 g/L", "200mL", "1350.00"],
    "Glowstar 150 SL": ["150 SL", "Glufosinate ammonium 150 g/L", "	1 L and 4 L bottle and 200 L drum", "3350.00"],

    // "Dermatonics Dry Skin Balm": ["DRB03", "", "200mL", "1350"],
    // "Ultraveen Relief Cream": ["ULC01", "", "125mL", "975"],
    // "Dermatonics Heel Balm w/ Manuka Honey": ["DRB01", "", "60mL", "695"],
    // "Dermatonics Ultracool Foot Gel": ["DRB02", "", "60mL", "695"],
    // "Dermatonics Soothing Foot Cream": ["DRC01", "", "60mL", "695"],
    // "Dermatonics Hard Skin Removing Balm": ["DRG01", "", "60mL", "710"],
  };

  List<Map<String, dynamic>> pharmaRows = [];
  List<Map<String, dynamic>> dermaRows = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final todayString =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    if (widget.formData != null) {
      final d = widget.formData!;
      mrName = d['mrName'] ?? "";
      soldTo = d['soldTo'] ?? "";
      dateOfOrder =
          d['dateOfOrder'] ?? todayString; // fallback to today if missing
      salesOrderNo = d['salesOrderNo'] ?? "";
      address = d['address'] ?? "";
      shipTo = d['shipTo'] ?? "";
      telNo = d['telNo'] ?? "";
      terms = d['terms'] ?? "";
      specialNote = d['specialNote'] ?? "";
      specialInstruction = d['specialInstruction'] ?? "";
      notedBy1 = d['notedBy1'] ?? "";
      notedBy2 = d['notedBy2'] ?? "";
      discount = d['discount']?.toString() ?? '';
      pharmaRows = List<Map<String, dynamic>>.from(d['pharmaRows'] ?? []);
      dermaRows = List<Map<String, dynamic>>.from(d['dermaRows'] ?? []);
    } else {
      // New form: always set Date of Order to today's date
      dateOfOrder = todayString;
    }
  }

  double computeGross() => [...pharmaRows, ...dermaRows]
      .map((r) => r["amount"] as double? ?? 0)
      .fold(0.0, (a, b) => a + b);

  double computeNet(double gross) {
    if (discount.isEmpty || double.tryParse(discount) == 0) return gross;
    double disc = double.tryParse(discount) ?? 0.0;
    return gross * (1.0 - disc / 100.0);
  }

  void _addPharmaProduct() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (_) => SimpleDialog(
        title: Text('Select Fungicides'/**'Select Pharma Product' */),
        children: pharmaMapping.keys
            .map((prod) => SimpleDialogOption(
                  child: Text(prod),
                  onPressed: () => Navigator.pop(context, prod),
                ))
            .toList(),
      ),
    );
    if (selected != null) {
      final entry = pharmaMapping[selected]!;
      setState(() {
        pharmaRows.add({
          "desc": selected,
          "code": entry[0],
          "generic": entry[1],
          "pack": entry[2],
          "reg": 0,
          "free": 0,
          "price": entry[3],
          "amount": 0.0,
        });
        _recalcAmounts();
      });
    }
  }

  void _addDermaProduct() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (_) => SimpleDialog(
        title: Text('Select Herbicides'/**'Select Derma Product' */),
        children: dermaMapping.keys
            .map((prod) => SimpleDialogOption(
                  child: Text(prod),
                  onPressed: () => Navigator.pop(context, prod),
                ))
            .toList(),
      ),
    );
    if (selected != null) {
      final entry = dermaMapping[selected]!;
      setState(() {
        dermaRows.add({
          "desc": selected,
          "code": entry[0],
          "generic": entry[1],
          "pack": entry[2],
          "reg": 0,
          "free": 0,
          "price": entry[3],
          "amount": 0.0,
        });
        _recalcAmounts();
      });
    }
  }

  void _recalcAmounts() {
    for (var row in pharmaRows) {
      final reg = int.tryParse(row["reg"].toString()) ?? 0;
      final price = double.tryParse(row["price"].toString()) ?? 0.0;
      row["amount"] = reg * price;
    }
    for (var row in dermaRows) {
      final reg = int.tryParse(row["reg"].toString()) ?? 0;
      final price = double.tryParse(row["price"].toString()) ?? 0.0;
      row["amount"] = reg * price;
    }
    grossAmount = computeGross();
    netAmount = computeNet(grossAmount);
  }

  void _resetForm() {
    setState(() {
      mrName = soldTo = salesOrderNo = address = shipTo = telNo = terms =
          specialNote = specialInstruction = notedBy1 = notedBy2 = discount = "";
      pharmaRows.clear();
      dermaRows.clear();
      grossAmount = netAmount = 0.0;

      final now = DateTime.now();
      dateOfOrder =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    });
  }

  Future<String> getSanitizedUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final userEmail = prefs.getString('userEmail') ?? '';
    return userEmail.replaceAll(RegExp(r'[.#\$\\\[\]/]'), '_');
  }

  Future<void> _submit() async {
    _recalcAmounts();
    final data = {
      "mrName": mrName,
      "soldTo": soldTo,
      "dateOfOrder": dateOfOrder,
      "salesOrderNo": salesOrderNo,
      "address": address,
      "shipTo": shipTo,
      "telNo": telNo,
      "terms": terms,
      "specialNote": specialNote,
      "specialInstruction": specialInstruction,
      "notedBy1": notedBy1,
      "notedBy2": notedBy2,
      "discount": discount,
      "pharmaRows": pharmaRows,
      "dermaRows": dermaRows,
      "grossAmount": grossAmount,
      "netAmount": netAmount,
      "timestamp": FieldValue.serverTimestamp(),
    };
    final userKey = await getSanitizedUserEmail();
    await FirebaseFirestore.instance
        .collection('flowDB')
        .doc('users')
        .collection(userKey)
        .doc('sales_orders')
        .collection('sales_orders')
        .add(data);
    Navigator.pop(context, true);
  }

  // ---- UI WIDGETS BELOW (no logic skipped) ----

  InputDecoration _inputDeco(String label) => InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.cyan.shade50,
      );

  Widget _scrollTableArea({required Widget child}) => Scrollbar(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: 800),
            child: child,
          ),
        ),
      );

  Widget _tableHeader() => Row(
        children: [
          _tableCell("Product Code", true),
          _tableCell("Product Description", true),
          _tableCell("Active Ingredient"/**"Generic Name"*/, true),
          _tableCell("Pack Size", true),
          Container(
            width: 130,
            child: Column(
              children: [
                Text("Quantity", style: TextStyle(fontWeight: FontWeight.bold)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                        child: Center(
                            child:
                                Text("Reg", style: TextStyle(fontSize: 13)))),
                    Expanded(
                        child: Center(
                            child:
                                Text("Free", style: TextStyle(fontSize: 13)))),
                  ],
                ),
              ],
            ),
          ),
          _tableCell("Unit Price", true),
          _tableCell("Amount", true),
        ],
      );

  Widget _yellowSection(String title) => Container(
        width: 830,
        color: Colors.yellow.shade100,
        padding: EdgeInsets.symmetric(vertical: 9),
        child: Center(
            child: Text(title,
                style:
                    TextStyle(fontWeight: FontWeight.w600, fontSize: 17))),
      );

  Widget _rowTable(List<Map<String, dynamic>> products) => Column(
        children: products.asMap().entries.map((e) {
          return Row(
            children: [
              _tableCell(e.value["code"] ?? ""),
              _tableCell(e.value["desc"] ?? ""),
              _tableCell(e.value["generic"] ?? ""),
              _tableCell(e.value["pack"] ?? ""),
              _tableCellWidget(
                  child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: e.value["reg"].toString(),
                      readOnly: widget.readonly,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        contentPadding:
                            EdgeInsets.symmetric(vertical: 0, horizontal: 0),
                        border: InputBorder.none,
                      ),
                      onChanged: widget.readonly
                          ? null
                          : (v) {
                              setState(() {
                                e.value["reg"] = int.tryParse(v) ?? 0;
                                e.value["amount"] =
                                    (e.value["reg"] as int) *
                                        double.parse(e.value["price"]);
                                _recalcAmounts();
                              });
                            },
                      style: TextStyle(fontSize: 15),
                    ),
                  ),
                  VerticalDivider(width: 1, thickness: 1),
                  Expanded(
                    child: TextFormField(
                      initialValue: e.value["free"].toString(),
                      readOnly: widget.readonly,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        contentPadding:
                            EdgeInsets.symmetric(vertical: 0, horizontal: 0),
                        border: InputBorder.none,
                      ),
                      onChanged: widget.readonly
                          ? null
                          : (v) {
                              setState(() {
                                e.value["free"] = int.tryParse(v) ?? 0;
                              });
                            },
                      style: TextStyle(fontSize: 15),
                    ),
                  ),
                ],
              )),
              _tableCell(e.value["price"].toString()),
              _tableCell((e.value["amount"] ?? 0.0).toStringAsFixed(2)),
            ],
          );
        }).toList(),
      );

  Widget _tableCellWidget({required Widget child, bool header = false}) =>
      Container(
        width: 120,
        height: header ? 50 : 48,
        padding: EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: header ? Colors.cyan[100] : Colors.white,
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Center(child: child),
      );

  Widget _tableCell(String text, [bool header = false]) => Container(
        width: 120,
        height: header ? 50 : null,
        padding: EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        color: header ? Colors.cyan[100] : null,
        child: Center(
          child: Text(text,
              style: TextStyle(
                  fontSize: header ? 10 : 15,
                  fontWeight:
                      header ? FontWeight.bold : FontWeight.normal)),
        ),
      );

  Widget _inputBox(String label, String value, void Function(String) onChanged,
          {bool readOnly = false, TextInputType? type}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10.0),
        child: TextFormField(
          initialValue: value,
          readOnly: readOnly,
          keyboardType: type,
          onChanged: readOnly ? null : onChanged,
          style: TextStyle(fontSize: 16),
          decoration: _inputDeco(label),
        ),
      );

  Widget _readOnlyField(String label, String value, {Color? color}) => Padding(
        padding: const EdgeInsets.only(bottom: 8.0, top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    color: color ?? Colors.black54,
                    fontWeight: FontWeight.w600)),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              margin: EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                  color: Colors.cyan.shade100,
                  borderRadius: BorderRadius.circular(7)),
              child: Text(value,
                  style:
                      TextStyle(fontSize: 18, color: color ?? Colors.black)),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    grossAmount = computeGross();
    netAmount = computeNet(grossAmount);
    final isReadonly = widget.readonly;

    return Scaffold(
      appBar: AppBar(
        title: Text(isReadonly ? "View Sales Order" : "Sales Order Form"),
        backgroundColor: Color(0xFF5958b2),
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(14),
        child: Column(
          children: [
            Wrap(
              runSpacing: 10,
              children: [
                _inputBox("Name", mrName,
                    (v) => setState(() => mrName = v),
                    readOnly: isReadonly),
                _inputBox("Sold To", soldTo,
                    (v) => setState(() => soldTo = v),
                    readOnly: isReadonly),

                // Date of Order: always date, never editable
                _inputBox(
                  "Date of Order",
                  dateOfOrder,
                  (_) {},
                  readOnly: true,
                ),

                _inputBox("Sales Order No.", salesOrderNo,
                    (v) => setState(() => salesOrderNo = v),
                    readOnly: isReadonly),
                _inputBox("Address", address,
                    (v) => setState(() => address = v),
                    readOnly: isReadonly),
                _inputBox("Ship To", shipTo,
                    (v) => setState(() => shipTo = v),
                    readOnly: isReadonly),
                _inputBox("Tel No.", telNo,
                    (v) => setState(() => telNo = v),
                    readOnly: isReadonly),
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: DropdownButtonFormField<String>(
                    decoration: _inputDeco("Terms"),
                    value: terms.isNotEmpty ? terms : null,
                    items: termsOptions
                        .map((opt) =>
                            DropdownMenuItem(value: opt, child: Text(opt)))
                        .toList(),
                    onChanged: isReadonly
                        ? null
                        : (val) {
                            setState(() => terms = val!);
                          },
                  ),
                ),
                _inputBox(
                    "Special Notes on Invoice",
                    specialNote,
                    (v) => setState(() => specialNote = v),
                    readOnly: isReadonly),
              ],
            ),
            SizedBox(height: 8),
            _scrollTableArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _tableHeader(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      if (!isReadonly)
                        ElevatedButton(
                          onPressed: _addPharmaProduct,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade300,
                            foregroundColor: Colors.black,
                            minimumSize: const Size(32, 32),
                            padding: EdgeInsets.zero,
                          ),
                          child: const Text(
                            "+",
                            style: TextStyle(fontSize: 24),
                          ),
                        ),
                      const SizedBox(width: 8),
                      _yellowSection("Fungicides"),
                    ],
                  ),
                  _rowTable(pharmaRows),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      if (!isReadonly)
                        ElevatedButton(
                          onPressed: _addDermaProduct,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade300,
                            foregroundColor: Colors.black,
                            minimumSize: const Size(32, 32),
                            padding: EdgeInsets.zero,
                          ),
                          child: const Text(
                            "+",
                            style: TextStyle(fontSize: 24),
                          ),
                        ),
                      const SizedBox(width: 8),
                      _yellowSection("Herbicides"),
                    ],
                  ),
                  _rowTable(dermaRows),
                ],
              ),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _readOnlyField("Gross Amount", grossAmount.toStringAsFixed(2))),
                SizedBox(width: 8),
                Expanded(
                  child: _inputBox(
                    "Discount (%)",
                    discount,
                    (v) {
                      setState(() {
                        discount = v;
                        _recalcAmounts();
                      });
                    },
                    readOnly: isReadonly,
                    type: TextInputType.number,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: _readOnlyField(
                    "Net Amount",
                    netAmount.toStringAsFixed(2),
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            // Signature and Noted By
            // Container(
            //   height: 100,
            //   decoration: BoxDecoration(
            //     border: Border.all(color: Colors.grey),
            //     borderRadius: BorderRadius.circular(15),
            //   ),
            //   margin: EdgeInsets.only(bottom: 10),
            //   child: Center(
            //     child: Text(
            //       isReadonly ? "Signature Pad (View only)" : "Signature Pad",
            //     ),
            //   ),
            // ),
            Row(
              children: [
                Expanded(
                  child: _inputBox(
                    "Noted By",
                    notedBy1,
                    (v) => setState(() => notedBy1 = v),
                    readOnly: isReadonly,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: _inputBox(
                    "Special Instructions",
                    specialInstruction,
                    (v) => setState(() => specialInstruction = v),
                    readOnly: isReadonly,
                  ),
                ),
              ],
            ),
            SizedBox(height: 80),
          ],
        ),
      ),

      // PERSISTENT FLOATING RESET/SUBMIT BUTTONS
      persistentFooterButtons: !isReadonly
          ? [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 140,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade300,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                      onPressed: _resetForm,
                      child: const Text(
                        "Reset",
                        style: TextStyle(color: Colors.black),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  SizedBox(
                    width: 140,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                      onPressed: _submit,
                      child: const Text(
                        "Submit",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ]
          : null,
    );
  }
}
