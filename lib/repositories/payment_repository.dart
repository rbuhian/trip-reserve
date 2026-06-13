import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/enums.dart';
import '../models/payment.dart';
import '../providers/supabase_provider.dart';

/// Provider for PaymentRepository
final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return PaymentRepository(client);
});

/// Repository for PayMongo payments (checkout + realtime status).
class PaymentRepository {
  final SupabaseClient _client;

  PaymentRepository(this._client);

  /// Map our [PaymentMethod] enum to the PayMongo token the
  /// `create-payment-checkout` edge function expects.
  ///
  /// `gcash` -> `gcash`, `card` -> `card`, `maya` -> `paymaya`.
  String _methodToken(PaymentMethod m) =>
      m == PaymentMethod.maya ? 'paymaya' : m.value;

  /// Create a PayMongo hosted checkout session for [bookingId] using [method].
  ///
  /// Calls the `create-payment-checkout` edge function, which returns
  /// `{ checkoutUrl, paymentId }`.
  Future<PaymentCheckout> createCheckout({
    required String bookingId,
    required PaymentMethod method,
  }) async {
    final res = await _client.functions.invoke(
      'create-payment-checkout',
      body: {'bookingId': bookingId, 'method': _methodToken(method)},
    );

    if (res.status < 200 || res.status >= 300) {
      throw Exception(
        'Failed to create payment checkout (status ${res.status}): ${res.data}',
      );
    }

    final data = res.data;
    if (data is! Map) {
      throw Exception('Invalid checkout response from server');
    }

    final json = data.cast<String, dynamic>();

    // The edge function returns camelCase keys (`checkoutUrl`, `paymentId`),
    // while PaymentCheckout.fromJson reads snake_case. Normalize so the model
    // deserializes correctly regardless of which casing the server sends.
    final checkoutUrl = json['checkout_url'] ?? json['checkoutUrl'];
    final paymentId = json['payment_id'] ?? json['paymentId'];

    if (checkoutUrl == null || paymentId == null) {
      throw Exception('Checkout response missing checkout url or payment id');
    }

    return PaymentCheckout.fromJson({
      'checkout_url': checkoutUrl,
      'payment_id': paymentId,
    });
  }

  /// Watch the latest payment row for a booking via Supabase Realtime, so the
  /// UI can react when the PayMongo webhook flips the status to `paid`.
  Stream<Payment?> watchPayment(String bookingId) {
    return _client
        .from('payments')
        .stream(primaryKey: ['id'])
        .eq('booking_id', bookingId)
        .order('created_at', ascending: false)
        .map((rows) => rows.isEmpty ? null : Payment.fromJson(rows.first));
  }

  /// One-shot fetch of the newest payment for a booking, or null if none.
  Future<Payment?> getPaymentForBooking(String bookingId) async {
    final response = await _client
        .from('payments')
        .select()
        .eq('booking_id', bookingId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    return response != null ? Payment.fromJson(response) : null;
  }
}
