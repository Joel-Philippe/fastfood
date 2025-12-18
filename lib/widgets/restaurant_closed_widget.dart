import 'dart:async';
import 'package:flutter/material.dart';

class RestaurantClosedWidget extends StatefulWidget {
  final Duration timeUntilOpening;

  const RestaurantClosedWidget({super.key, required this.timeUntilOpening});

  @override
  State<RestaurantClosedWidget> createState() => _RestaurantClosedWidgetState();
}

class _RestaurantClosedWidgetState extends State<RestaurantClosedWidget> {
  late Timer _timer;
  late Duration _remainingTime;

  @override
  void initState() {
    super.initState();
    _remainingTime = widget.timeUntilOpening;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingTime.inSeconds > 0) {
          _remainingTime = _remainingTime - const Duration(seconds: 1);
        } else {
          _timer.cancel();
          // Optionally, you could add a callback to refresh the parent page
        }
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.door_back_door_outlined, size: 80, color: Colors.grey),
            const SizedBox(height: 24),
            Text(
              'Le restaurant est actuellement fermé',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              'Prochaine ouverture dans :',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _formatDuration(_remainingTime),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
