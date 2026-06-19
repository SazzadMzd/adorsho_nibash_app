import '../models/flat.dart';
import '../models/tenant.dart';
import '../models/bill.dart';
import '../models/electricity_reading.dart';

class BillGenerator {
  static String currentMonth() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  static String previousMonth(String month) {
    final parts = month.split('-');
    var y = int.parse(parts[0]);
    var m = int.parse(parts[1]) - 1;
    if (m < 1) {
      m = 12;
      y--;
    }
    return '$y-${m.toString().padLeft(2, '0')}';
  }

  static String nextMonth(String month) {
    final parts = month.split('-');
    var y = int.parse(parts[0]);
    var m = int.parse(parts[1]);
    m++;
    if (m > 12) {
      m = 1;
      y++;
    }
    return '$y-${m.toString().padLeft(2, '0')}';
  }

  static List<String> monthsBetween(String from, String to) {
    final result = <String>[];
    final fromParts = from.split('-');
    final toParts = to.split('-');
    var y = int.parse(fromParts[0]);
    var m = int.parse(fromParts[1]);
    final targetY = int.parse(toParts[0]);
    final targetM = int.parse(toParts[1]);

    while (y < targetY || (y == targetY && m <= targetM)) {
      result.add('$y-${m.toString().padLeft(2, '0')}');
      m++;
      if (m > 12) {
        m = 1;
        y++;
      }
    }
    return result;
  }

  static bool needsGeneration(String? lastGeneratedMonth) {
    if (lastGeneratedMonth == null) return true;
    return lastGeneratedMonth != currentMonth();
  }

  static List<Bill> createBills(
    String month,
    List<Tenant> tenants,
    Map<String, Flat> flatMap, [
    Map<String, ElectricityReading>? readingsByFlatId,
    Map<String, Bill>? prevBillsByFlatId,
  ]) {
    return tenants
        .where((t) => t.isActive)
        .map((tenant) {
          final flat = flatMap[tenant.flatId];
          if (flat == null) return null;

          double electricity = 0;
          double prevReading = 0;

          final reading = readingsByFlatId?[tenant.flatId];
          if (reading != null) {
            electricity = reading.billAmount;
            prevReading = reading.previousReading;
          }

          final prevBill = prevBillsByFlatId?[tenant.flatId];
          if (prevBill != null) {
            if (reading == null || prevReading <= 0) {
              prevReading = prevBill.currentMeterReading;
            }
          }

          return Bill(
            id: '',
            tenantId: tenant.id,
            flatId: tenant.flatId,
            month: month,
            rent: flat.rent,
            gas: flat.gas,
            water: flat.water,
            garage: flat.garage,
            electricity: electricity,
            prevMeterReading: prevReading,
            status: 'pending',
          );
        })
        .whereType<Bill>()
        .toList();
  }

  static String formatMonth(String month) {
    final parts = month.split('-');
    final months = [
      'জানুয়ারী', 'ফেব্রুয়ারী', 'মার্চ', 'এপ্রিল',
      'মে', 'জুন', 'জুলাই', 'আগস্ট',
      'সেপ্টেম্বর', 'অক্টোবর', 'নভেম্বর', 'ডিসেম্বর',
    ];
    final m = int.parse(parts[1]);
    return '${months[m - 1]} ${parts[0]}';
  }
}
