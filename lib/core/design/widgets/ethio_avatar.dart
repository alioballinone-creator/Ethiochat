import 'package:flutter/material.dart';
import '../ethio_colors.dart';

/// Initials avatar with a stable warm tone per name. Pass [imageUrl] to show a photo.
class EthioAvatar extends StatelessWidget {
  const EthioAvatar({super.key, required this.name, this.imageUrl, this.size = 52, this.online = false});

  final String name;
  final String? imageUrl;
  final double size;
  final bool online;

  String get _initials {
    final p = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (p.isEmpty) return '?';
    if (p.length == 1) return p.first.characters.first.toUpperCase();
    return (p.first.characters.first + p.last.characters.first).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final tone = EthioColors.avatarTones[name.hashCode.abs() % EthioColors.avatarTones.length];
    final avatar = Container(
      width: size, height: size, alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [tone, tone.withValues(alpha: .8)]),
        image: imageUrl != null ? DecorationImage(image: NetworkImage(imageUrl!), fit: BoxFit.cover) : null,
      ),
      child: imageUrl == null
          ? Text(_initials, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: size * .34, fontFamily: 'Poppins'))
          : null,
    );
    if (!online) return avatar;
    return Stack(clipBehavior: Clip.none, children: [
      avatar,
      Positioned(
        right: 0, bottom: 0,
        child: Container(
          width: size * .26, height: size * .26,
          decoration: BoxDecoration(
            color: EthioColors.success, shape: BoxShape.circle,
            border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
          ),
        ),
      ),
    ]);
  }
}
