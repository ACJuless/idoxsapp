import 'package:flutter/material.dart';

class CustomItineraryReadonlyPage extends StatelessWidget {
  final Map<String, dynamic> formData;
  final String docId;

  const CustomItineraryReadonlyPage({
    Key? key,
    required this.formData,
    required this.docId,
  }) : super(key: key);

  static const Color _colorPrimaryDark = Color(0xFF4A2371);
  static const Color _colorPrimary = Color(0xFF5958B2);
  static const Color _colorSurface = Color(0xFFF9F5FF);
  static const Color _colorCard = Colors.white;
  static const Color _colorText = Color(0xFF1A1A2E);
  static const Color _colorMuted = Color(0xFF4B5563);

  static const double _maxWidth = 760;

  LinearGradient get _headerGradient => const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          _colorPrimaryDark,
          _colorPrimaryDark,
          _colorPrimary,
        ],
        stops: [0.0, 0.55, 1.0],
      );

  String _s(dynamic v) => (v ?? '').toString();

  String _formatDate(dynamic raw) {
    final s = _s(raw).trim();
    if (s.isEmpty) return '';
    // If it’s a local datetime string, normalise T -> space.
    if (s.contains('T')) return s.replaceFirst('T', ' ');
    return s;
  }

  List<Map<String, dynamic>> _segments() {
    final raw = formData['segments'];
    if (raw is List) {
      return raw.map<Map<String, dynamic>>((e) {
        if (e is Map<String, dynamic>) return e;
        if (e is Map) return Map<String, dynamic>.from(e);
        return <String, dynamic>{};
      }).toList();
    }
    return const <Map<String, dynamic>>[];
  }

  @override
  Widget build(BuildContext context) {
    final tripTitle = _s(formData['tripTitle']).trim();
    final travelerName = _s(formData['travelerName']).trim();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Custom Itinerary'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: _colorPrimaryDark,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: _headerGradient,
          ),
        ),
      ),
      backgroundColor: _colorSurface,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxWidth),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 32),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeaderCard(tripTitle, travelerName),
                      const SizedBox(height: 18),
                      _buildTripDetailsCard(),
                      const SizedBox(height: 18),
                      _buildMetaInfoCard(),
                      const SizedBox(height: 18),
                      _buildSegmentsSection(),
                      const SizedBox(height: 18),
                      _buildNotesCard(),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // HEADER CARD
  Widget _buildHeaderCard(String tripTitle, String travelerName) {
    final destination = _s(formData['destination']).trim();
    final startDate = _formatDate(formData['startDate']);
    final endDate = _formatDate(formData['endDate']);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [
            _colorPrimaryDark,
            _colorPrimary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tripTitle.isNotEmpty ? tripTitle : 'Custom Itinerary',
            style: const TextStyle(
              fontSize: 20,
              fontFamily: 'OpenSauce',
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.1,
            ),
          ),
          const SizedBox(height: 6),
          if (destination.isNotEmpty)
            Text(
              destination,
              style: const TextStyle(
                fontSize: 13,
                fontFamily: 'OpenSauce',
                fontWeight: FontWeight.w500,
                color: Color(0xFFE5E7EB),
              ),
            ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              if (travelerName.isNotEmpty)
                _headerChip(
                  icon: Icons.person_outline,
                  label: travelerName,
                ),
              if (startDate.isNotEmpty || endDate.isNotEmpty)
                _headerChip(
                  icon: Icons.calendar_month_outlined,
                  label: (startDate.isNotEmpty && endDate.isNotEmpty)
                      ? '$startDate – $endDate'
                      : (startDate.isNotEmpty ? startDate : endDate),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withOpacity(0.35),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontFamily: 'OpenSauce',
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // CARD WRAPPER
  Widget _card(Widget child) {
    return Container(
      decoration: BoxDecoration(
        color: _colorCard,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _sectionLabel(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 13,
          fontFamily: 'OpenSauce',
          fontWeight: FontWeight.w700,
          color: _colorPrimary,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _fieldRow(String label, String value, {bool last = false}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: last ? Colors.transparent : const Color(0xFFF0EBF9),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10.5,
              fontFamily: 'OpenSauce',
              fontWeight: FontWeight.w700,
              color: _colorMuted,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0x0D6B21C8), // subtle tinted background
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: const Color(0x406B21C8),
                width: 1.5,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            child: Text(
              value.trim().isEmpty ? '-' : value,
              style: const TextStyle(
                fontSize: 15,
                fontFamily: 'OpenSauce',
                fontWeight: FontWeight.w500,
                color: _colorText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _twoColRow({
    required String labelLeft,
    required String valueLeft,
    required String labelRight,
    required String valueRight,
    bool last = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: last ? Colors.transparent : const Color(0xFFF0EBF9),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _fieldRow(labelLeft, valueLeft, last: true),
          ),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: Color(0xFFF0EBF9),
                    width: 1,
                  ),
                ),
              ),
              child: _fieldRow(labelRight, valueRight, last: true),
            ),
          ),
        ],
      ),
    );
  }

  // TRIP DETAILS CARD
  Widget _buildTripDetailsCard() {
    final destination = _s(formData['destination']).trim();
    final startDate = _formatDate(formData['startDate']);
    final endDate = _formatDate(formData['endDate']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Trip Details'),
        _card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _fieldRow('Destination', destination),
              _twoColRow(
                labelLeft: 'Start Date',
                valueLeft: startDate,
                labelRight: 'End Date',
                valueRight: endDate,
                last: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // META INFO CARD (created by, created at, doc id)
  Widget _buildMetaInfoCard() {
    final createdBy = _s(formData['createdBy']).trim();
    final createdAt = _formatDate(formData['timestamp'] ?? formData['createdAt']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Meta Information'),
        _card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _fieldRow('Created By', createdBy),
              _fieldRow('Created At', createdAt),
              _fieldRow('Document ID', docId, last: true),
            ],
          ),
        ),
      ],
    );
  }

  // SEGMENTS
  Widget _buildSegmentsSection() {
    final segments = _segments();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Itinerary Segments'),
        if (segments.isEmpty)
          _card(
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Text(
                'No segments added.',
                style: TextStyle(
                  fontSize: 13,
                  fontFamily: 'OpenSauce',
                  fontWeight: FontWeight.w400,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          )
        else
          Column(
            children: List.generate(
              segments.length,
              (index) => _buildSegmentCard(segments[index], index),
            ),
          ),
      ],
    );
  }

  Widget _buildSegmentCard(Map<String, dynamic> segment, int index) {
    final dayLabel = _s(segment['dayLabel']).trim();
    final date = _formatDate(segment['date']);
    final location = _s(segment['location']).trim();
    final activity = _s(segment['activity']).trim();
    final timeRange = _s(segment['timeRange']).trim();
    final remarks = _s(segment['remarks']).trim();

    final headerTitle = dayLabel.isNotEmpty
        ? dayLabel
        : 'Segment ${index + 1}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _colorCard,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0x126B21C8),
                  const Color(0x086345FF),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    gradient: _headerGradient,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontFamily: 'OpenSauce',
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    headerTitle,
                    style: const TextStyle(
                      fontSize: 14,
                      fontFamily: 'OpenSauce',
                      fontWeight: FontWeight.w700,
                      color: _colorPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Body
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _segmentField('Date', date),
                _segmentField('Location', location),
                _segmentField('Activity', activity),
                _segmentField('Time', timeRange),
                if (remarks.isNotEmpty)
                  _segmentField('Remarks', remarks, last: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _segmentField(String label, String value, {bool last = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10.5,
              fontFamily: 'OpenSauce',
              fontWeight: FontWeight.w700,
              color: _colorMuted,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 3),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0x0D6B21C8),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0x386B21C8),
                width: 1.5,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Text(
              value.trim().isEmpty ? '-' : value,
              style: const TextStyle(
                fontSize: 14.5,
                fontFamily: 'OpenSauce',
                fontWeight: FontWeight.w500,
                color: _colorText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // NOTES CARD
  Widget _buildNotesCard() {
    final notes = _s(formData['notes']).trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Notes'),
        _card(
          _fieldRow('Additional Notes', notes, last: true),
        ),
      ],
    );
  }
}