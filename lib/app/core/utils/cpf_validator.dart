/// Valida CPF pelo algoritmo dos dígitos verificadores.
/// Retorna null se válido, ou mensagem de erro se inválido.
String? validateCpf(String? value) {
  final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');

  if (digits.length != 11) return 'CPF inválido.';

  // Rejeita sequências iguais (ex: 000.000.000-00, 111.111.111-11)
  if (RegExp(r'^(\d)\1{10}$').hasMatch(digits)) return 'CPF inválido.';

  // Primeiro dígito verificador
  int sum = 0;
  for (int i = 0; i < 9; i++) {
    sum += int.parse(digits[i]) * (10 - i);
  }
  int remainder = (sum * 10) % 11;
  if (remainder == 10 || remainder == 11) remainder = 0;
  if (remainder != int.parse(digits[9])) return 'CPF inválido.';

  // Segundo dígito verificador
  sum = 0;
  for (int i = 0; i < 10; i++) {
    sum += int.parse(digits[i]) * (11 - i);
  }
  remainder = (sum * 10) % 11;
  if (remainder == 10 || remainder == 11) remainder = 0;
  if (remainder != int.parse(digits[10])) return 'CPF inválido.';

  return null;
}
