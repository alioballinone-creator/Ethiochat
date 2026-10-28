import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../ethio_colors.dart';

/// Logo mark from assets/brand/logo-mark.svg (add `flutter_svg` to pubspec).
class EthioMark extends StatelessWidget {
  const EthioMark({super.key, this.size = 96});
  final double size;
  @override
  Widget build(BuildContext context) =>
      SvgPicture.asset('assets/brand/logo-mark.svg',
          width: size, height: size, semanticsLabel: 'EthioChat');
}

/// "Ethio" in the text colour + "Chat" in shiny gold.
class EthioWordmark extends StatelessWidget {
  const EthioWordmark({super.key, this.size = 38});
  final double size;
  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
        fontFamily: 'Poppins', fontSize: size, letterSpacing: -size * .02);
    return Text.rich(TextSpan(children: [
      TextSpan(
          text: 'Ethio',
          style: base.copyWith(
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface)),
      WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: ShaderMask(
          shaderCallback: (r) => const LinearGradient(
              colors: [EthioColors.gold, EthioColors.goldDeep]).createShader(r),
          child: Text('Chat',
              style: base.copyWith(
                  fontWeight: FontWeight.w700, color: Colors.white)),
        ),
      ),
    ]));
  }
}
