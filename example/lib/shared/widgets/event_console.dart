import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_ble_connection_manager/flutter_ble_connection_manager.dart';
import '../theme/app_design.dart';

class EventConsole extends StatefulWidget {
  final Stream<BleLifecycleEvent> events;

  const EventConsole({super.key, required this.events});

  @override
  State<EventConsole> createState() => _EventConsoleState();
}

class _EventConsoleState extends State<EventConsole> {
  final List<_EventLog> _logs = [];
  final ScrollController _scrollController = ScrollController();
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(covariant EventConsole oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.events != widget.events) {
      _subscribe();
    }
  }

  void _subscribe() {
    _subscription?.cancel();
    _subscription = widget.events.listen((event) {
      if (!mounted) return;
      setState(() {
        _logs.add(_EventLog(event: event, timestamp: DateTime.now()));
        if (_logs.length > 200) {
          _logs.removeAt(0);
        }
      });
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
  }

  String _formatEventName(BleLifecycleEvent event) {
    // Extract the class name of the event
    final typeName = event.runtimeType.toString();
    // Return something like "ConnectionAttemptStarted"
    return typeName;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.consoleBackground,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.all(AppDimensions.spacingMedium - 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'EVENT CONSOLE',
            style: TextStyle(
              color: AppColors.success,
              fontWeight: FontWeight.bold,
              fontSize: AppDimensions.fontSmall,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingSmall),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _logs.length,
              itemBuilder: (context, index) {
                final log = _logs[index];
                return Padding(
                  padding: const EdgeInsets.only(
                    bottom: AppDimensions.spacingSmall,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '[${_formatTime(log.timestamp)}]',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontFamily: 'monospace',
                          fontSize: AppDimensions.fontSmall,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatEventName(log.event),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontFamily: 'monospace',
                          fontSize: AppDimensions.fontMedium,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '──────────────',
                        style: TextStyle(
                          color: AppColors.borderHighlight,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EventLog {
  final BleLifecycleEvent event;
  final DateTime timestamp;

  _EventLog({required this.event, required this.timestamp});
}
