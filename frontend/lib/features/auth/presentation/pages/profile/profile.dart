import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:news_app_clean_architecture/features/auth/domain/entities/user.dart';
import 'package:news_app_clean_architecture/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:news_app_clean_architecture/features/auth/presentation/bloc/auth_event.dart';

class ProfileScreen extends StatefulWidget {
  final UserEntity user;
  const ProfileScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Estado local temporal para el switch (luego lo conectaremos al ThemeCubit)
  bool _isDarkMode = false; 

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mi Perfil", style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            
            // 1. AVATAR MEJORADO
            _buildProfileHeader(),
            
            const SizedBox(height: 40),

            // 2. OPCIONES DE CONFIGURACIÓN
            _buildSettingsSection(),

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
  }

  Widget _buildProfileHeader() {
    // Si tuviéramos photoURL en la entidad UserEntity, lo usaríamos aquí.
    // Por ahora, usamos un diseño limpio con las iniciales.
    final String initial = widget.user.displayName != null && widget.user.displayName!.isNotEmpty
        ? widget.user.displayName![0].toUpperCase()
        : "U";

    return Column(
      children: [
        CircleAvatar(
          radius: 60,
          backgroundColor: Colors.black87,
          child: Text(
            initial,
            style: const TextStyle(fontSize: 40, color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 20),
        
        // DISPLAY NAME (Requerimiento 11.1)
        Text(
          widget.user.displayName ?? "Usuario Symmetry",
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        
        const SizedBox(height: 8),
        
        // EMAIL
        Text(
          widget.user.email ?? "No Email",
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
        // [ELIMINADO] UID crudo para cumplir con el requerimiento de UX
      ],
    );
  }

  Widget _buildSettingsSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // SWITCH MODO OSCURO (Visual por ahora)
          SwitchListTile(
            title: const Text("Modo Oscuro"),
            secondary: Icon(
              _isDarkMode ? Icons.dark_mode : Icons.light_mode,
              color: Colors.black87
            ),
            value: _isDarkMode,
            activeColor: Colors.black,
            onChanged: (bool value) {
              setState(() {
                _isDarkMode = value;
              });
              // TODO: Conectar con ThemeCubit en la siguiente tarea
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Próximamente: Cambio de tema global"),
                  duration: Duration(milliseconds: 500),
                )
              );
            },
          ),
          
          const Divider(height: 1),

          ListTile(
            leading: const Icon(Icons.info_outline, color: Colors.black87),
            title: const Text("Versión de la App"),
            trailing: const Text("1.0.0", style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }
}