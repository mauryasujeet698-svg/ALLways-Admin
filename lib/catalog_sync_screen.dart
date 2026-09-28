import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class CatalogSyncScreen extends StatefulWidget {
  const CatalogSyncScreen({super.key});

  @override
  State<CatalogSyncScreen> createState() => _CatalogSyncScreenState();
}

class _CatalogSyncScreenState extends State<CatalogSyncScreen> {
  static const String _endpoint =
      'https://script.google.com/macros/s/AKfycbxnmGS7Q6t7pPWiT50V87JmA0Qbh2tSi1UKLFzN28dQpybjw7vvCufnryi-qpTnq0b0IA/exec';

  bool _busy = false;
  int _productCount = 0;
  int _inventoryCount = 0;
  String? _lastSyncText;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLastSync();
  }

  Future<void> _loadLastSync() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('settings')
          .doc('catalogSync')
          .get();
      final data = snap.data() ?? {};
      if (!mounted) return;

      final stamp = data['lastSyncAt'];
      setState(() {
        _productCount = _asInt(data['productCount']);
        _inventoryCount = _asInt(data['inventoryCount']);
        _lastSyncText = stamp is Timestamp
            ? stamp.toDate().toLocal().toString()
            : (stamp?.toString().trim().isEmpty ?? true)
                ? null
                : stamp.toString();
      });
    } catch (_) {}
  }

  Future<void> _syncCatalog() async {
    if (_busy) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final response = await http
          .get(
            Uri.parse(_endpoint),
            headers: const {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          'Catalog endpoint returned HTTP ${response.statusCode}.',
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Catalog endpoint returned an unexpected response.');
      }

      if (decoded['success'] != true) {
        throw Exception(
          (decoded['error'] ?? 'Catalog endpoint reported a failure.').toString(),
        );
      }

      final rawProducts = decoded['products'];
      if (rawProducts is! List) {
        throw Exception('Catalog response did not contain a products list.');
      }

      final records = <Map<String, dynamic>>[];
      final seenIds = <String>{};

      for (final raw in rawProducts) {
        if (raw is! Map) continue;

        final row = Map<String, dynamic>.from(raw);
        final name = _asString(row['Product Name']);
        if (name.isEmpty) continue;

        final id = _normaliseId(
          _asString(row['ID']),
          fallback: name,
        );
        if (!seenIds.add(id)) continue;

        final category = _asString(row['Category'], fallback: 'Other');
        final emoji = _asString(row['Emoji']);
        final price = _asNum(row['Price']);
        final stock = _asNum(row['Stock']);
        final available = _asBool(row['Available'], fallback: true);
        final maxQty = _asNum(row['Max Qty'], fallback: 10);
        final imageUrl = _asString(row['Image URL']);

        records.add({
          'id': id,
          'name': name,
          'title': name,
          'category': category,
          'emoji': emoji,
          'price': price,
          'stock': stock,
          'available': available,
          'maxQty': maxQty,
          'imageUrl': imageUrl,
          'catalogSource': 'google_sheets',
          'sourceSheet': 'Products',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      if (records.isEmpty) {
        throw Exception('No valid products were found in the Sheet response.');
      }

      final firestore = FirebaseFirestore.instance;

      // 2 writes per product, so stay safely under Firestore's batch limit.
      const maxRecordsPerBatch = 225;

      for (var start = 0; start < records.length; start += maxRecordsPerBatch) {
        final end = (start + maxRecordsPerBatch > records.length)
            ? records.length
            : start + maxRecordsPerBatch;

        final batch = firestore.batch();

        for (final product in records.sublist(start, end)) {
          final id = product['id'].toString();

          batch.set(
            firestore.collection('products').doc(id),
            product,
            SetOptions(merge: true),
          );

          batch.set(
            firestore.collection('inventory').doc(id),
            {
              'id': id,
              'productId': id,
              'name': product['name'],
              'category': product['category'],
              'stock': product['stock'],
              'available': product['available'],
              'maxQty': product['maxQty'],
              'imageUrl': product['imageUrl'],
              'catalogSource': 'google_sheets',
              'sourceSheet': 'Products',
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        }

        await batch.commit();
      }

      await firestore.collection('settings').doc('catalogSync').set(
        {
          'productCount': records.length,
          'inventoryCount': records.length,
          'source': 'Google Sheets',
          'sheet': 'Products',
          'endpoint': _endpoint,
          'lastSyncAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;

      setState(() {
        _productCount = records.length;
        _inventoryCount = records.length;
        _lastSyncText = DateTime.now().toLocal().toString();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Catalog synced: ${records.length} products and ${records.length} inventory records.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Catalog sync failed: $_error')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String _asString(dynamic value, {String fallback = ''}) {
    final result = value?.toString().trim() ?? '';
    return result.isEmpty ? fallback : result;
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString().trim() ?? '') ?? 0;
  }

  static num _asNum(dynamic value, {num fallback = 0}) {
    if (value is num) return value;
    final text = value?.toString().trim() ?? '';
    return num.tryParse(text.replaceAll(',', '')) ?? fallback;
  }

  static bool _asBool(dynamic value, {bool fallback = false}) {
    if (value is bool) return value;
    final text = value?.toString().trim().toLowerCase() ?? '';

    if (['yes', 'true', '1', 'available'].contains(text)) return true;
    if (['no', 'false', '0', 'unavailable'].contains(text)) return false;

    return fallback;
  }

  static String _normaliseId(
    String value, {
    required String fallback,
  }) {
    final source = value.isEmpty ? fallback : value;
    final cleaned = source
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9_-]+'), '_');

    if (cleaned.isEmpty) {
      return 'allways_${DateTime.now().microsecondsSinceEpoch}';
    }

    return cleaned.length > 100 ? cleaned.substring(0, 100) : cleaned;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Catalog Sync')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          Card(
            elevation: 0,
            color: Theme.of(context).colorScheme.primary.withOpacity(.07),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor:
                        Theme.of(context).colorScheme.primary.withOpacity(.13),
                    child: Icon(
                      Icons.sync,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 13),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Google Sheets Catalog',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Import Products into Firestore and keep inventory in sync.',
                          style: TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _metric(
                  _productCount.toString(),
                  'Products',
                  Icons.inventory_2,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _metric(
                  _inventoryCount.toString(),
                  'Inventory',
                  Icons.fact_check,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            child: ListTile(
              leading: const Icon(Icons.table_chart_outlined),
              title: const Text(
                'Source',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: const Text('Google Sheet • Products • /exec API'),
            ),
          ),
          if (_lastSyncText != null)
            Card(
              elevation: 0,
              child: ListTile(
                leading: const Icon(Icons.schedule),
                title: const Text(
                  'Last sync',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(_lastSyncText!),
              ),
            ),
          if (_error != null)
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              onPressed: _busy ? null : _syncCatalog,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync),
              label: Text(
                _busy ? 'Syncing…' : 'Sync Products & Inventory',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metric(String value, String label, IconData icon) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
            const SizedBox(height: 7),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10.5,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
