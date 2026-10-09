import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Analytics uses one document per order/ride and explicitly separates delivery
/// and ride counts. Dates are interpreted as India calendar dates (UTC+05:30).
class AdminAnalyticsScreen extends StatefulWidget {
  final Color accent;
  const AdminAnalyticsScreen({super.key, required this.accent});

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

enum _Period { today, last7Days, month, year, custom }

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  _Period _period = _Period.last7Days;
  DateTime? _customStart;
  DateTime? _customEnd;

  static const Duration _indiaOffset = Duration(hours: 5, minutes: 30);
  static const Set<String> _completedDelivery = {'delivered', 'completed'};
  static const Set<String> _cancelled = {'cancelled', 'canceled'};
  static const Set<String> _rejectedExpired = {'rejected', 'expired', 'failed'};
  static const Set<String> _activeRide = {'searching', 'accepted', 'arrived', 'started'};
  static const Set<String> _activeDelivery = {
    'pending', 'new order', 'searching', 'ready', 'pending_acceptance',
    'assigned', 'picked up', 'out for delivery', 'arrived', 'preparing'
  };

  DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is num) {
      final v = value.toInt();
      return DateTime.fromMillisecondsSinceEpoch(v < 100000000000 ? v * 1000 : v);
    }
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  DateTime? _firstDate(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = _date(data[key]);
      if (value != null) return value;
    }
    return null;
  }

  String _status(Map<String, dynamic> data) =>
      (data['status'] ?? '').toString().trim().toLowerCase();

  String _customerId(Map<String, dynamic> data) =>
      (data['customerId'] ?? data['customerUid'] ?? data['uid'] ??
              data['userId'] ?? '')
          .toString()
          .trim();

  String _partnerId(Map<String, dynamic> data) =>
      (data['carrierUid'] ?? data['deliveryPartnerUid'] ??
              data['deliveryPartnerId'] ?? data['assignedPartnerId'] ??
              data['driverUid'] ?? '')
          .toString()
          .trim();

  DateTime _indiaToday() {
    final indiaNow = DateTime.now().toUtc().add(_indiaOffset);
    return DateTime.utc(indiaNow.year, indiaNow.month, indiaNow.day);
  }

  ({DateTime start, DateTime end}) _bounds() {
    final today = _indiaToday();
    switch (_period) {
      case _Period.today:
        return (start: today, end: today.add(const Duration(days: 1)));
      case _Period.last7Days:
        return (start: today.subtract(const Duration(days: 6)), end: today.add(const Duration(days: 1)));
      case _Period.month:
        return (start: DateTime.utc(today.year, today.month), end: DateTime.utc(today.year, today.month + 1));
      case _Period.year:
        return (start: DateTime.utc(today.year), end: DateTime.utc(today.year + 1));
      case _Period.custom:
        final start = _customStart == null
            ? today.subtract(const Duration(days: 6))
            : DateTime.utc(_customStart!.year, _customStart!.month, _customStart!.day);
        final endDay = _customEnd == null
            ? today
            : DateTime.utc(_customEnd!.year, _customEnd!.month, _customEnd!.day);
        return (start: start, end: endDay.add(const Duration(days: 1)));
    }
  }

  /// Convert an instant into an India wall-clock date (represented as UTC) so
  /// date-only boundaries are independent of the handset's configured zone.
  DateTime? _indiaWallDate(DateTime? instant) {
    if (instant == null) return null;
    final shifted = instant.toUtc().add(_indiaOffset);
    return DateTime.utc(shifted.year, shifted.month, shifted.day);
  }

  bool _within(DateTime? instant, ({DateTime start, DateTime end}) bounds) {
    final wall = _indiaWallDate(instant);
    return wall != null && !wall.isBefore(bounds.start) && wall.isBefore(bounds.end);
  }

  DateTime? _eventDate(Map<String, dynamic> data, List<String> eventKeys) =>
      _firstDate(data, [...eventKeys, 'createdAt', 'requestedAt', 'createdOn', 'timestamp']);

  ({DateTime start, DateTime end}) _previousBounds(({DateTime start, DateTime end}) current) {
    switch (_period) {
      case _Period.today:
        return (start: current.start.subtract(const Duration(days: 1)), end: current.start);
      case _Period.last7Days:
        return (start: current.start.subtract(const Duration(days: 7)), end: current.start);
      case _Period.month:
        final previousStart = DateTime.utc(current.start.year, current.start.month - 1);
        return (start: previousStart, end: current.start);
      case _Period.year:
        final previousStart = DateTime.utc(current.start.year - 1);
        return (start: previousStart, end: current.start);
      case _Period.custom:
        final duration = current.end.difference(current.start);
        return (start: current.start.subtract(duration), end: current.start);
    }
  }

  String _changeLabel(int current, int previous) {
    if (previous == 0) return current == 0 ? 'No change vs previous period' : 'New activity (previous period: 0)';
    final change = ((current - previous) * 100 / previous);
    final prefix = change > 0 ? '+' : '';
    return '${prefix}${change.toStringAsFixed(1)}% vs previous period';
  }

  Future<void> _chooseCustomRange() async {
    final today = _indiaToday();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(today.year + 1, 12, 31),
      initialDateRange: DateTimeRange(
        start: _customStart ?? today.subtract(const Duration(days: 6)),
        end: _customEnd ?? today,
      ),
      helpText: 'Choose India calendar dates',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _period = _Period.custom;
      _customStart = picked.start;
      _customEnd = picked.end;
    });
  }

  String get _periodLabel => switch (_period) {
        _Period.today => 'Today',
        _Period.last7Days => 'Last 7 days',
        _Period.month => 'This calendar month',
        _Period.year => 'This calendar year',
        _Period.custom => 'Custom range',
      };

  Widget _metric(String value, String label, IconData icon) => Expanded(
        child: Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, color: widget.accent),
              const SizedBox(height: 6),
              Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ]),
          ),
        ),
      );

  Widget _metricRow(List<(String, String, IconData)> items) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            _metric(items[i].$1, items[i].$2, items[i].$3),
          ],
        ],
      );

  @override
  Widget build(BuildContext context) {
    final bounds = _bounds();
    return Scaffold(
      appBar: AppBar(title: const Text('Reports & Analytics')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('orders').snapshots(),
        builder: (context, ordersSnap) {
          if (ordersSnap.hasError) return _error('orders', ordersSnap.error);
          if (!ordersSnap.hasData) return const Center(child: CircularProgressIndicator());
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('autoRideRequests').snapshots(),
            builder: (context, ridesSnap) {
              if (ridesSnap.hasError) return _error('rides', ridesSnap.error);
              if (!ridesSnap.hasData) return const Center(child: CircularProgressIndicator());
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance.collection('customers').snapshots(),
                builder: (context, customersSnap) {
                  if (customersSnap.hasError) return _error('customers', customersSnap.error);
                  if (!customersSnap.hasData) return const Center(child: CircularProgressIndicator());

                  final orderDocs = ordersSnap.data!.docs;
                  final rideDocs = ridesSnap.data!.docs;
                  final customerDocs = customersSnap.data!.docs;
                  final periodOrders = orderDocs.where((d) => _within(
                    _eventDate(d.data(), const ['createdAt', 'createdOn', 'orderDate']),
                    bounds,
                  )).toList();
                  final periodRides = rideDocs.where((d) => _within(
                    _eventDate(d.data(), const ['requestedAt', 'createdAt', 'createdOn']),
                    bounds,
                  )).toList();
                  final newCustomers = customerDocs.where((d) => _within(
                    _firstDate(d.data(), const ['createdAt', 'registeredAt', 'registrationDate', 'createdOn']),
                    bounds,
                  )).length;

                  // Completion/cancellation metrics use their event timestamps, not
                  // transaction creation time. Legacy records fall back to creation time.
                  final completedOrders = orderDocs.where((d) =>
                    _completedDelivery.contains(_status(d.data())) &&
                    _within(_eventDate(d.data(), const ['deliveredAt', 'completedAt']), bounds)
                  ).toList();
                  final cancelledOrders = orderDocs.where((d) =>
                    _cancelled.contains(_status(d.data())) &&
                    _within(_eventDate(d.data(), const ['cancelledAt', 'updatedAt']), bounds)
                  ).length;
                  final completedRides = rideDocs.where((d) =>
                    _status(d.data()) == 'completed' &&
                    _within(_eventDate(d.data(), const ['completedAt']), bounds)
                  ).toList();
                  final cancelledRides = rideDocs.where((d) =>
                    _cancelled.contains(_status(d.data())) &&
                    _within(_eventDate(d.data(), const ['cancelledAt', 'updatedAt']), bounds)
                  ).length;
                  final activeOrders = periodOrders.where((d) => _activeDelivery.contains(_status(d.data()))).toList();
                  final activeRides = periodRides.where((d) => _activeRide.contains(_status(d.data()))).toList();
                  final unassignedOrders = activeOrders.where((d) => _partnerId(d.data()).isEmpty).length;
                  final unassignedRides = activeRides.where((d) => _partnerId(d.data()).isEmpty).length;

                  final orderCounts = <String, int>{};
                  for (final d in completedOrders) {
                    final id = _customerId(d.data());
                    if (id.isNotEmpty) orderCounts[id] = (orderCounts[id] ?? 0) + 1;
                  }
                  final rideCounts = <String, int>{};
                  for (final d in completedRides) {
                    final id = _customerId(d.data());
                    if (id.isNotEmpty) rideCounts[id] = (rideCounts[id] ?? 0) + 1;
                  }
                  final repeatOrders = orderCounts.values.where((v) => v >= 2).length;
                  final repeatRides = rideCounts.values.where((v) => v >= 2).length;
                  final combinedCounts = <String, int>{};
                  for (final entry in orderCounts.entries) {
                    combinedCounts[entry.key] = (combinedCounts[entry.key] ?? 0) + entry.value;
                  }
                  for (final entry in rideCounts.entries) {
                    combinedCounts[entry.key] = (combinedCounts[entry.key] ?? 0) + entry.value;
                  }
                  final repeatCombined = combinedCounts.values.where((v) => v >= 2).length;
                  final orderOutcomeCount = orderDocs.where((d) {
                    final status = _status(d.data());
                    final isTerminal = _completedDelivery.contains(status) || _cancelled.contains(status) || _rejectedExpired.contains(status);
                    if (!isTerminal) return false;
                    final keys = _completedDelivery.contains(status)
                        ? const ['deliveredAt', 'completedAt']
                        : _cancelled.contains(status)
                            ? const ['cancelledAt', 'updatedAt']
                            : const ['rejectedAt', 'expiredAt', 'updatedAt'];
                    return _within(_eventDate(d.data(), keys), bounds);
                  }).length;
                  final rideOutcomeCount = rideDocs.where((d) {
                    final status = _status(d.data());
                    final isTerminal = status == 'completed' || _cancelled.contains(status) || _rejectedExpired.contains(status);
                    if (!isTerminal) return false;
                    final keys = status == 'completed'
                        ? const ['completedAt']
                        : _cancelled.contains(status)
                            ? const ['cancelledAt', 'updatedAt']
                            : const ['rejectedAt', 'expiredAt', 'updatedAt'];
                    return _within(_eventDate(d.data(), keys), bounds);
                  }).length;
                  final completedOrderRate = orderOutcomeCount == 0 ? 0.0 : completedOrders.length * 100 / orderOutcomeCount;
                  final cancelledOrderRate = orderOutcomeCount == 0 ? 0.0 : cancelledOrders * 100 / orderOutcomeCount;
                  final completedRideRate = rideOutcomeCount == 0 ? 0.0 : completedRides.length * 100 / rideOutcomeCount;
                  final cancelledRideRate = rideOutcomeCount == 0 ? 0.0 : cancelledRides * 100 / rideOutcomeCount;
                  final previous = _previousBounds(bounds);
                  final previousOrders = orderDocs.where((d) => _within(_eventDate(d.data(), const ['createdAt', 'createdOn', 'orderDate']), previous)).length;
                  final previousRides = rideDocs.where((d) => _within(_eventDate(d.data(), const ['requestedAt', 'createdAt', 'createdOn']), previous)).length;
                  final previousCompletedOrders = orderDocs.where((d) => _completedDelivery.contains(_status(d.data())) && _within(_eventDate(d.data(), const ['deliveredAt', 'completedAt']), previous)).length;
                  final previousCompletedRides = rideDocs.where((d) => _status(d.data()) == 'completed' && _within(_eventDate(d.data(), const ['completedAt']), previous)).length;
                  final previousNewCustomers = customerDocs.where((d) => _within(_firstDate(d.data(), const ['createdAt', 'registeredAt', 'registrationDate', 'createdOn']), previous)).length;

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const Text('Analysis', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      const Text('One Firestore document counts as one transaction. Completed means delivered/completed for deliveries and completed for rides. Repeat customers have at least two completed transactions within the selected period. India time (UTC+05:30) is used for calendar boundaries.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      const SizedBox(height: 12),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        _filterButton('Today', _Period.today),
                        _filterButton('Last 7 days', _Period.last7Days),
                        _filterButton('This month', _Period.month),
                        _filterButton('This year', _Period.year),
                        OutlinedButton.icon(
                          onPressed: _chooseCustomRange,
                          icon: const Icon(Icons.date_range),
                          label: Text(_period == _Period.custom && _customStart != null && _customEnd != null
                              ? '${_customStart!.day}/${_customStart!.month}/${_customStart!.year} – ${_customEnd!.day}/${_customEnd!.month}/${_customEnd!.year}'
                              : 'Custom range'),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      Text('Showing: $_periodLabel', style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      _section('Deliveries'),
                      _metricRow([
                        (periodOrders.length.toString(), 'Total orders', Icons.receipt_long),
                        (completedOrders.length.toString(), 'Completed deliveries', Icons.check_circle),
                      ]),
                      _metricRow([
                        (cancelledOrders.toString(), 'Cancelled orders', Icons.cancel_outlined),
                        (activeOrders.length.toString(), 'Active deliveries', Icons.local_shipping),
                      ]),
                      _metricRow([
                        (unassignedOrders.toString(), 'Unassigned deliveries', Icons.assignment_late_outlined),
                        ('${completedOrderRate.toStringAsFixed(1)}%', 'Completion rate', Icons.task_alt),
                      ]),
                      _metricRow([
                        ('${cancelledOrderRate.toStringAsFixed(1)}%', 'Cancellation rate', Icons.block),
                        (repeatOrders.toString(), 'Repeat delivery customers', Icons.repeat),
                      ]),
                      const SizedBox(height: 10),
                      _section('Rides'),
                      _metricRow([
                        (periodRides.length.toString(), 'Total rides', Icons.two_wheeler),
                        (completedRides.length.toString(), 'Completed rides', Icons.check_circle),
                      ]),
                      _metricRow([
                        (cancelledRides.toString(), 'Cancelled rides', Icons.cancel_outlined),
                        (activeRides.length.toString(), 'Active rides', Icons.route),
                      ]),
                      _metricRow([
                        (unassignedRides.toString(), 'Unassigned rides', Icons.person_search),
                        ('${completedRideRate.toStringAsFixed(1)}%', 'Completion rate', Icons.task_alt),
                      ]),
                      _metricRow([
                        ('${cancelledRideRate.toStringAsFixed(1)}%', 'Cancellation rate', Icons.block),
                        (repeatRides.toString(), 'Repeat ride customers', Icons.repeat),
                      ]),
                      const SizedBox(height: 10),
                      _section('Customers'),
                      _metricRow([
                        (newCustomers.toString(), 'New customers', Icons.person_add_alt_1),
                        (repeatCombined.toString(), 'Repeat customers (combined)', Icons.groups),
                      ]),
                      const SizedBox(height: 12),
                      Card(child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('Compared with previous equivalent period', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                          const SizedBox(height: 8),
                          Text('Orders created: ${_changeLabel(periodOrders.length, previousOrders)}'),
                          Text('Completed deliveries: ${_changeLabel(completedOrders.length, previousCompletedOrders)}'),
                          Text('Rides created: ${_changeLabel(periodRides.length, previousRides)}'),
                          Text('Completed rides: ${_changeLabel(completedRides.length, previousCompletedRides)}'),
                          Text('New customers: ${_changeLabel(newCustomers, previousNewCustomers)}'),
                        ]),
                      )),
                      const SizedBox(height: 12),
                      Card(child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('Data quality notes', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                          const SizedBox(height: 6),
                          Text('Excluded from completed counts: cancelled, rejected, expired and incomplete jobs. Unassigned jobs are active records without a recognised partner ID. Active counts reflect current status for jobs created in the selected period. Customer records without a readable creation date are not counted as new in this period.'),
                          const SizedBox(height: 8),
                          Text('Completed delivery transactions in range: ${completedOrders.length} • completed ride transactions in range: ${completedRides.length}'),
                        ]),
                      )),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _filterButton(String label, _Period period) => ChoiceChip(
        label: Text(label),
        selected: _period == period,
        onSelected: (_) => setState(() => _period = period),
      );

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 4),
        child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
      );

  Widget _error(String name, Object? error) => Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text('Could not load $name analytics. Check connectivity and Admin access.\n$error', textAlign: TextAlign.center),
        ),
      );
}
