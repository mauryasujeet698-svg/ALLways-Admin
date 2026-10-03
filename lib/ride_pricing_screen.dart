import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class RidePricingScreen extends StatefulWidget {
  final User? user;
  const RidePricingScreen({super.key,this.user});

  @override
  State<RidePricingScreen> createState() => _RidePricingScreenState();
}

class _RidePricingScreenState extends State<RidePricingScreen> {
  final _bikeWithin = TextEditingController();
  final _bikeAbove = TextEditingController();
  final _autoWithin = TextEditingController();
  final _autoAbove = TextEditingController();
  final _carWithin = TextEditingController();
  final _carAbove = TextEditingController();

  bool loading = true;
  bool saving = false;
  bool enabled = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_bikeWithin,_bikeAbove,_autoWithin,_autoAbove,_carWithin,_carAbove]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('settings').doc('ridePricing').get();
      final d = snap.data() ?? {};
      final bike = d['bike'] is Map ? Map<String,dynamic>.from(d['bike']) : <String,dynamic>{};
      final auto = d['auto'] is Map ? Map<String,dynamic>.from(d['auto']) : <String,dynamic>{};
      final car = d['car'] is Map ? Map<String,dynamic>.from(d['car']) : <String,dynamic>{};

      _bikeWithin.text = (bike['within5Km'] ?? 30).toString();
      _bikeAbove.text = (bike['above5KmRate'] ?? 8).toString();
      _autoWithin.text = (auto['within5Km'] ?? 40).toString();
      _autoAbove.text = (auto['above5KmRate'] ?? 12).toString();
      _carWithin.text = (car['within5Km'] ?? 60).toString();
      _carAbove.text = (car['above5KmRate'] ?? 16).toString();
      enabled = d['enabled'] != false;
    } catch (_) {
      _bikeWithin.text = '30'; _bikeAbove.text = '8';
      _autoWithin.text = '40'; _autoAbove.text = '12';
      _carWithin.text = '60'; _carAbove.text = '16';
    }
    if (mounted) setState(() => loading = false);
  }

  double? _value(TextEditingController c) => double.tryParse(c.text.trim());

  Future<void> _save() async {
    final values = [
      _bikeWithin,_bikeAbove,_autoWithin,_autoAbove,_carWithin,_carAbove
    ].map(_value).toList();
    if (values.any((v) => v == null || v < 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid non-negative prices and rates.')),
      );
      return;
    }

    setState(() => saving = true);
    try {
      await FirebaseFirestore.instance.collection('settings').doc('ridePricing').set({
        'enabled': enabled,
        'distanceBreakKm': 5,
        'bike': {
          'within5Km': values[0],
          'above5KmRate': values[1],
        },
        'auto': {
          'within5Km': values[2],
          'above5KmRate': values[3],
        },
        'car': {
          'within5Km': values[4],
          'above5KmRate': values[5],
        },
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': widget.user?.uid,
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ride pricing saved successfully.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save ride pricing: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget _vehicleCard({
    required String title,
    required IconData icon,
    required TextEditingController within,
    required TextEditingController above,
  }) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              CircleAvatar(
                backgroundColor: const Color(0x1AC2185B),
                child: Icon(icon, color: const Color(0xFFC2185B)),
              ),
              const SizedBox(width: 12),
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            ]),
            const SizedBox(height: 14),
            TextField(
              controller: within,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Fixed fare • up to 5 km',
                prefixText: '₹ ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: above,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Rate • each km above 5 km',
                prefixText: '₹ ',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        Card(
          elevation: 0,
          color: const Color(0x0FC2185B),
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ride pricing', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                SizedBox(height: 6),
                Text(
                  'Set the fare used by ALLways when a customer requests a ride. '
                  'Up to 5 km uses the fixed fare. Above 5 km adds the configured rate '
                  'for every kilometre after the first 5 km.',
                  style: TextStyle(color: Colors.black54, height: 1.35),
                ),
              ],
            ),
          ),
        ),
        SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          title: const Text('Use Admin ride pricing', style: TextStyle(fontWeight: FontWeight.w800)),
          subtitle: const Text('Turn off to temporarily use the app fallback pricing.'),
          value: enabled,
          onChanged: (v) => setState(() => enabled = v),
        ),
        const SizedBox(height: 4),
        _vehicleCard(
          title: 'Bike',
          icon: Icons.two_wheeler,
          within: _bikeWithin,
          above: _bikeAbove,
        ),
        const SizedBox(height: 10),
        _vehicleCard(
          title: 'Auto',
          icon: Icons.local_taxi_outlined,
          within: _autoWithin,
          above: _autoAbove,
        ),
        const SizedBox(height: 10),
        _vehicleCard(
          title: 'Cab',
          icon: Icons.directions_car_outlined,
          within: _carWithin,
          above: _carAbove,
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: saving ? null : _save,
          icon: const Icon(Icons.save_outlined),
          label: Text(saving ? 'Saving…' : 'Save ride pricing'),
        ),
      ],
    );
  }
}
