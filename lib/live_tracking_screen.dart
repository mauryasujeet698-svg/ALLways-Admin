import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

const _mapboxPublicToken = String.fromEnvironment('MAPBOX_PUBLIC_TOKEN');
String _mapboxTiles() => 'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/256/{z}/{x}/{y}?access_token=' + _mapboxPublicToken;

class AdminLiveTrackingScreen extends StatefulWidget {
  final Color accent;
  const AdminLiveTrackingScreen({super.key, required this.accent});

  @override
  State<AdminLiveTrackingScreen> createState() => _AdminLiveTrackingScreenState();
}

class _AdminLiveTrackingScreenState extends State<AdminLiveTrackingScreen> {
  final TextEditingController _search = TextEditingController();
  String _statusFilter = 'All active';
  String _assignment = 'All';
  String _dateRange = 'Last 7 days';

  static const _offset = Duration(hours: 5, minutes: 30);
  static const _activeRideStatuses = {'searching', 'accepted', 'arrived', 'started'};
  static const _activeOrderStatuses = {
    'pending', 'new order', 'searching', 'ready', 'pending_acceptance',
    'assigned', 'picked up', 'out for delivery', 'arrived', 'preparing'
  };

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is num) {
      final n = value.toInt();
      return DateTime.fromMillisecondsSinceEpoch(n < 100000000000 ? n * 1000 : n);
    }
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  DateTime _indiaToday() {
    final now = DateTime.now().toUtc().add(_offset);
    return DateTime.utc(now.year, now.month, now.day);
  }

  bool _inRange(DateTime? instant) {
    if (instant == null) return _dateRange == 'All time';
    final shifted = instant.toUtc().add(_offset);
    final day = DateTime.utc(shifted.year, shifted.month, shifted.day);
    final today = _indiaToday();
    final start = switch (_dateRange) {
      'Today' => today,
      'This month' => DateTime.utc(today.year, today.month),
      'This year' => DateTime.utc(today.year),
      'All time' => DateTime.utc(2000),
      _ => today.subtract(const Duration(days: 6)),
    };
    final end = switch (_dateRange) {
      'Today' => today.add(const Duration(days: 1)),
      'This month' => DateTime.utc(today.year, today.month + 1),
      'This year' => DateTime.utc(today.year + 1),
      'All time' => DateTime.utc(2100),
      _ => today.add(const Duration(days: 1)),
    };
    return !day.isBefore(start) && day.isBefore(end);
  }

  String _jobStatus(Map<String, dynamic> x) => (x['status'] ?? 'unknown').toString().trim().toLowerCase();
  String _partnerId(Map<String, dynamic> x, {required bool ride}) =>
      (ride
          ? (x['driverUid'] ?? x['carrierUid'] ?? x['assignedPartnerId'] ?? '')
          : (x['carrierUid'] ?? x['deliveryPartnerUid'] ?? x['deliveryPartnerId'] ?? x['assignedPartnerId'] ?? ''))
          .toString().trim();
  String _partnerName(Map<String, dynamic> x, {required bool ride}) =>
      (ride ? (x['driverName'] ?? 'Unassigned') : (x['carrierName'] ?? x['deliveryPartnerName'] ?? 'Unassigned')).toString();
  String _customerName(Map<String, dynamic> x) =>
      (x['customerName'] ?? x['name'] ?? x['customerId'] ?? x['uid'] ?? 'Customer details unavailable').toString();
  String _reference(Map<String, dynamic> x, String id) => (x['orderId'] ?? x['rideId'] ?? x['id'] ?? id).toString();
  String _address(Map<String, dynamic> x, {required bool ride}) => ride
      ? '${x['pickupAddress'] ?? x['address'] ?? 'Pickup unavailable'} → ${x['destinationAddress'] ?? x['destination'] ?? 'Destination unavailable'}'
      : (x['address'] ?? x['deliveryAddress'] ?? x['shippingAddress'] ?? 'Delivery address unavailable').toString();

  DateTime? _created(Map<String, dynamic> x, {required bool ride}) =>
      _date(x[ride ? 'requestedAt' : 'createdAt']) ??
      _date(x['createdAt']) ?? _date(x['assignedAt']) ?? _date(x['updatedAt']);

  DateTime? _locationUpdatedAt(Map<String, dynamic> x, {required bool ride}) =>
      _date(x[ride ? 'driverLocationUpdatedAt' : 'carrierLocationUpdatedAt']) ??
      _date(x[ride ? 'driverLastLocationAt' : 'lastLocationAt']);
  DateTime? _lastActivity(Map<String, dynamic> x, {required bool ride}) =>
      _locationUpdatedAt(x, ride: ride) ?? _date(x['lastActivityAt']) ?? _date(x['statusUpdatedAt']) ?? _date(x['updatedAt']);

  bool _isFresh(DateTime? date) =>
      date != null && DateTime.now().toUtc().difference(date.toUtc()) <= const Duration(minutes: 2) &&
      !date.isAfter(DateTime.now().add(const Duration(minutes: 1)));

  bool _matches(Map<String, dynamic> x, String id, {required bool ride}) {
    final status = _jobStatus(x);
    if (!(ride ? _activeRideStatuses : _activeOrderStatuses).contains(status)) return false;
    if (!_inRange(_created(x, ride: ride))) return false;
    if (_statusFilter != 'All active' && status != _statusFilter.toLowerCase()) return false;
    final assigned = _partnerId(x, ride: ride).isNotEmpty;
    if (_assignment == 'Assigned' && !assigned) return false;
    if (_assignment == 'Unassigned' && assigned) return false;
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return true;
    final haystack = [
      id, _reference(x, id), _customerName(x), _partnerName(x, ride: ride),
      _partnerId(x, ride: ride), _address(x, ride: ride), status,
    ].join(' ').toLowerCase();
    return haystack.contains(q);
  }

  double _number(dynamic value) => value is num ? value.toDouble() : double.tryParse((value ?? '').toString()) ?? 0;

  Widget _jobCard(BuildContext context, QueryDocumentSnapshot<Map<String, dynamic>> doc, {required bool ride}) {
    final x = doc.data();
    final status = _jobStatus(x);
    final partnerId = _partnerId(x, ride: ride);
    final assigned = partnerId.isNotEmpty;
    final activity = _lastActivity(x, ride: ride);
    final locationTime = _locationUpdatedAt(x, ride: ride);
    final fresh = _isFresh(locationTime);
    final lat = _number(ride ? x['driverLat'] : (x['carrierLat'] ?? x['deliveryLat']));
    final lng = _number(ride ? x['driverLng'] : (x['carrierLng'] ?? x['deliveryLng']));
    final hasValidCoords = lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180 && lat != 0 && lng != 0;
    final canShowLiveLocation = assigned && fresh && hasValidCoords;
    final created = _created(x, ride: ride);
    final stale = assigned && (activity == null || DateTime.now().toUtc().difference(activity.toUtc()) > const Duration(minutes: 10));

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(ride ? Icons.two_wheeler : Icons.local_shipping, color: widget.accent),
            const SizedBox(width: 8),
            Expanded(child: Text('#${_reference(x, doc.id)}', style: const TextStyle(fontWeight: FontWeight.w900))),
            _statusBadge(status),
          ]),
          const SizedBox(height: 8),
          Text('Customer: ${_customerName(x)}', maxLines: 2, overflow: TextOverflow.ellipsis),
          Text('${ride ? 'Driver' : 'Delivery partner'}: ${_partnerName(x, ride: ride)}${assigned ? ' • $partnerId' : ''}',
              maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(_address(x, ride: ride), maxLines: 3, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 7),
          Wrap(spacing: 8, runSpacing: 5, children: [
            _infoChip(assigned ? 'Assigned' : 'UNASSIGNED', assigned ? Icons.person : Icons.person_off),
            if (created != null) _infoChip('Created ${_age(created)} ago', Icons.schedule),
            if (activity != null) _infoChip('Activity ${_age(activity)} ago', Icons.update),
          ]),
          if (!assigned)
            const Padding(padding: EdgeInsets.only(top: 8), child: Text('Action needed: assign a partner.', style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.w800))),
          if (stale)
            const Padding(padding: EdgeInsets.only(top: 8), child: Text('Stale activity: no recent location/activity update. Verify status with the partner.', style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.w800))),
          if (assigned && activity == null)
            const Padding(padding: EdgeInsets.only(top: 8), child: Text('Last activity time unavailable; location is not treated as live.', style: TextStyle(color: Colors.grey))),
          if (canShowLiveLocation)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => openMap(context, lat, lng),
                icon: const Icon(Icons.map_outlined),
                label: const Text('Open recent location'),
              ),
            )
          else if (assigned && hasValidCoords)
            const Padding(padding: EdgeInsets.only(top: 8), child: Text('Saved coordinates are stale; hidden as live location.', style: TextStyle(color: Colors.grey))),
        ]),
      ),
    );
  }

  String _age(DateTime date) {
    final duration = DateTime.now().toUtc().difference(date.toUtc());
    if (duration.isNegative) return 'just now';
    if (duration.inMinutes < 1) return 'under 1 min';
    if (duration.inHours < 1) return '${duration.inMinutes} min';
    if (duration.inDays < 1) return '${duration.inHours} hr';
    return '${duration.inDays} days';
  }

  Widget _statusBadge(String status) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(color: widget.accent.withOpacity(.10), borderRadius: BorderRadius.circular(20)),
    child: Text(status.toUpperCase(), style: TextStyle(color: widget.accent, fontSize: 10, fontWeight: FontWeight.w900)),
  );

  Widget _infoChip(String label, IconData icon) => Chip(
    visualDensity: VisualDensity.compact,
    avatar: Icon(icon, size: 15),
    label: Text(label, style: const TextStyle(fontSize: 11)),
  );

  void openMap(BuildContext context, double lat, double lng) {
    if (lat == 0 || lng == 0 || lat < -90 || lat > 90 || lng < -180 || lng > 180) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AdminMapPage(accent: widget.accent, partner: LatLng(lat, lng)),
    ));
  }

  Widget _section(String title, List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, {required bool ride}) {
    final matching = docs.where((d) => _matches(d.data(), d.id, ride: ride)).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 8),
        child: Text('$title (${matching.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
      ),
      if (matching.isEmpty)
        const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('No active jobs match these filters.')))
      else
        ...matching.map((d) => _jobCard(context, d, ride: ride)),
    ]);
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
    children: [
      Card(
        elevation: 0,
        color: widget.accent.withOpacity(.08),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Row(children: [
            Icon(Icons.gps_fixed),
            SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Live Operations', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              SizedBox(height: 4),
              Text('Active rides and deliveries. Saved locations are shown as live only when their timestamp is recent.'),
            ])),
          ]),
        ),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _search,
        decoration: const InputDecoration(labelText: 'Search reference, customer or partner', prefixIcon: Icon(Icons.search), border: OutlineInputBorder()),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        _dropdown('Date', _dateRange, const ['Today', 'Last 7 days', 'This month', 'This year', 'All time'], (v) => setState(() => _dateRange = v)),
        _dropdown('Status', _statusFilter, const ['All active', 'searching', 'accepted', 'started', 'arrived', 'pending', 'assigned', 'picked up', 'out for delivery', 'ready', 'preparing'], (v) => setState(() => _statusFilter = v)),
        _dropdown('Assignment', _assignment, const ['All', 'Assigned', 'Unassigned'], (v) => setState(() => _assignment = v)),
      ]),
      const SizedBox(height: 8),
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('autoRideRequests').snapshots(),
        builder: (context, ridesSnap) {
          if (ridesSnap.hasError) return Text('Could not load rides: ${ridesSnap.error}');
          if (!ridesSnap.hasData) return const Center(child: CircularProgressIndicator());
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('orders').snapshots(),
            builder: (context, ordersSnap) {
              if (ordersSnap.hasError) return Text('Could not load deliveries: ${ordersSnap.error}');
              if (!ordersSnap.hasData) return const Center(child: CircularProgressIndicator());
              final rides = ridesSnap.data!.docs;
              final orders = ordersSnap.data!.docs;
              final visibleRides = rides.where((d) => _matches(d.data(), d.id, ride: true)).length;
              final visibleOrders = orders.where((d) => _matches(d.data(), d.id, ride: false)).length;
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Matching active jobs: ${visibleRides + visibleOrders} • ${visibleRides} rides • ${visibleOrders} deliveries', style: const TextStyle(fontWeight: FontWeight.w800)),
                _section('Active rides', rides, ride: true),
                _section('Active deliveries', orders, ride: false),
              ]);
            },
          );
        },
      ),
    ],
  );

  Widget _dropdown(String label, String value, List<String> options, ValueChanged<String> onChanged) =>
      SizedBox(
        width: label == 'Status' ? 175 : 140,
        child: DropdownButtonFormField<String>(
          value: value,
          isExpanded: true,
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
          items: options.map((v) => DropdownMenuItem(value: v, child: Text(v, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: (v) { if (v != null) onChanged(v); },
        ),
      );
}

class AdminMapPage extends StatelessWidget {
  final Color accent;
  final LatLng partner;
  const AdminMapPage({super.key, required this.accent, required this.partner});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recent Partner Location')),
      body: FlutterMap(
        options: MapOptions(initialCenter: partner, initialZoom: 15),
        children: [
          TileLayer(
            urlTemplate: _mapboxTiles(),
            tileSize: 256,
            maxZoom: 19,
            userAgentPackageName: 'com.allways.admin',
          ),
          RichAttributionWidget(attributions: const [TextSourceAttribution('© Mapbox © OpenStreetMap')]),
          MarkerLayer(markers: [
            Marker(
              point: partner,
              width: 56,
              height: 56,
              child: CircleAvatar(backgroundColor: accent, child: const Icon(Icons.navigation, color: Colors.white)),
            ),
          ]),
        ],
      ),
    );
  }
}
