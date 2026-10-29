import 'package:flutter/material.dart';
import '../ethio_colors.dart';

/// Mirrors the `status` lifecycle of the outbox pipeline (master prompt 4.2).
enum MessageStatus { sending, sent, delivered, read, failed }

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.isMine,
    required this.time,
    this.text,
    this.child,
    this.status = MessageStatus.sent,
    this.firstInGroup = true,
    this.header,
    this.onRetry,
    this.onLongPress,
    this.edited = false,
  }) : assert(text != null || child != null);

  final bool isMine, firstInGroup;
  final String? text;
  final Widget? child; // voice note, payment card, image, etc.
  final String time;
  final MessageStatus status;
  final Widget? header;
  final VoidCallback? onRetry;
  final VoidCallback? onLongPress;
  final bool edited;

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);
    final textColor =
        isMine ? pal.bubbleSentText : Theme.of(context).colorScheme.onSurface;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(isMine ? 18 : (firstInGroup ? 6 : 18)),
      bottomRight: Radius.circular(isMine ? (firstInGroup ? 6 : 18) : 18),
    );
    final meta = Row(mainAxisSize: MainAxisSize.min, children: [
      if (edited) ...[
        Text('Edited',
            style: TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: isMine
                    ? textColor.withValues(alpha: .75)
                    : pal.textTertiary,
                fontFamily: 'Poppins')),
        const SizedBox(width: 5),
      ],
      Text(time,
          style: TextStyle(
              fontSize: 11,
              color:
                  isMine ? textColor.withValues(alpha: .75) : pal.textTertiary,
              fontFamily: 'Poppins')),
      if (isMine) ...[
        const SizedBox(width: 5),
        _AnimatedStatusIcon(status: status, pal: pal)
      ],
    ]);

    final bubble = Container(
      constraints:
          BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .78),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 7),
      decoration: BoxDecoration(
        gradient: isMine ? pal.bubbleSent : null,
        color: isMine ? null : pal.bubbleReceived,
        border: isMine ? null : Border.all(color: pal.line),
        borderRadius: radius,
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (header != null) ...[
              header!,
              const SizedBox(height: 6),
            ],
            if (text != null)
              Align(
                  alignment: Alignment.centerLeft,
                  child: Text(text!,
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge!
                          .copyWith(color: textColor)))
            else
              DefaultTextStyle.merge(
                  style: TextStyle(color: textColor), child: child!),
            const SizedBox(height: 2),
            meta,
          ]),
    );

    return Padding(
      padding: EdgeInsets.only(top: firstInGroup ? 6 : 2, bottom: 2),
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
            onTap: status == MessageStatus.failed ? onRetry : null,
            onLongPress: onLongPress,
            child: bubble),
      ),
    );
  }
}

class _AnimatedStatusIcon extends StatelessWidget {
  const _AnimatedStatusIcon({required this.status, required this.pal});

  final MessageStatus status;
  final EthioPalette pal;

  @override
  Widget build(BuildContext context) {
    final icon = _StatusIcon(status: status, pal: pal);
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final statusIcon = reduceMotion
        ? icon
        : AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: KeyedSubtree(key: ValueKey(status), child: icon),
          );
    final isAmharic = Localizations.localeOf(context).languageCode == 'am';
    final label = switch (status) {
      MessageStatus.sending => isAmharic ? 'በመላክ ላይ' : 'Sending',
      MessageStatus.sent => isAmharic ? 'ተልኳል' : 'Sent',
      MessageStatus.delivered => isAmharic ? 'ደርሷል' : 'Delivered',
      MessageStatus.read => isAmharic ? 'ተነቧል' : 'Read',
      MessageStatus.failed =>
        isAmharic ? 'አልተላከም፤ ለመድገም ይንኩ' : 'Failed — tap to retry',
    };
    return Tooltip(
      message: label,
      child: statusIcon,
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status, required this.pal});
  final MessageStatus status;
  final EthioPalette pal;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case MessageStatus.sending:
        return Icon(Icons.schedule_rounded,
            size: 13, color: pal.bubbleSentText.withValues(alpha: .7));
      case MessageStatus.failed:
        return const Icon(Icons.error_rounded,
            size: 15, color: EthioColors.danger);
      case MessageStatus.sent:
        return CustomPaint(
            size: const Size(12, 9),
            painter:
                _Ticks(pal.tickSent.withValues(alpha: .6), isDouble: false));
      case MessageStatus.delivered:
        return CustomPaint(
            size: const Size(16, 10),
            painter: _Ticks(pal.bubbleSentText.withValues(alpha: .6),
                isDouble: true));
      case MessageStatus.read:
        return CustomPaint(
            size: const Size(16, 10),
            painter: _Ticks(pal.tickRead, isDouble: true));
    }
  }
}

class _Ticks extends CustomPainter {
  _Ticks(this.color, {required this.isDouble});
  final Color color;
  final bool isDouble;
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final a = Path()
      ..moveTo(s.width * .06, s.height * .55)
      ..lineTo(s.width * .26, s.height * .85)
      ..lineTo(s.width * .66, s.height * .12);
    c.drawPath(a, p);
    if (isDouble) {
      final b = Path()
        ..moveTo(s.width * .42, s.height * .8)
        ..lineTo(s.width * .46, s.height * .88)
        ..lineTo(s.width * .94, s.height * .12);
      c.drawPath(b, p);
    }
  }

  @override
  bool shouldRepaint(_Ticks o) => o.color != color || o.isDouble != isDouble;
}
