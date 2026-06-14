import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/driver_balance.dart';
import '../../../models/enums.dart';
import '../../../models/withdrawal.dart';
import '../../../providers/payout_provider.dart';
import '../../../repositories/payout_repository.dart';

final _php = NumberFormat.currency(
  locale: 'en_PH',
  symbol: '₱',
  decimalDigits: 2,
);

final _dateFmt = DateFormat('MMM d, y · h:mm a');
final _dateShortFmt = DateFormat('MMM d, y');

/// Driver wallet: balance, request a withdrawal, and review history.
class DriverEarningsScreen extends ConsumerWidget {
  const DriverEarningsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(myBalanceProvider);
    final withdrawals = ref.watch(myWithdrawalsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('My Earnings')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myBalanceProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _BalanceCard(balance: balance),
            const SizedBox(height: 16),
            _RequestButton(balance: balance),
            const SizedBox(height: 28),
            Text(
              'Withdrawal History',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            _HistoryList(withdrawals: withdrawals),
          ],
        ),
      ),
    );
  }
}

// ============================================
// BALANCE CARD
// ============================================

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balance});

  final AsyncValue<DriverBalance> balance;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primary.withOpacity(0.85),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: balance.when(
        data: (b) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Available Balance',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              _php.format(b.available),
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _row('Total Earned', b.totalEarned),
                  const SizedBox(height: 10),
                  _row('Pending (in review)', b.pending),
                  const SizedBox(height: 10),
                  _row('Paid Out', b.paidOut),
                ],
              ),
            ),
          ],
        ),
        loading: () => const SizedBox(
          height: 120,
          child: Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        ),
        error: (_, __) => const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Could not load balance',
              style: TextStyle(color: Colors.white, fontSize: 15),
            ),
            SizedBox(height: 12),
            _BalanceRetry(),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, double value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.white.withOpacity(0.75),
          ),
        ),
        Text(
          _php.format(value),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

// Retry needs ref access; provide a Consumer-wrapped retry button variant.
class _BalanceRetry extends ConsumerWidget {
  const _BalanceRetry();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OutlinedButton(
      onPressed: () => ref.invalidate(myBalanceProvider),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Colors.white54),
      ),
      child: const Text('Retry'),
    );
  }
}

// ============================================
// REQUEST WITHDRAWAL BUTTON
// ============================================

class _RequestButton extends ConsumerWidget {
  const _RequestButton({required this.balance});

  final AsyncValue<DriverBalance> balance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final available = balance.valueOrNull?.available ?? 0;
    final enabled = available > 0;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: enabled
            ? () => _openForm(context, ref, available)
            : null,
        icon: const Icon(Icons.payments_outlined),
        label: const Text('Request Withdrawal'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.textDark,
          disabledBackgroundColor: AppColors.disabled,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _openForm(BuildContext context, WidgetRef ref, double available) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _WithdrawalForm(available: available),
    );
  }
}

// ============================================
// WITHDRAWAL FORM
// ============================================

class _WithdrawalForm extends ConsumerStatefulWidget {
  const _WithdrawalForm({required this.available});

  final double available;

  @override
  ConsumerState<_WithdrawalForm> createState() => _WithdrawalFormState();
}

class _WithdrawalFormState extends ConsumerState<_WithdrawalForm> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _accountCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  PayoutMethod _method = PayoutMethod.gcash;
  bool _submitting = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _accountCtrl.dispose();
    _nameCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  String get _accountLabel =>
      _method == PayoutMethod.bank ? 'Bank account number' : 'GCash/Maya number';

  String? _validateAmount(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return 'Enter an amount';
    final amount = double.tryParse(raw);
    if (amount == null) return 'Enter a valid amount';
    if (amount <= 0) return 'Amount must be greater than zero';
    if (amount > widget.available) {
      return 'Cannot exceed available (${_php.format(widget.available)})';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    final amount = double.parse(_amountCtrl.text.trim());
    final note = _noteCtrl.text.trim();

    try {
      await ref.read(payoutRepositoryProvider).requestWithdrawal(
            amount: amount,
            method: _method,
            account: _accountCtrl.text.trim(),
            name: _nameCtrl.text.trim(),
            note: note.isEmpty ? null : note,
          );

      if (!mounted) return;
      ref.invalidate(myBalanceProvider);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Withdrawal request submitted'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit request: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: 20 + bottomInset,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Request Withdrawal',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Available: ${_php.format(widget.available)}',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textMedium,
              ),
            ),
            const SizedBox(height: 20),

            // Amount
            TextFormField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              enabled: !_submitting,
              validator: _validateAmount,
              decoration: InputDecoration(
                labelText: 'Amount',
                prefixText: '₱ ',
                helperText: 'Available: ${_php.format(widget.available)}',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Payout method
            const Text(
              'Payout Method',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textMedium,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: PayoutMethod.values.map((m) {
                final selected = m == _method;
                return ChoiceChip(
                  label: Text(m.displayName),
                  selected: selected,
                  onSelected: _submitting
                      ? null
                      : (_) => setState(() => _method = m),
                  selectedColor: AppColors.accent,
                  labelStyle: TextStyle(
                    color: selected ? AppColors.textDark : AppColors.textMedium,
                    fontWeight: FontWeight.w600,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Account number
            TextFormField(
              controller: _accountCtrl,
              enabled: !_submitting,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
              decoration: InputDecoration(
                labelText: _accountLabel,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Account name
            TextFormField(
              controller: _nameCtrl,
              enabled: !_submitting,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
              decoration: const InputDecoration(
                labelText: 'Account name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Note
            TextFormField(
              controller: _noteCtrl,
              enabled: !_submitting,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.textDark,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.textDark,
                        ),
                      )
                    : const Text(
                        'Submit Request',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================
// HISTORY LIST
// ============================================

class _HistoryList extends StatelessWidget {
  const _HistoryList({required this.withdrawals});

  final AsyncValue<List<Withdrawal>> withdrawals;

  @override
  Widget build(BuildContext context) {
    return withdrawals.when(
      data: (list) {
        if (list.isEmpty) return const _EmptyHistory();
        return Column(
          children: list
              .map((w) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _WithdrawalCard(withdrawal: w),
                  ))
              .toList(),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, __) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Could not load history: $e',
          style: const TextStyle(color: AppColors.error),
        ),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border.withOpacity(0.4)),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 40,
            color: AppColors.textLight,
          ),
          SizedBox(height: 12),
          Text(
            'No withdrawals yet',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Request a withdrawal to cash out your available balance',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textMedium),
          ),
        ],
      ),
    );
  }
}

class _WithdrawalCard extends StatelessWidget {
  const _WithdrawalCard({required this.withdrawal});

  final Withdrawal withdrawal;

  @override
  Widget build(BuildContext context) {
    final w = withdrawal;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => WithdrawalDetailScreen(withdrawal: w),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border.withOpacity(0.4)),
          boxShadow: [
            BoxShadow(
              color: AppColors.textDark.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _php.format(w.amount),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${w.payoutMethod.displayName} · ${_maskAccount(w.payoutAccount)}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textMedium,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _dateShortFmt.format(w.requestedAt),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textLight,
                    ),
                  ),
                ],
              ),
            ),
            WithdrawalStatusPill(status: w.status),
          ],
        ),
      ),
    );
  }
}

// ============================================
// WITHDRAWAL DETAIL
// ============================================

class WithdrawalDetailScreen extends ConsumerWidget {
  const WithdrawalDetailScreen({super.key, required this.withdrawal});

  final Withdrawal withdrawal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = withdrawal;
    final events = ref.watch(withdrawalEventsProvider(w.id));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Withdrawal Details')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Amount + status
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border.withOpacity(0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _php.format(w.amount),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    WithdrawalStatusPill(status: w.status),
                  ],
                ),
                const SizedBox(height: 16),
                _detailRow('Payout method', w.payoutMethod.displayName),
                _detailRow('Account number', w.payoutAccount),
                _detailRow('Account name', w.payoutName),
                _detailRow('Requested', _dateFmt.format(w.requestedAt)),
                if (w.note != null && w.note!.isNotEmpty)
                  _detailRow('Note', w.note!),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Cancel (pending only) — driver can withdraw their own request
          if (w.status == WithdrawalStatus.pending) ...[
            _CancelWithdrawalButton(withdrawalId: w.id),
            const SizedBox(height: 16),
          ],

          // Reject reason
          if (w.status == WithdrawalStatus.rejected &&
              w.rejectReason != null) ...[
            _InfoBox(
              icon: Icons.cancel_outlined,
              color: AppColors.error,
              title: 'Rejected',
              body: w.rejectReason!,
            ),
            const SizedBox(height: 16),
          ],

          // Reference number (paid)
          if (w.status == WithdrawalStatus.paid &&
              w.referenceNumber != null) ...[
            _InfoBox(
              icon: Icons.check_circle_outline,
              color: AppColors.success,
              title: 'Paid',
              body: 'Reference: ${w.referenceNumber}',
            ),
            const SizedBox(height: 16),
          ],

          // Proof image
          if (w.proofUrl != null) ...[
            const Text(
              'Payment Proof',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            _ProofImage(path: w.proofUrl!),
            const SizedBox(height: 16),
          ],

          // Audit timeline
          const Text(
            'Activity',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 12),
          events.when(
            data: (list) {
              if (list.isEmpty) {
                return const Text(
                  'No activity recorded',
                  style: TextStyle(color: AppColors.textMedium),
                );
              }
              return _Timeline(events: list);
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, __) => Text(
              'Could not load activity: $e',
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textMedium,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Outlined "Cancel Request" button for a pending withdrawal.
class _CancelWithdrawalButton extends ConsumerStatefulWidget {
  const _CancelWithdrawalButton({required this.withdrawalId});

  final String withdrawalId;

  @override
  ConsumerState<_CancelWithdrawalButton> createState() =>
      _CancelWithdrawalButtonState();
}

class _CancelWithdrawalButtonState
    extends ConsumerState<_CancelWithdrawalButton> {
  bool _busy = false;

  Future<void> _cancel() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel withdrawal?'),
        content: const Text(
          'This request will be cancelled and the amount returned to your '
          'available balance.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Cancel request',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref
          .read(payoutRepositoryProvider)
          .cancelWithdrawal(widget.withdrawalId);
      if (!mounted) return;
      ref.invalidate(myBalanceProvider);
      navigator.pop(); // back to the wallet; the stream updates the list
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Withdrawal cancelled'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not cancel: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _busy ? null : _cancel,
        icon: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.close, size: 18),
        label: Text(_busy ? 'Cancelling…' : 'Cancel Request'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.error,
          side: BorderSide(color: AppColors.error.withOpacity(0.5)),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProofImage extends ConsumerWidget {
  const _ProofImage({required this.path});

  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<String>(
      future: ref.read(payoutRepositoryProvider).signedProofUrl(path),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Container(
            height: 120,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              'Could not load proof',
              style: TextStyle(color: AppColors.textMedium),
            ),
          );
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.network(
            snapshot.data!,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              );
            },
            errorBuilder: (_, __, ___) => Container(
              height: 120,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'Could not load proof',
                style: TextStyle(color: AppColors.textMedium),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Vertical audit timeline of withdrawal events (oldest first).
class _Timeline extends StatelessWidget {
  const _Timeline({required this.events});

  final List<WithdrawalEvent> events;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(events.length, (i) {
        final e = events[i];
        final isLast = i == events.length - 1;
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.white, width: 2),
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        color: AppColors.border,
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _eventLabel(e.event),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _dateFmt.format(e.createdAt),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textLight,
                        ),
                      ),
                      if (e.note != null && e.note!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          e.note!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textMedium,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

// ============================================
// HELPERS
// ============================================

/// A pill-shaped widget to display a [WithdrawalStatus].
class WithdrawalStatusPill extends StatelessWidget {
  const WithdrawalStatusPill({super.key, required this.status});

  final WithdrawalStatus status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(
          color: fg,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  (Color, Color) get _colors {
    switch (status) {
      case WithdrawalStatus.pending:
        return (AppColors.statusPendingBg, AppColors.statusPendingText);
      case WithdrawalStatus.approved:
        return (AppColors.statusInProgressBg, AppColors.statusInProgressText);
      case WithdrawalStatus.rejected:
        return (AppColors.statusCancelledBg, AppColors.statusCancelledText);
      case WithdrawalStatus.paid:
        return (AppColors.statusConfirmedBg, AppColors.statusConfirmedText);
      case WithdrawalStatus.cancelled:
        return (AppColors.statusCompletedBg, AppColors.statusCompletedText);
    }
  }
}

/// Mask all but the last 4 characters of a payout account.
String _maskAccount(String account) {
  final trimmed = account.trim();
  if (trimmed.length <= 4) return trimmed;
  final visible = trimmed.substring(trimmed.length - 4);
  return '•••• $visible';
}

/// Turn a raw event key (e.g. "requested") into a readable label.
String _eventLabel(String event) {
  switch (event.toLowerCase()) {
    case 'requested':
      return 'Requested';
    case 'approved':
      return 'Approved';
    case 'rejected':
      return 'Rejected';
    case 'paid':
      return 'Paid';
    default:
      final cleaned = event.replaceAll('_', ' ');
      if (cleaned.isEmpty) return cleaned;
      return cleaned[0].toUpperCase() + cleaned.substring(1);
  }
}
