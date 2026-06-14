import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/enums.dart';
import '../../../models/withdrawal.dart';
import '../../../providers/payout_provider.dart';
import '../../../repositories/payout_repository.dart';

/// Admin screen for reviewing driver payout (withdrawal) requests:
/// approve / reject / mark-paid plus an audit timeline. (PO-20..24)
class AdminWithdrawalsScreen extends ConsumerStatefulWidget {
  const AdminWithdrawalsScreen({super.key});

  @override
  ConsumerState<AdminWithdrawalsScreen> createState() =>
      _AdminWithdrawalsScreenState();
}

class _AdminWithdrawalsScreenState extends ConsumerState<AdminWithdrawalsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const _tabs = [
    (label: 'Pending', status: WithdrawalStatus.pending),
    (label: 'Approved', status: WithdrawalStatus.approved),
    (label: 'Rejected', status: WithdrawalStatus.rejected),
    (label: 'Paid', status: WithdrawalStatus.paid),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Payouts'),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: colorScheme.primary,
          unselectedLabelColor: colorScheme.onSurfaceVariant,
          indicatorColor: colorScheme.primary,
          tabs: _tabs.map((t) => Tab(text: t.label)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children:
            _tabs.map((t) => _WithdrawalsList(status: t.status)).toList(),
      ),
    );
  }
}

class _WithdrawalsList extends ConsumerWidget {
  final WithdrawalStatus status;

  const _WithdrawalsList({required this.status});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final async = ref.watch(adminWithdrawalsProvider(status));

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(adminWithdrawalsProvider(status)),
      child: async.when(
        data: (items) {
          if (items.isEmpty) {
            return _EmptyState(status: status);
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = items[index];
              return _WithdrawalCard(
                withdrawal: item.withdrawal,
                driverName: item.driverName,
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: colorScheme.error),
              const SizedBox(height: 16),
              const Text('Failed to load payouts'),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () =>
                    ref.invalidate(adminWithdrawalsProvider(status)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final WithdrawalStatus status;

  const _EmptyState({required this.status});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // Render inside a scrollable so pull-to-refresh works on empty tabs.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 64,
                  color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'No ${status.displayName.toLowerCase()} payouts',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Requests will appear here',
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================
// STATUS PILL
// ============================================

({Color bg, Color fg}) _statusColors(WithdrawalStatus status) {
  switch (status) {
    case WithdrawalStatus.pending:
      return (bg: AppColors.warningLight, fg: AppColors.accentDark);
    case WithdrawalStatus.approved:
      return (bg: AppColors.infoLight, fg: AppColors.info);
    case WithdrawalStatus.rejected:
      return (bg: AppColors.errorLight, fg: AppColors.error);
    case WithdrawalStatus.paid:
      return (bg: AppColors.successLight, fg: AppColors.success);
  }
}

class _StatusPill extends StatelessWidget {
  final WithdrawalStatus status;

  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final c = _statusColors(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: c.fg,
        ),
      ),
    );
  }
}

// ============================================
// CARD
// ============================================

final _peso = NumberFormat.currency(locale: 'en_PH', symbol: '₱');
final _dateFmt = DateFormat('MMM d, y • h:mm a');

class _WithdrawalCard extends ConsumerWidget {
  final Withdrawal withdrawal;
  final String driverName;

  const _WithdrawalCard({required this.withdrawal, required this.driverName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final w = withdrawal;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _showDetail(context, ref, w, driverName),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    driverName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _StatusPill(status: w.status),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _peso.format(w.amount),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.account_balance_wallet_outlined,
              text: '${w.payoutMethod.displayName} • ${w.payoutAccount}',
            ),
            const SizedBox(height: 4),
            _InfoRow(icon: Icons.person_outline, text: w.payoutName),
            const SizedBox(height: 4),
            _InfoRow(
              icon: Icons.schedule,
              text: _dateFmt.format(w.requestedAt.toLocal()),
            ),
            if (w.status == WithdrawalStatus.rejected &&
                (w.rejectReason?.isNotEmpty ?? false)) ...[
              const SizedBox(height: 8),
              _InfoRow(
                icon: Icons.cancel_outlined,
                text: w.rejectReason!,
                color: AppColors.error,
              ),
            ],
            if (w.status == WithdrawalStatus.paid &&
                (w.referenceNumber?.isNotEmpty ?? false)) ...[
              const SizedBox(height: 8),
              _InfoRow(
                icon: Icons.confirmation_number_outlined,
                text: 'Ref: ${w.referenceNumber}',
              ),
            ],
            const SizedBox(height: 12),
            _CardActions(withdrawal: w),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;

  const _InfoRow({required this.icon, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final c = color ?? colorScheme.onSurfaceVariant;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: c),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: TextStyle(fontSize: 13, color: c)),
        ),
      ],
    );
  }
}

// ============================================
// CARD ACTIONS (status dependent)
// ============================================

class _CardActions extends ConsumerWidget {
  final Withdrawal withdrawal;

  const _CardActions({required this.withdrawal});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (withdrawal.status) {
      case WithdrawalStatus.pending:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _reject(context, ref, withdrawal.id),
                icon: const Icon(Icons.close, size: 18),
                label: const Text('Reject'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _approve(context, ref, withdrawal.id),
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Approve'),
              ),
            ),
          ],
        );
      case WithdrawalStatus.approved:
        return SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => _markPaidFlow(context, ref, withdrawal.id),
            icon: const Icon(Icons.payments_outlined, size: 18),
            label: const Text('Mark as Paid'),
          ),
        );
      case WithdrawalStatus.paid:
        return SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: withdrawal.proofUrl == null
                ? null
                : () => _viewProof(context, ref, withdrawal.proofUrl!),
            icon: const Icon(Icons.image_outlined, size: 18),
            label: const Text('View Proof'),
          ),
        );
      case WithdrawalStatus.rejected:
        return const SizedBox.shrink();
    }
  }
}

// ============================================
// ACTIONS
// ============================================

void _invalidateAll(WidgetRef ref) {
  for (final s in WithdrawalStatus.values) {
    ref.invalidate(adminWithdrawalsProvider(s));
  }
  ref.invalidate(adminWithdrawalsProvider(null));
}

void _snack(BuildContext context, String message, {bool error = false}) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: error ? AppColors.error : AppColors.success,
    ),
  );
}

Future<void> _approve(BuildContext context, WidgetRef ref, String id) async {
  try {
    await ref.read(payoutRepositoryProvider).approve(id);
    _invalidateAll(ref);
    _snack(context, 'Payout approved');
  } catch (e) {
    _snack(context, 'Failed to approve: $e', error: true);
  }
}

Future<void> _reject(BuildContext context, WidgetRef ref, String id) async {
  final controller = TextEditingController();
  final reason = await showDialog<String>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          final canSubmit = controller.text.trim().isNotEmpty;
          return AlertDialog(
            title: const Text('Reject Payout'),
            content: TextField(
              controller: controller,
              autofocus: true,
              maxLines: 3,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Reason',
                hintText: 'Why is this payout being rejected?',
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: canSubmit
                    ? () => Navigator.pop(context, controller.text.trim())
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.error,
                ),
                child: const Text('Reject'),
              ),
            ],
          );
        },
      );
    },
  );

  if (reason == null) return;
  try {
    await ref.read(payoutRepositoryProvider).reject(id, reason);
    _invalidateAll(ref);
    _snack(context, 'Payout rejected');
  } catch (e) {
    _snack(context, 'Failed to reject: $e', error: true);
  }
}

Future<void> _markPaidFlow(
    BuildContext context, WidgetRef ref, String id) async {
  final paid = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _MarkPaidDialog(withdrawalId: id),
  );
  if (paid == true) {
    _invalidateAll(ref);
    _snack(context, 'Payout marked as paid');
  }
}

Future<void> _viewProof(
    BuildContext context, WidgetRef ref, String proofPath) async {
  showDialog(
    context: context,
    builder: (dialogContext) => Dialog(
      child: FutureBuilder<String>(
        future: ref.read(payoutRepositoryProvider).signedProofUrl(proofPath),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const SizedBox(
              height: 200,
              child: Center(child: Text('Could not load proof')),
            );
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: InteractiveViewer(
                  child: Image.network(
                    snapshot.data!,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox(
                      height: 200,
                      child: Center(child: Text('Could not load image')),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Close'),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

// ============================================
// MARK PAID DIALOG (upload proof + reference)
// ============================================

class _MarkPaidDialog extends ConsumerStatefulWidget {
  final String withdrawalId;

  const _MarkPaidDialog({required this.withdrawalId});

  @override
  ConsumerState<_MarkPaidDialog> createState() => _MarkPaidDialogState();
}

class _MarkPaidDialogState extends ConsumerState<_MarkPaidDialog> {
  final _referenceController = TextEditingController();
  Uint8List? _proofBytes;
  String? _proofFileName;
  bool _submitting = false;

  @override
  void dispose() {
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _pickProof() async {
    final picked =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _proofBytes = bytes;
      _proofFileName = picked.name;
    });
  }

  Future<void> _confirm() async {
    final bytes = _proofBytes;
    final reference = _referenceController.text.trim();
    if (bytes == null || reference.isEmpty) return;

    setState(() => _submitting = true);
    try {
      final repo = ref.read(payoutRepositoryProvider);
      final path = await repo.uploadProof(
        bytes,
        fileExt: 'jpg',
        contentType: 'image/jpeg',
      );
      await repo.markPaid(
        widget.withdrawalId,
        reference: reference,
        proofPath: path,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to mark paid: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final canConfirm = _proofBytes != null &&
        _referenceController.text.trim().isNotEmpty &&
        !_submitting;

    return AlertDialog(
      title: const Text('Mark as Paid'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Proof screenshot',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _submitting ? null : _pickProof,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 140,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colorScheme.outlineVariant,
                  ),
                ),
                child: _proofBytes == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 32,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap to select screenshot',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          _proofBytes!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                      ),
              ),
            ),
            if (_proofFileName != null) ...[
              const SizedBox(height: 4),
              Text(
                _proofFileName!,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _referenceController,
              enabled: !_submitting,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Reference number',
                hintText: 'Transaction reference',
                border: OutlineInputBorder(),
              ),
            ),
            if (_submitting) ...[
              const SizedBox(height: 16),
              const Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('Uploading proof...'),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: canConfirm ? _confirm : null,
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}

// ============================================
// DETAIL + AUDIT TIMELINE
// ============================================

void _showDetail(
  BuildContext context,
  WidgetRef ref,
  Withdrawal w,
  String driverName,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _WithdrawalDetailSheet(
      withdrawal: w,
      driverName: driverName,
    ),
  );
}

class _WithdrawalDetailSheet extends ConsumerWidget {
  final Withdrawal withdrawal;
  final String driverName;

  const _WithdrawalDetailSheet({
    required this.withdrawal,
    required this.driverName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final w = withdrawal;
    final events = ref.watch(withdrawalEventsProvider(w.id));

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  driverName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _StatusPill(status: w.status),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _peso.format(w.amount),
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 20),
          _DetailRow(label: 'Method', value: w.payoutMethod.displayName),
          _DetailRow(label: 'Account', value: w.payoutAccount),
          _DetailRow(label: 'Account name', value: w.payoutName),
          _DetailRow(
            label: 'Requested',
            value: _dateFmt.format(w.requestedAt.toLocal()),
          ),
          if (w.note?.isNotEmpty ?? false)
            _DetailRow(label: 'Note', value: w.note!),
          if (w.referenceNumber?.isNotEmpty ?? false)
            _DetailRow(label: 'Reference', value: w.referenceNumber!),
          if (w.rejectReason?.isNotEmpty ?? false)
            _DetailRow(
              label: 'Reject reason',
              value: w.rejectReason!,
              valueColor: AppColors.error,
            ),
          const SizedBox(height: 24),
          Text(
            'Audit Timeline',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          events.when(
            data: (list) {
              if (list.isEmpty) {
                return Text(
                  'No events recorded',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                );
              }
              return Column(
                children: [
                  for (var i = 0; i < list.length; i++)
                    _TimelineTile(
                      event: list[i],
                      isLast: i == list.length - 1,
                    ),
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => Text(
              'Failed to load timeline',
              style: TextStyle(color: colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: valueColor ?? colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  final WithdrawalEvent event;
  final bool isLast;

  const _TimelineTile({required this.event, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: colorScheme.outlineVariant,
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
                    _humanizeEvent(event.event),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _dateFmt.format(event.createdAt.toLocal()),
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (event.actorId != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'By: ${event.actorId}',
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurfaceVariant.withOpacity(0.8),
                      ),
                    ),
                  ],
                  if (event.note?.isNotEmpty ?? false) ...[
                    const SizedBox(height: 2),
                    Text(
                      event.note!,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
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
  }

  String _humanizeEvent(String event) {
    final cleaned = event.replaceAll('_', ' ').trim();
    if (cleaned.isEmpty) return event;
    return cleaned[0].toUpperCase() + cleaned.substring(1);
  }
}
