import 'package:flutter/material.dart';

class SymmetryAppLogo extends StatelessWidget {
  const SymmetryAppLogo({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Detectamos si es modo oscuro
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(8.0), // Margen para que no toque los bordes
      child: Image.asset(
        isDark 
            ? 'assets/images/logo_symmetry_white.jpg' 
            : 'assets/images/logo_symmetry.jpg',
        fit: BoxFit.contain,
      ),
    );
  }
}