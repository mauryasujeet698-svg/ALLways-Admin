import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminLiveTrackingScreen extends StatelessWidget {
  final Color accent;
  const AdminLiveTrackingScreen({super.key, required this.accent});

  double n(dynamic v) => v is num ? v.toDouble() : double.tryParse((v ?? '').toString()) ?? 0;

  String age(dynamic value) {
    DateTime? t;
    if (value is Timestamp) t = value.toDate();
    if (t == null) return 'Location time unavailable';
    final d = DateTime.now().difference(t);
    if (d.inSeconds < 60) return 'Updated ${d.inSeconds}s ago';
    if (d.inMinutes < 60) return 'Updated ${d.inMinutes}m ago';
    return 'Updated ${d.inHours}h ago';
  }

  Future<void> openMap(double lat, double lng) async {
    if (lat == 0 || lng == 0) return;
    final uri = Uri.parse('https://www.openstreetmap.org/?mlat=$lat&mlon=$lng#map=17/$lat/$lng');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget card({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String status,
    required double lat,
    required double lng,
    required dynamic updatedAt,
    required IconData icon,
  }) {
    final hasLocation = lat != 0 && lng != 0;
    return Card(
      elevation: 0,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 7),
        leading: CircleAvatar(backgroundColor: accent.withOpacity(.10), child: Icon(icon, color: accent)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text('$status\n${hasLocation ? age(updatedAt) : 'Waiting for live location'}', maxLines: 2),
        isThreeLine: true,
        trailing: hasLocation
            ? IconButton(tooltip: 'Open live location', onPressed: () => openMap(lat, lng), icon: const Icon(Icons.open_in_new))
            : const Icon(Icons.location_searching, color: Colors.grey),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
    children: [
      Card(
        elevation: 0,
        color: accent.withOpacity(.08),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Row(children: [
            Icon(Icons.gps_fixed),
            SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Live Tracking', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              SizedBox(height: 4),
              Text('Monitor active rides and deliveries. Partner locations update in real time.'),
            ])),
          ]),
        ),
      ),
      const SizedBox(height: 14),
      const Text('Active rides', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
      const SizedBox(height: 8),
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('autoRideRequests').snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return Text('Could not load rides: ${snap.error}');
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs.where((d) {
            final s = (d.data()['status'] ?? '').toString().toLowerCase();
            return {'searching', 'accepted', 'started'}.contains(s);
          }).toList();
          if (docs.isEmpty) return const Card(child: ListTile(title: Text('No active rides.')));
          return Column(children: docs.map((d) {
            final x = d.data();
            return card(
              context: context,
              title: '#${(x['id'] ?? d.id).toString()}',
              subtitle: (x['driverName'] ?? x['customerName'] ?? 'Ride').toString(),
              status: (x['status'] ?? 'active').toString(),
              lat: n(x['driverLat']),
              lng: n(x['driverLng']),
              updatedAt: x['driverLocationUpdatedAt'],
              icon: Icons.two_wheeler,
            );
          }).toList());
        },
      ),
      const SizedBox(height: 18),
      const Text('Active deliveries', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
      const SizedBox(height: 8),
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('orders').snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return Text('Could not load deliveries: ${snap.error}');
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs.where((d) {
            final s = (d.data()['status'] ?? '').toString().toLowerCase();
            return {'assigned', 'picked up', 'out for delivery'}.contains(s);
          }).toList();
          if (docs.isEmpty) return const Card(child: ListTile(title: Text('No active deliveries.')));
          return Column(children: docs.map((d) {
            final x = d.data();
            return card(
              context: context,
              title: '#${(x['id'] ?? d.id).toString()}',
              subtitle: (x['carrierName'] ?? x['customerName'] ?? 'Delivery').toString(),
              status: (x['status'] ?? 'active').toString(),
              lat: n(x['carrierLat']),
              lng: n(x['carrierLng']),
              updatedAt: x['carrierLocationUpdatedAt'],
              icon: Icons.local_shipping,
            );
          }).toList());
        },
      ),
    ],
  );
}
