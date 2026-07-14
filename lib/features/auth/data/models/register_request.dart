/// Body for password-based registration.
class RegisterBody {
  const RegisterBody({
    required this.phoneE164,
    required this.password,
    required this.name,
    required this.currency,
    required this.language,
    this.email,
    this.monthlyIncome,
  });

  final String phoneE164;
  final String password;
  final String name;
  final String currency; // SAR | JOD | USD | AED | EUR
  final String language; // ar | en
  final String? email;
  final num? monthlyIncome;
}
