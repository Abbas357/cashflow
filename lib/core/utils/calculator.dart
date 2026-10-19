/// Evaluates simple arithmetic like `1200+350*2-50/5`.
///
/// Supports + - * / and decimals, with the usual precedence. Returns null
/// for anything it cannot read, or for division by zero.
double? evaluateExpression(String input) {
  final src = input
      .replaceAll('×', '*')
      .replaceAll('÷', '/')
      .replaceAll('−', '-')
      .replaceAll(',', '')
      .replaceAll(' ', '');
  if (src.isEmpty) return null;

  final tokens = <String>[];
  final buf = StringBuffer();
  for (var i = 0; i < src.length; i++) {
    final c = src[i];
    final isOp = '+-*/'.contains(c);
    // A leading minus, or one right after another operator, is a sign.
    final isSign =
        c == '-' && (i == 0 || '+-*/'.contains(src[i - 1])) && buf.isEmpty;
    if (isOp && !isSign) {
      if (buf.isEmpty) return null;
      tokens.add(buf.toString());
      buf.clear();
      tokens.add(c);
    } else if ('0123456789.-'.contains(c)) {
      buf.write(c);
    } else {
      return null;
    }
  }
  if (buf.isEmpty) {
    // Trailing operator: ignore it so "120+" still shows 120.
    if (tokens.isNotEmpty) tokens.removeLast();
  } else {
    tokens.add(buf.toString());
  }
  if (tokens.isEmpty) return null;

  // First pass: * and /.
  final pass = <Object>[];
  double? read(String s) => double.tryParse(s);
  var acc = read(tokens[0]);
  if (acc == null) return null;
  for (var i = 1; i < tokens.length; i += 2) {
    final op = tokens[i];
    final rhs = read(tokens[i + 1]);
    if (rhs == null) return null;
    if (op == '*') {
      acc = acc! * rhs;
    } else if (op == '/') {
      if (rhs == 0) return null;
      acc = acc! / rhs;
    } else {
      pass
        ..add(acc!)
        ..add(op);
      acc = rhs;
    }
  }
  pass.add(acc!);

  // Second pass: + and -.
  var total = pass[0] as double;
  for (var i = 1; i < pass.length; i += 2) {
    final v = pass[i + 1] as double;
    total = pass[i] == '+' ? total + v : total - v;
  }
  return total;
}
