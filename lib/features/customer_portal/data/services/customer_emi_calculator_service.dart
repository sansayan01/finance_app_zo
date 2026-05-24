/// Pure EMI calculation service for the customer portal.
/// No UI dependencies — returns raw numbers and schedule data.
class CustomerEmiCalculatorService {
  CustomerEmiCalculatorService._();

  /// Calculates the Equated Monthly Installment.
  ///
  /// Formula: EMI = P * r * (1+r)^n / ((1+r)^n - 1)
  /// where P = principal, r = monthly rate, n = tenure in months.
  ///
  /// Returns 0 when [principal], [annualRate], or [tenureMonths] is zero
  /// to avoid division-by-zero in the UI.
  static double calculateEMI(
    double principal,
    double annualRate,
    int tenureMonths,
  ) {
    if (principal <= 0 || annualRate <= 0 || tenureMonths <= 0) return 0;

    final monthlyRate = annualRate / 12 / 100;
    final powFactor = _pow(1 + monthlyRate, tenureMonths);
    return principal * monthlyRate * powFactor / (powFactor - 1);
  }

  /// Total amount paid over the full tenure.
  static double calculateTotalPayment(double emi, int tenureMonths) {
    return emi * tenureMonths;
  }

  /// Total interest component (total payment minus principal).
  static double calculateTotalInterest(double totalPayment, double principal) {
    return totalPayment - principal;
  }

  /// Generates a month-by-month repayment schedule.
  ///
  /// Each entry contains:
  /// - `emiNumber`   — 1-based period index
  /// - `emiAmount`   — fixed EMI for the period
  /// - `principal`   — principal component of this EMI
  /// - `interest`    — interest component of this EMI
  /// - `balanceAfter` — outstanding balance after this EMI
  static List<Map<String, dynamic>> generateSchedule(
    double principal,
    double annualRate,
    int tenureMonths,
  ) {
    if (principal <= 0 || annualRate <= 0 || tenureMonths <= 0) return [];

    final emi = calculateEMI(principal, annualRate, tenureMonths);
    final monthlyRate = annualRate / 12 / 100;
    final schedule = <Map<String, dynamic>>[];
    double balance = principal;

    for (int i = 1; i <= tenureMonths; i++) {
      final interest = balance * monthlyRate;
      final principalPart = emi - interest;
      balance -= principalPart;

      // Clamp final balance to zero to avoid floating-point artefacts.
      if (i == tenureMonths) balance = 0;
      if (balance < 0) balance = 0;

      schedule.add({
        'emiNumber': i,
        'emiAmount': emi,
        'principal': principalPart,
        'interest': interest,
        'balanceAfter': balance,
      });
    }

    return schedule;
  }

  // ── Helpers ──

  static double _pow(double base, int exponent) {
    double result = 1;
    for (int i = 0; i < exponent; i++) {
      result *= base;
    }
    return result;
  }
}
