import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/driver_balance.dart';
import '../models/enums.dart';
import '../models/withdrawal.dart';
import '../providers/supabase_provider.dart';

/// Provider for PayoutRepository
final payoutRepositoryProvider = Provider<PayoutRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return PayoutRepository(client);
});

/// Repository for driver payouts & withdrawals
class PayoutRepository {
  final SupabaseClient _client;

  PayoutRepository(this._client);

  /// Get current user's ID
  String? get _currentUserId => _client.auth.currentUser?.id;

  /// Normalize an RPC response that returns a single row, handling both a
  /// single Map and a one-element List defensively.
  Map<String, dynamic> _rowFrom(dynamic res) {
    return res is List
        ? res.first as Map<String, dynamic>
        : res as Map<String, dynamic>;
  }

  // ============================================
  // DRIVER
  // ============================================

  /// Get the current driver's balance summary via the
  /// `get_my_driver_balance` RPC. Returns a zeroed balance when empty.
  Future<DriverBalance> getMyBalance() async {
    final response = await _client.rpc('get_my_driver_balance');

    final rows = response as List;
    if (rows.isEmpty) {
      return const DriverBalance(
        totalEarned: 0,
        available: 0,
        pending: 0,
        paidOut: 0,
      );
    }

    return DriverBalance.fromJson(rows.first as Map<String, dynamic>);
  }

  /// Watch the current driver's withdrawals via Supabase Realtime, newest
  /// first.
  Stream<List<Withdrawal>> watchMyWithdrawals() {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    return _client
        .from('withdrawals')
        .stream(primaryKey: ['id'])
        .eq('driver_id', _currentUserId!)
        .order('requested_at', ascending: false)
        .map((rows) => rows.map(Withdrawal.fromJson).toList());
  }

  /// Request a withdrawal via the `request_withdrawal` RPC.
  Future<Withdrawal> requestWithdrawal({
    required double amount,
    required PayoutMethod method,
    required String account,
    required String name,
    String? note,
  }) async {
    final response = await _client.rpc(
      'request_withdrawal',
      params: {
        'p_amount': amount,
        'p_method': method.value,
        'p_account': account,
        'p_name': name,
        'p_note': note,
      },
    );

    return Withdrawal.fromJson(_rowFrom(response));
  }

  /// Cancel the driver's own withdrawal while it is still pending.
  Future<Withdrawal> cancelWithdrawal(String id) async {
    final response = await _client.rpc(
      'cancel_withdrawal',
      params: {'p_id': id},
    );
    return Withdrawal.fromJson(_rowFrom(response));
  }

  /// Get the audit trail events for a withdrawal, oldest first.
  Future<List<WithdrawalEvent>> getEvents(String withdrawalId) async {
    final response = await _client
        .from('withdrawal_events')
        .select()
        .eq('withdrawal_id', withdrawalId)
        .order('created_at', ascending: true);

    return (response as List)
        .map((json) => WithdrawalEvent.fromJson(json))
        .toList();
  }

  // ============================================
  // ADMIN
  // ============================================

  /// Get withdrawals for admin review, optionally filtered by status, newest
  /// first. Each record pairs the withdrawal with its driver's name.
  Future<List<({Withdrawal withdrawal, String driverName})>>
      adminGetWithdrawals({WithdrawalStatus? status}) async {
    var query = _client
        .from('withdrawals')
        .select('*, driver:users!driver_id(full_name)');

    if (status != null) {
      query = query.eq('status', status.value);
    }

    final response = await query.order('requested_at', ascending: false);

    return (response as List).map((row) {
      final driverName = row['driver']?['full_name'] as String? ?? 'Driver';
      return (
        withdrawal: Withdrawal.fromJson(row),
        driverName: driverName,
      );
    }).toList();
  }

  /// Approve a withdrawal via the `approve_withdrawal` RPC.
  Future<Withdrawal> approve(String id) async {
    final response = await _client.rpc(
      'approve_withdrawal',
      params: {'p_id': id},
    );

    return Withdrawal.fromJson(_rowFrom(response));
  }

  /// Reject a withdrawal via the `reject_withdrawal` RPC.
  Future<Withdrawal> reject(String id, String reason) async {
    final response = await _client.rpc(
      'reject_withdrawal',
      params: {'p_id': id, 'p_reason': reason},
    );

    return Withdrawal.fromJson(_rowFrom(response));
  }

  /// Mark a withdrawal as paid via the `mark_withdrawal_paid` RPC.
  Future<Withdrawal> markPaid(
    String id, {
    required String reference,
    required String proofPath,
  }) async {
    final response = await _client.rpc(
      'mark_withdrawal_paid',
      params: {
        'p_id': id,
        'p_reference': reference,
        'p_proof_url': proofPath,
      },
    );

    return Withdrawal.fromJson(_rowFrom(response));
  }

  // ============================================
  // STORAGE (proof screenshot)
  // ============================================

  /// Upload a payout proof screenshot to the private `payout-proofs` bucket.
  /// Returns the object path (store this in `proof_url`).
  Future<String> uploadProof(
    Uint8List bytes, {
    required String fileExt,
    String contentType = 'image/jpeg',
  }) async {
    final path =
        '$_currentUserId/${DateTime.now().millisecondsSinceEpoch}.$fileExt';

    await _client.storage.from('payout-proofs').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );

    return path;
  }

  /// Create a signed URL (1 hour) for displaying a payout proof.
  Future<String> signedProofUrl(String path) async {
    return _client.storage.from('payout-proofs').createSignedUrl(path, 3600);
  }
}
