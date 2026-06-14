import 'package:freezed_annotation/freezed_annotation.dart';

part 'driver_balance.freezed.dart';
part 'driver_balance.g.dart';

/// Driver balance summary from the `get_my_driver_balance()` RPC
@freezed
abstract class DriverBalance with _$DriverBalance {
  const factory DriverBalance({
    @JsonKey(name: 'total_earned') required double totalEarned,
    required double available,
    required double pending,
    @JsonKey(name: 'paid_out') required double paidOut,
  }) = _DriverBalance;

  factory DriverBalance.fromJson(Map<String, dynamic> json) =>
      _$DriverBalanceFromJson(json);
}
