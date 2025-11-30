import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:news_app_clean_architecture/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:news_app_clean_architecture/features/auth/presentation/bloc/auth_event.dart';
import 'package:news_app_clean_architecture/features/auth/presentation/bloc/auth_state.dart';
import 'package:news_app_clean_architecture/features/daily_news/presentation/widgets/symmetry_logo.dart';

class RegisterScreen extends HookWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final usernameController = useTextEditingController();
    final emailController = useTextEditingController();
    final passwordController = useTextEditingController();
    final isPasswordVisible = useState(false);

    // Detectar tema
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Crear Cuenta",
          // Usamos el estilo del tema
          style: Theme.of(context).appBarTheme.titleTextStyle,
        ),
        // Quitamos colores fijos
      ),
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is Authenticated) {
            Navigator.of(context).pop(); 
          }
          if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is AuthLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  
                  // --- AGREGAMOS EL LOGO AQUÍ TAMBIÉN ---
                  const SizedBox(
                      height: 100, 
                      child: SymmetryAppLogo()
                  ),
                  const SizedBox(height: 20),

                  Text(
                    "Únete a Symmetry News",
                    textAlign: TextAlign.center,
                    // Color dinámico según tema
                    style: TextStyle(
                      fontSize: 24, 
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Crea tu perfil de periodista fitness",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 30),

                  // USERNAME INPUT
                  TextField(
                    controller: usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de Usuario',
                      hintText: 'Ej: Juan Periodista',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // EMAIL INPUT
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // PASSWORD INPUT
                  TextField(
                    controller: passwordController,
                    obscureText: !isPasswordVisible.value, 
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          isPasswordVisible.value 
                              ? Icons.visibility 
                              : Icons.visibility_off,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          isPasswordVisible.value = !isPasswordVisible.value;
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // REGISTER BUTTON
                  ElevatedButton(
                    onPressed: () {
                      final username = usernameController.text.trim();
                      final email = emailController.text.trim();
                      final password = passwordController.text.trim();

                      if (username.isNotEmpty &&
                          email.isNotEmpty &&
                          password.isNotEmpty) {
                        
                        context.read<AuthBloc>().add(AuthRegister(
                              email: email,
                              password: password,
                              username: username,
                            ));
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Por favor llena todos los campos"),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      // Lógica de color invertido para visibilidad
                      backgroundColor: isDark ? Colors.white : Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      "REGISTRARSE",
                      // Texto invertido
                      style: TextStyle(color: isDark ? Colors.black : Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}