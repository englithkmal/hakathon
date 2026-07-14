/// Body for password-based login.
class LoginBody {
  const LoginBody({required this.phoneE164, required this.password});

  final String phoneE164;
  final String password;
}
