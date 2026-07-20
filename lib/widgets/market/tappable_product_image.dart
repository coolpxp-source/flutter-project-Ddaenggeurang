import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class TappableProductImage extends StatefulWidget {
  final String imageUrl;
  final VoidCallback? onTap;

  const TappableProductImage({
    super.key,
    required this.imageUrl,
    this.onTap,
  });

  @override
  State<TappableProductImage> createState() => _TappableProductImageState();
}

class _TappableProductImageState extends State<TappableProductImage> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: _isPressed ? 0.85 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              widget.imageUrl,
              fit: BoxFit.cover,
              width: double.infinity,
              height: 70,
              errorBuilder: (context, error, stackTrace) =>
                  Container(color: Colors.grey[200]),
            ),
          ),
        ),
      ),
    );
  }
}