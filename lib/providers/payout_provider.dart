import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/driver_balance.dart';
import '../models/enums.dart';
import '../models/withdrawal.dart';
import '../repositories/payout_repository.dart';

/// Driver's payout balance (total earned / available / pending / paid out).
final myBalanceProvider = FutureProvider<DriverBalance>((ref) async {
  return ref.watch(payoutRepositoryProvider).getMyBalance();
});

/// Live list of the current driver's withdrawals.
final myWithdrawalsProvider = StreamProvider<List<Withdrawal>>((ref) {
  return ref.watch(payoutRepositoryProvider).watchMyWithdrawals();
});

/// Admin list of withdrawal requests, optionally filtered by status.
final adminWithdrawalsProvider = FutureProvider
    .family<List<({Withdrawal withdrawal, String driverName})>, WithdrawalStatus?>(
        (ref, status) async {
  return ref.watch(payoutRepositoryProvider).adminGetWithdrawals(status: status);
});

/// Audit-trail events for a withdrawal.
final withdrawalEventsProvider =
    FutureProvider.family<List<WithdrawalEvent>, String>((ref, id) async {
  return ref.watch(payoutRepositoryProvider).getEvents(id);
});
