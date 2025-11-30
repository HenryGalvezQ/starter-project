import 'package:flutter/material.dart';

class AppTheme {
  // 1. TEMA CLARO (El que ya teníamos, refinado)
  static ThemeData get light {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: Colors.black,
      scaffoldBackgroundColor: Colors.white, // Fondo Blanco
      fontFamily: 'Muli',
      
      // AppBar Claro
      appBarTheme: const AppBarTheme(
        color: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.black),
        titleTextStyle: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
      ),

      // Textos por defecto en negro
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: Colors.black87),
        bodyLarge: TextStyle(color: Colors.black87),
      ),
      
      // Inputs
      inputDecorationTheme: const InputDecorationTheme(
        fillColor: Colors.white,
        filled: true,
      ),
    );
  }

  // 2. TEMA OSCURO (Invertido: Fondo Negro, Letras Blancas)
  static ThemeData get dark {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: Colors.white,
      scaffoldBackgroundColor: const Color(0xFF121212), // Negro suave (Material Standard) o Colors.black
      fontFamily: 'Muli',
      
      // AppBar Oscuro
      appBarTheme: const AppBarTheme(
        color: Color(0xFF121212), // Mismo que scaffold para efecto "flat"
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
      ),

      // Textos por defecto en blanco
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: Colors.white),
        bodyLarge: TextStyle(color: Colors.white),
      ),

      // Inputs oscuros
      inputDecorationTheme: InputDecorationTheme(
        fillColor: Colors.grey[900],
        filled: true,
        border: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey[800]!),
        ),
        hintStyle: TextStyle(color: Colors.grey[500]),
      ),
      
      // Iconos generales
      iconTheme: const IconThemeData(color: Colors.white),
    );
  }
}