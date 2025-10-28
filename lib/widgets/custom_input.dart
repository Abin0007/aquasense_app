import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomInput extends StatefulWidget {
  final String hintText;
  final IconData icon;
  final bool isPassword;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final TextInputType keyboardType;
  final Animation<double> glowAnimation;
  final bool readOnly;
  final VoidCallback? onTap;
  final int? maxLines; // <-- ADDED THIS LINE

  const CustomInput({
    super.key,
    required this.hintText,
    required this.icon,
    this.isPassword = false,
    required this.controller,
    this.validator,
    this.keyboardType = TextInputType.text,
    required this.glowAnimation,
    this.readOnly = false,
    this.onTap,
    this.maxLines = 1, // <-- ADDED THIS LINE (default to 1 line)
  });

  @override
  State<CustomInput> createState() => _CustomInputState();
}

class _CustomInputState extends State<CustomInput> {
  bool _obscureText = true;
  final FocusNode _focusNode = FocusNode();
  String? _errorText; // State to track the current error message

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.glowAnimation,
      builder: (context, child) {
        final bool shouldShowGlow = _focusNode.hasFocus && _errorText == null;

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            boxShadow: shouldShowGlow ? [
              BoxShadow(
                color: Color.fromRGBO(0, 255, 255, 0.3 + (widget.glowAnimation.value * 0.3)),
                blurRadius: 8.0 + (widget.glowAnimation.value * 5),
                spreadRadius: 2.0,
              )
            ] : [],
          ),
          child: child,
        );
      },
      child: TextFormField(
        focusNode: _focusNode,
        controller: widget.controller,
        obscureText: widget.isPassword ? _obscureText : false,
        keyboardType: widget.keyboardType,
        readOnly: widget.readOnly,
        onTap: widget.onTap,
        maxLines: widget.isPassword ? 1 : widget.maxLines, // <-- USE maxLines HERE (force 1 for password)
        inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'^\s*'))],
        style: const TextStyle(color: Colors.white),
        validator: (value) {
          final error = widget.validator?.call(value);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _errorText != error) {
              setState(() {
                _errorText = error;
              });
            }
          });
          return error;
        },
        decoration: InputDecoration(
          prefixIcon: Icon(widget.icon, color: Colors.white70),
          hintText: widget.hintText,
          hintStyle: const TextStyle(color: Colors.white70),
          filled: true,
          fillColor: const Color.fromRGBO(255, 255, 255, 0.2),
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: Color.fromRGBO(255, 255, 255, 0.3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: Colors.cyanAccent, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: Colors.redAccent, width: 2),
          ),
          errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 12),
          suffixIcon: widget.isPassword
              ? IconButton(
            icon: Icon(
              _obscureText ? Icons.visibility_off : Icons.visibility,
              color: Colors.white70,
            ),
            onPressed: () => setState(() => _obscureText = !_obscureText),
          )
              : null,
        ),
      ),
    );
  }
}