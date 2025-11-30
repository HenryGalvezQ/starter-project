import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:news_app_clean_architecture/features/auth/domain/entities/user.dart';
import 'package:news_app_clean_architecture/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:news_app_clean_architecture/features/auth/presentation/bloc/auth_event.dart';
import '../../../../../config/theme/theme_cubit.dart'; // <--- IMPORTANTE: Importar el Cubit

class ProfileScreen extends StatelessWidget {
  final UserEntity user;
  const ProfileScreen({Key? key, required this.user}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Escuchamos el tema actual para reconstruir la pantalla cuando cambie
    return BlocBuilder<ThemeCubit, ThemeMode>(
      builder: (context, themeMode) {
        final isDark = themeMode == ThemeMode.dark;

        return Scaffold(
          appBar: AppBar(
            title: const Text("Mi Perfil"), // El estilo ya viene del AppTheme (Negro o Blanco)
            // Quitamos backgroundColor hardcoded para que use el del tema
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const SizedBox(height: 20),
                
                // 1. AVATAR
                _buildProfileHeader(context, isDark),
                
                const SizedBox(height: 40),

                // 2. OPCIONES (Pasamos isDark para ajustar el color del contenedor)
                _buildSettingsSection(context, isDark),

                const SizedBox(height: 40),

                // 3. BOTÓN CERRAR SESIÓN
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      context.read<AuthBloc>().add(AuthLogout());
                    },
                    icon: const Icon(Icons.logout, color: Colors.white),
                    label: const Text("CERRAR SESIÓN", style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)
                      )
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileHeader(BuildContext context, bool isDark) {
    final String initial = user.displayName != null && user.displayName!.isNotEmpty
        ? user.displayName![0].toUpperCase()
        : "U";

    return Column(
      children: [
        CircleAvatar(
          radius: 60,
          // En modo oscuro, el avatar resalta mejor en blanco o gris claro
          backgroundColor: isDark ? Colors.grey[800] : Colors.black87,
          child: Text(
            initial,
            style: const TextStyle(fontSize: 40, color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 20),
        
        Text(
          user.displayName ?? "Usuario Symmetry",
          // Usamos el estilo del cuerpo, el color se ajusta solo (Negro en Light, Blanco en Dark)
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 24
          ),
        ),
        
        const SizedBox(height: 8),
        
        Text(
          user.email ?? "No Email",
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildSettingsSection(BuildContext context, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        // [CLAVE] Color dinámico: Gris claro en Light, Gris oscuro en Dark
        color: isDark ? Colors.grey[900] : Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        // En dark mode agregamos un borde sutil para separar del fondo negro
        border: isDark ? Border.all(color: Colors.grey[800]!) : null,
      ),
      child: Column(
        children: [
          // SWITCH MODO OSCURO (CONECTADO)
          SwitchListTile(
            title: const Text("Modo Oscuro"),
            secondary: Icon(
              isDark ? Icons.dark_mode : Icons.light_mode,
              // El icono se adapta al color del texto del tema
              color: Theme.of(context).iconTheme.color
            ),
            value: isDark,
            activeColor: Colors.white, // Switch blanco cuando está activo (Dark)
            activeTrackColor: Colors.grey,
            onChanged: (bool value) {
              // LLAMADA AL CUBIT: Esto guarda y cambia el tema globalmente
              context.read<ThemeCubit>().toggleTheme(value);
            },
          ),
          
          Divider(height: 1, color: isDark ? Colors.grey[800] : Colors.grey[300]),

          ListTile(
            leading: Icon(Icons.info_outline, color: Theme.of(context).iconTheme.color),
            title: const Text("Versión de la App"),
            trailing: const Text("1.0.0", style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }
}