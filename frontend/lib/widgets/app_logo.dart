import 'package:flutter/material.dart';

/// Renders the official Sahara logo asset
class AppLogo extends StatelessWidget {
  final double? width;
  final double? height;
  final BoxFit fit;

  const AppLogo({
    super.key,
    this.width,
    this.height = 40.0,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/sahara_logo.png',
      width: width,
      height: height,
      fit: fit,
      semanticLabel: 'Sahara Logo',
      errorBuilder: (context, error, stackTrace) {
        // Safe fallback in test environments if asset loading is skipped
        return Text(
          'Sahara',
          style: TextStyle(
            fontFamily: 'Fira Sans',
            fontStyle: FontStyle.italic,
            fontSize: height != null ? height! * 0.5 : 20,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0B3B8C),
          ),
        );
      },
    );
  }
}
