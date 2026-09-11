import 'package:flutter/material.dart';

class BrandTitle extends StatelessWidget {
  final double fontSize;
  final FontWeight fontWeight;
  final Color? color;
  final double? letterSpacing;

  const BrandTitle({
    super.key,
    this.fontSize = 24.0,
    this.fontWeight = FontWeight.w700,
    this.color,
    this.letterSpacing,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      'Sahara',
      style: TextStyle(
        fontFamily: 'Fira Sans',
        fontStyle: FontStyle.italic,
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color ?? const Color(0xFF0B3B8C),
        letterSpacing: letterSpacing ?? -0.2,
      ),
    );
  }
}

/// Helper for rendering *Sahara* in italics inline within text or headers
TextSpan buildBrandSpan({
  required BuildContext context,
  double? fontSize,
  FontWeight fontWeight = FontWeight.w700,
  Color? color,
}) {
  return TextSpan(
    text: 'Sahara',
    style: TextStyle(
      fontFamily: 'Fira Sans',
      fontStyle: FontStyle.italic,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? const Color(0xFF0B3B8C),
    ),
  );
}
