import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../models/enums.dart';
import '../../../models/user.dart';
import '../../../repositories/admin_repository.dart';

/// Filter state for users
class UserFilter {
  final UserRole? role;
  final bool? isActive;
  final String searchQuery;

  const UserFilter({
    this.role,
    this.isActive,
    this.searchQuery = '',
  });

  UserFilter copyWith({
    UserRole? role,
    bool? isActive,
    String? searchQuery,
    bool clearRole = false,
    bool clearIsActive = false,
  }) {
    return UserFilter(
      role: clearRole ? null : (role ?? this.role),
      isActive: clearIsActive ? null : (isActive ?? this.isActive),
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

/// Provider for user filter state
final userFilterProvider = StateProvider<UserFilter>((ref) => const UserFilter());

/// Provider for filtered users
final adminUsersProvider = FutureProvider<List<User>>((ref) async {
  final repo = ref.watch(adminRepositoryProvider);
  final filter = ref.watch(userFilterProvider);

  return repo.getAllUsers(
    role: filter.role,
    isActive: filter.isActive,
    searchQuery: filter.searchQuery,
  );
});

/// Provider for user counts by role
final userCountsProvider = FutureProvider<Map<UserRole, int>>((ref) async {
  final repo = ref.watch(adminRepositoryProvider);
  return repo.getUserCountsByRole();
});

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final users = ref.watch(adminUsersProvider);
    final filter = ref.watch(userFilterProvider);
    final counts = ref.watch(userCountsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        actions: [
          IconButton(
            onPressed: () => _showFilterSheet(context),
            icon: Badge(
              isLabelVisible: filter.role != null || filter.isActive != null,
              child: const Icon(Icons.filter_list),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search users...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _searchController.clear();
                          ref.read(userFilterProvider.notifier).state =
                              filter.copyWith(searchQuery: '');
                        },
                        icon: const Icon(Icons.clear),
                      )
                    : null,
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                ref.read(userFilterProvider.notifier).state =
                    filter.copyWith(searchQuery: value);
              },
            ),
          ),

          // Role chips
          SizedBox(
            height: 40,
            child: counts.when(
              data: (countMap) => ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _buildRoleChip(
                    context,
                    label: 'All',
                    count: countMap.values.fold(0, (a, b) => a + b),
                    isSelected: filter.role == null,
                    onTap: () {
                      ref.read(userFilterProvider.notifier).state =
                          filter.copyWith(clearRole: true);
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildRoleChip(
                    context,
                    label: 'Customers',
                    count: countMap[UserRole.customer] ?? 0,
                    isSelected: filter.role == UserRole.customer,
                    onTap: () {
                      ref.read(userFilterProvider.notifier).state =
                          filter.copyWith(role: UserRole.customer);
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildRoleChip(
                    context,
                    label: 'Drivers',
                    count: countMap[UserRole.driver] ?? 0,
                    isSelected: filter.role == UserRole.driver,
                    onTap: () {
                      ref.read(userFilterProvider.notifier).state =
                          filter.copyWith(role: UserRole.driver);
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildRoleChip(
                    context,
                    label: 'Admins',
                    count: countMap[UserRole.admin] ?? 0,
                    isSelected: filter.role == UserRole.admin,
                    onTap: () {
                      ref.read(userFilterProvider.notifier).state =
                          filter.copyWith(role: UserRole.admin);
                    },
                  ),
                ],
              ),
              loading: () => const SizedBox(),
              error: (_, __) => const SizedBox(),
            ),
          ),

          const SizedBox(height: 8),

          // Users list
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(adminUsersProvider);
                ref.invalidate(userCountsProvider);
              },
              child: users.when(
                data: (userList) {
                  if (userList.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 64,
                            color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No users found',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Try adjusting your filters',
                            style: TextStyle(
                              fontSize: 14,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: userList.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final user = userList[index];
                      return _UserCard(
                        user: user,
                        onTap: () => context.push('/admin/users/${user.id}'),
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
                      const Text('Failed to load users'),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => ref.invalidate(adminUsersProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleChip(
    BuildContext context, {
    required String label,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary
              : colorScheme.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isSelected
                    ? colorScheme.onPrimary
                    : colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? colorScheme.onPrimary.withOpacity(0.2)
                    : colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? colorScheme.onPrimary
                      : colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterSheet(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final filter = ref.read(userFilterProvider);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          bool? selectedIsActive = filter.isActive;

          return Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Filters',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        ref.read(userFilterProvider.notifier).state =
                            const UserFilter();
                        Navigator.pop(context);
                      },
                      child: const Text('Clear all'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'Status',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildFilterChip(
                      context,
                      label: 'All',
                      isSelected: selectedIsActive == null,
                      onTap: () {
                        setSheetState(() => selectedIsActive = null);
                        ref.read(userFilterProvider.notifier).state =
                            filter.copyWith(clearIsActive: true);
                      },
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      context,
                      label: 'Active',
                      isSelected: selectedIsActive == true,
                      onTap: () {
                        setSheetState(() => selectedIsActive = true);
                        ref.read(userFilterProvider.notifier).state =
                            filter.copyWith(isActive: true);
                      },
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      context,
                      label: 'Inactive',
                      isSelected: selectedIsActive == false,
                      onTap: () {
                        setSheetState(() => selectedIsActive = false);
                        ref.read(userFilterProvider.notifier).state =
                            filter.copyWith(isActive: false);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Apply Filters'),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(
    BuildContext context, {
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary
              : colorScheme.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final User user;
  final VoidCallback onTap;

  const _UserCard({
    required this.user,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: colorScheme.outlineVariant.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 24,
              backgroundColor: _getRoleColor(user.role).withOpacity(0.1),
              backgroundImage: user.avatarUrl != null
                  ? NetworkImage(user.avatarUrl!)
                  : null,
              child: user.avatarUrl == null
                  ? Text(
                      user.initials,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _getRoleColor(user.role),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          user.fullName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _buildRoleBadge(context, user.role),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.email,
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (user.phone != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      user.phone!,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Status indicator
            Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: user.isActive
                        ? Colors.green
                        : colorScheme.onSurfaceVariant.withOpacity(0.3),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.isActive ? 'Active' : 'Inactive',
                  style: TextStyle(
                    fontSize: 10,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),

            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleBadge(BuildContext context, UserRole role) {
    final color = _getRoleColor(role);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        role.displayName,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return Colors.purple;
      case UserRole.driver:
        return Colors.blue;
      case UserRole.customer:
        return Colors.teal;
    }
  }
}
