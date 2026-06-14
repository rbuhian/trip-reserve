import 'package:freezed_annotation/freezed_annotation.dart';

import 'enums.dart';

part 'withdrawal.freezed.dart';
part 'withdrawal.g.dart';

/// Driver withdrawal request
@freezed
abstract class Withdrawal with _$Withdrawal {
  const factory Withdrawal({
    required String id,
    @JsonKey(name: 'driver_id') required String driverId,
    required double amount,
    @JsonKey(name: 'payout_method') required PayoutMethod payoutMethod,
    @JsonKey(name: 'payout_account') required String payoutAccount,
    @JsonKey(name: 'payout_name') required String payoutName,
    required WithdrawalStatus status,
    String? note,
    @JsonKey(name: 'reject_reason') String? rejectReason,
    @JsonKey(name: 'reference_number') String? referenceNumber,
    @JsonKey(name: 'proof_url') String? proofUrl,
    @JsonKey(name: 'requested_at') required DateTime requestedAt,
    @JsonKey(name: 'reviewed_by') String? reviewedBy,
    @JsonKey(name: 'reviewed_at') DateTime? reviewedAt,
    @JsonKey(name: 'paid_at') DateTime? paidAt,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  }) = _Withdrawal;

  factory Withdrawal.fromJson(Map<String, dynamic> json) =>
      _$WithdrawalFromJson(json);
}

/// Audit trail event for a withdrawal
@freezed
abstract class WithdrawalEvent with _$WithdrawalEvent {
  const factory WithdrawalEvent({
    required String id,
    @JsonKey(name: 'withdrawal_id') required String withdrawalId,
    required String event,
    @JsonKey(name: 'actor_id') String? actorId,
    String? note,
    @JsonKey(name: 'created_at') required DateTime createdAt,
  }) = _WithdrawalEvent;

  factory WithdrawalEvent.fromJson(Map<String, dynamic> json) =>
      _$WithdrawalEventFromJson(json);
}
