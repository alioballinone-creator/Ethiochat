import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../ethio_colors.dart';
import '../ethio_spacing.dart';

/// Text field with the gold focus ring from the mockups.
class EthioTextField extends StatefulWidget {
  const EthioTextField({
    super.key,
    this.controller,
    this.hint,
    this.errorText,
    this.prefix,
    this.suffix,
    this.keyboardType,
    this.inputFormatters,
    this.onChanged,
    this.textStyle,
    this.obscureText = false,
    this.autofocus = false,
    this.maxLength,
  });

  final TextEditingController? controller;
  final String? hint, errorText;
  final Widget? prefix, suffix;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final TextStyle? textStyle;
  final bool obscureText, autofocus;
  final int? maxLength;

  @override
  State<EthioTextField> createState() => _EthioTextFieldState();
}

class _EthioTextFieldState extends State<EthioTextField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);
    final focused = _focus.hasFocus && widget.errorText == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: Dur.fast,
          decoration: BoxDecoration(
            borderRadius: Rad.r14,
            boxShadow: focused
                ? [BoxShadow(color: pal.ring, spreadRadius: 4)]
                : const [],
          ),
          child: TextField(
            focusNode: _focus,
            controller: widget.controller,
            autofocus: widget.autofocus,
            keyboardType: widget.keyboardType,
            inputFormatters: widget.inputFormatters,
            onChanged: widget.onChanged,
            obscureText: widget.obscureText,
            maxLength: widget.maxLength,
            style: widget.textStyle ?? Theme.of(context).textTheme.bodyLarge,
            cursorColor: EthioColors.gold,
            decoration: InputDecoration(
              hintText: widget.hint,
              prefixIcon: widget.prefix,
              suffixIcon: widget.suffix,
              counterText: '',
              enabledBorder: widget.errorText != null
                  ? OutlineInputBorder(
                      borderRadius: Rad.r14,
                      borderSide: const BorderSide(
                          color: EthioColors.danger, width: 1.5))
                  : null,
            ),
          ),
        ),
        if (widget.errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(widget.errorText!,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall!
                    .copyWith(color: EthioColors.danger)),
          ),
      ],
    );
  }
}
