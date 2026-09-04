import 'package:flutter/material.dart';

class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 148});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/brand_logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      semanticLabel: '포마펫 로고',
    );
  }
}
