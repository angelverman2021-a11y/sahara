import 'package:flutter/material.dart';
import '../models/message.dart';
import '../services/service_scope.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_title.dart';

class BroadcastScreen extends StatefulWidget {
  const BroadcastScreen({super.key});

  @override
  State<BroadcastScreen> createState() => _BroadcastScreenState();
}

class _BroadcastScreenState extends State<BroadcastScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _isSent = false;
  String _lastBroadcastedMessage = '';

  final List<String> _suggestions = const [
    'Road blocked near Gate 2.',
    'Safe shelter available.',
    'Do not use this route.',
    'Drinking water point active at Relief Tent 3.',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleBroadcast(dynamic service) {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an emergency broadcast message.'),
        ),
      );
      return;
    }

    service.sendBroadcast(content: text);
    setState(() {
      _lastBroadcastedMessage = text;
      _isSent = true;
      _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final service = EmergencyServiceScope.of(context);
    final recentBroadcasts = service.recentBroadcasts;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(_isSent ? 'Broadcast Relayed' : 'Emergency Broadcast'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: _isSent
              ? _buildSentConfirmationView(context)
              : _buildComposeView(context, service, recentBroadcasts),
        ),
      ),
    );
  }

  Widget _buildComposeView(
    BuildContext context,
    dynamic service,
    List<Message> recentBroadcasts,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Emergency Broadcast',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),
        Text.rich(
          TextSpan(
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
            children: [
              const TextSpan(
                text: 'Propagated to all reachable peer devices in the ',
              ),
              buildBrandSpan(
                context: context,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
              const TextSpan(
                text: ' mesh.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Quick suggestions
        const Text(
          'QUICK SUGGESTIONS (TAP TO INSERT)',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: AppTheme.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _suggestions.map((template) {
            return ActionChip(
              label: Text(
                template,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 12.5,
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              backgroundColor: AppTheme.surfaceSubtle,
              side: const BorderSide(color: AppTheme.surfaceBorder),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius),
              ),
              onPressed: () {
                _controller.text = template;
                _controller.selection = TextSelection.fromPosition(
                  TextPosition(offset: _controller.text.length),
                );
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 18),

        // Text input field
        const Text(
          'BROADCAST MESSAGE',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: AppTheme.textMuted,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _controller,
          maxLines: 4,
          minLines: 3,
          textCapitalization: TextCapitalization.sentences,
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 14.5,
            color: AppTheme.textPrimary,
          ),
          decoration: const InputDecoration(
            hintText: 'Enter emergency message...',
          ),
        ),
        const SizedBox(height: 20),

        // Prominent Broadcast Message Button
        ElevatedButton.icon(
          onPressed: () => _handleBroadcast(service),
          icon: const Icon(Icons.campaign_rounded, size: 20),
          label: const Text(
            'BROADCAST MESSAGE',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.textPrimary, // Clean navy
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),

        const SizedBox(height: 28),

        // Recent Broadcasts
        if (recentBroadcasts.isNotEmpty) ...[
          const Text(
            'RECENT MESH BROADCASTS',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 10),
          ...recentBroadcasts.map((b) => _buildRecentBroadcastCard(b)),
        ],
      ],
    );
  }

  Widget _buildSentConfirmationView(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Sent Banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.activeGreenLight,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(color: AppTheme.activeGreenBorder),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: AppTheme.activeGreen,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'BROADCAST SENT',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.activeGreen,
                      ),
                    ),
                    Text.rich(
                      TextSpan(
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 12.5,
                          color: AppTheme.textSecondary,
                        ),
                        children: [
                          const TextSpan(
                            text: 'Relaying through the ',
                          ),
                          buildBrandSpan(
                            context: context,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                          const TextSpan(
                            text: ' network.',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Stats Box
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(color: AppTheme.surfaceBorder),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('Recipients reached', '8', Icons.group_outlined),
              Container(width: 1, height: 40, color: AppTheme.surfaceBorder),
              _buildStatItem('Relays', '4', Icons.hub_outlined),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Message Content Box
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surfaceSubtle,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(color: AppTheme.surfaceBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'MESSAGE CONTENT',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AppTheme.textMuted,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '"$_lastBroadcastedMessage"',
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Buttons
        OutlinedButton(
          onPressed: () {
            setState(() {
              _isSent = false;
            });
          },
          child: const Text('Compose Another Broadcast'),
        ),
        const SizedBox(height: 10),

        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Return to Home'),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.textSecondary, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 12,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentBroadcastCard(Message message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                message.senderName,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                message.timeFormatted,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 11,
                  color: AppTheme.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            message.content,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 13,
              color: AppTheme.textSecondary,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
