import '../models/student.dart';

/// Simple due calculator: expected total fee since admission
/// (monthly fee x number of months elapsed, minimum 1 month) minus total
/// amount already paid by the student.
class DueCalculator {
  static int monthsElapsed(DateTime admission, [DateTime? now]) {
    final n = now ?? DateTime.now();
    int months =
        (n.year - admission.year) * 12 + (n.month - admission.month) + 1;
    if (months < 1) months = 1;
    return months;
  }

  static double expectedTotal(Student s) {
    return s.monthlyFee * monthsElapsed(s.admissionDate);
  }

  static double due(Student s, double totalPaid) {
    final expected = expectedTotal(s);
    final d = expected - totalPaid;
    return d < 0 ? 0 : d;
  }

  static double advance(Student s, double totalPaid) {
    final expected = expectedTotal(s);
    final a = totalPaid - expected;
    return a < 0 ? 0 : a;
  }
}
