import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Stream of auth changes
  Stream<User?> get user => _auth.authStateChanges();

  // Sign in with email and password
  Future<UserCredential?> signIn(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      debugPrint('Error en signIn: ${e.toString()}');
      return null;
    }
  }

  // Register with email, password, and display name
  Future<UserCredential?> register(String email, String password, String displayName) async {
    try {
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      // Actualizar el perfil del usuario con su nombre y apellido
      await credential.user?.updateDisplayName(displayName);
      return credential;
    } catch (e) {
      debugPrint('Error en register: ${e.toString()}');
      return null;
    }
  }

  // Send password reset email
  Future<bool> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return true;
    } catch (e) {
      debugPrint('Error en sendPasswordReset: ${e.toString()}');
      return false;
    }
  }

  // Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // 1. Iniciar el flujo de inicio de sesión de Google
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // El usuario canceló el inicio de sesión
        return null;
      }

      // 2. Obtener los detalles de autenticación del usuario de Google
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // 3. Crear una nueva credencial para Firebase
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 4. Iniciar sesión en Firebase con la credencial de Google
      return await _auth.signInWithCredential(credential);
    } catch (e) {
      debugPrint('Error en signInWithGoogle: ${e.toString()}');
      rethrow; // Re-lanzar para que la pantalla de Login pueda capturar problemas de firma SHA-1
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    await _auth.signOut();
  }
}
