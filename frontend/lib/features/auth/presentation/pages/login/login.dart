import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:news_app_clean_architecture/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:news_app_clean_architecture/features/auth/presentation/bloc/auth_event.dart';
import 'package:news_app_clean_architecture/features/auth/presentation/bloc/auth_state.dart';
import 'package:news_app_clean_architecture/features/auth/presentation/pages/register/register.dart';
import 'package:news_app_clean_architecture/features/daily_news/presentation/widgets/symmetry_logo.dart';

class LoginScreen extends HookWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final emailController = useTextEditingController();
    final passwordController = useTextEditingController();
    final isPasswordVisible = useState(false);
    
    // Detectar tema
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Inicia Sesión",
          style: Theme.of(context).appBarTheme.titleTextStyle, 
        ),
      ),
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
        },
        builder: (context, state) {
          if (state is AuthLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          
          return Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    
                    // 1. LOGO
                    const SizedBox(
                      height: 120, 
                      child: SymmetryAppLogo(),
                    ),

                    // 2. TEXTO "Symmetry News" (Nuevo Agregado)
                    const SizedBox(height: 20), // Separación pequeña entre logo y texto
                    Text(
                      "Symmetry News",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        // Color dinámico: Blanco en Dark, Negro en Light
                        color: isDark ? Colors.white : Colors.black
                      ),
                    ),
                    
                    const SizedBox(height: 40), // Separación hacia los inputs
                    
                    // Email Input
                    TextField(
                      controller: emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    
                    // Password Input
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

                    // Login Button
                    ElevatedButton(
                      onPressed: () {
                        final email = emailController.text.trim();
                        final password = passwordController.text.trim();
                        if (email.isNotEmpty && password.isNotEmpty) {
                          context.read<AuthBloc>().add(AuthLogin(email, password));
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Llena todos los campos")),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? Colors.white : Colors.black87,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        "INGRESAR", 
                        style: TextStyle(color: isDark ? Colors.black : Colors.white)
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Register Link
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const RegisterScreen()),
                        );
                      },
                      child: const Text("¿No tienes cuenta? Regístrate"),
                    )
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}