import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/booking.dart';
import '../../../models/enums.dart';
import '../../../models/payment.dart';
import '../../../providers/payment_provider.dart';
import '../../../repositories/booking_repository.dart';
import '../../../repositories/payment_repository.dart';

/// Fetches the (already-created, pending) booking we are paying for.
final _paymentBookingProvider =
    FutureProvider.family<Booking?, String>((ref, id) async {
  return ref.watch(bookingRepositoryProvider).getById(id);
});

/// Steps in the payment flow.
enum _PaymentStep { selecting, awaiting, failed }

/// PayMongo hosted checkout — customer picks a method, taps Pay, completes
/// the payment in the browser, then we wait for the webhook (delivered via
/// Realtime) to mark the payment paid and return to the booking details.
class PaymentMethodScreen extends ConsumerStatefulWidget {
  const PaymentMethodScreen({super.key, required this.bookingId});

  final String bookingId;

  @override
  ConsumerState<PaymentMethodScreen> createState() =>
      _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends ConsumerState<PaymentMethodScreen> {
  final _currencyFormat = NumberFormat.currency(
    locale: 'en_PH',
    symbol: '₱',
    decimalDigits: 2,
  );

  PaymentMethod _selectedMethod = PaymentMethod.gcash;
  _PaymentStep _step = _PaymentStep.selecting;
  bool _processing = false;

  /// Guards against navigating away more than once after payment completes.
  bool _navigated = false;

  Future<void> _pay(Booking booking) async {
    setState(() => _processing = true);

    try {
      final checkout = await ref.read(paymentRepositoryProvider).createCheckout(
            bookingId: widget.bookingId,
            method: _selectedMethod,
          );

      await launchUrl(
        Uri.parse(checkout.checkoutUrl),
        mode: LaunchMode.externalApplication,
      );

      if (!mounted) return;
      setState(() {
        _step = _PaymentStep.awaiting;
        _processing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _step = _PaymentStep.selecting;
        _processing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not start payment: ${e.toString()}'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _resetToSelecting() {
    setState(() {
      _step = _PaymentStep.selecting;
      _processing = false;
    });
  }

  void _onPaymentChanged(AsyncValue<Payment?> async) {
    final payment = async.valueOrNull;
    if (payment == null) return;

    if (payment.isPaid && !_navigated) {
      _navigated = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.go('/bookings/${widget.bookingId}');
        }
      });
    } else if (payment.isFailed && _step != _PaymentStep.failed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _step = _PaymentStep.failed;
            _processing = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // React to the live payment status from the webhook (via Realtime).
    ref.listen<AsyncValue<Payment?>>(
      paymentForBookingProvider(widget.bookingId),
      (_, next) => _onPaymentChanged(next),
    );

    final bookingAsync = ref.watch(_paymentBookingProvider(widget.bookingId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment'),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: AppColors.white,
      ),
      body: bookingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _buildError(
          'Could not load your booking.\n${error.toString()}',
        ),
        data: (booking) {
          if (booking == null) {
            return _buildError('Booking not found.');
          }
          return _buildBody(booking);
        },
      ),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMedium),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () =>
                  ref.invalidate(_paymentBookingProvider(widget.bookingId)),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(Booking booking) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildAmountHeader(booking),
          const SizedBox(height: 24),
          if (_step == _PaymentStep.selecting) ...[
            _buildMethodPicker(),
            const SizedBox(height: 24),
            _buildPayButton(booking),
          ] else if (_step == _PaymentStep.awaiting)
            _buildAwaitingCard()
          else
            _buildFailedCard(),
        ],
      ),
    );
  }

  Widget _buildAmountHeader(Booking booking) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Amount due',
            style: TextStyle(fontSize: 13, color: AppColors.accentLight),
          ),
          const SizedBox(height: 6),
          Text(
            _currencyFormat.format(booking.totalAmount),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: AppColors.white,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.confirmation_number_outlined,
                  size: 14, color: AppColors.accentLight),
              const SizedBox(width: 6),
              Text(
                'Ref ${booking.referenceNumber}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.accentLight,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMethodPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select payment method',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 12),
        ...PaymentMethod.values.map(_buildMethodTile),
      ],
    );
  }

  IconData _iconFor(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.card:
        return Icons.credit_card;
      case PaymentMethod.gcash:
      case PaymentMethod.maya:
        return Icons.account_balance_wallet_outlined;
    }
  }

  Widget _buildMethodTile(PaymentMethod method) {
    final selected = method == _selectedMethod;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: _processing
            ? null
            : () => setState(() => _selectedMethod = method),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.accent.withOpacity(0.08)
                : AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: (selected ? AppColors.accent : AppColors.primary)
                      .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _iconFor(method),
                  color: selected ? AppColors.accentDark : AppColors.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  method.displayName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: selected ? AppColors.accent : AppColors.disabled,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPayButton(Booking booking) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _processing ? null : () => _pay(booking),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.primary,
          disabledBackgroundColor: AppColors.disabled,
        ),
        child: _processing
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              )
            : Text(
                'Pay ${_currencyFormat.format(booking.totalAmount)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }

  Widget _buildAwaitingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Waiting for payment confirmation…',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Complete your payment in the browser. '
            'This screen updates automatically.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textMedium),
          ),
        ],
      ),
    );
  }

  Widget _buildFailedCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.errorLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.cancel_outlined, size: 44, color: AppColors.error),
          const SizedBox(height: 16),
          const Text(
            'Payment failed',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.error,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your payment didn\'t go through. Please try again.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textMedium),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _resetToSelecting,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.primary,
              ),
              child: const Text(
                'Try again',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
