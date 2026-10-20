import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_controls.dart';

ButtonStyle _toolbarStyle({bool selected = false}) => IconButton.styleFrom(
  backgroundColor: selected ? AppColors.primaryGreen : Colors.white,
  foregroundColor: selected ? Colors.white : AppColors.primaryGreen,
  side: BorderSide(
    color: selected ? AppColors.primaryGreen : AppColors.dividerColor,
  ),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  minimumSize: const Size(48, 48),
);

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget? leading;
  final bool showSyncBadge;
  final bool isOnline;

  const CustomAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.leading,
    this.showSyncBadge = false,
    this.isOnline = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) => AppBar(
    toolbarHeight: 64,
    title: _AppBarHeading(
      title: title,
      subtitle: subtitle,
      showSyncBadge: showSyncBadge,
      isOnline: isOnline,
    ),
    leading: leading,
    actions: actions,
  );
}

class TopBarActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const TopBarActionButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: SizedBox(
        width: 48,
        height: 48,
        child: IconButton(
          tooltip: tooltip,
          style: _toolbarStyle(),
          onPressed: onTap,
          icon: Icon(icon, size: 22),
        ),
      ),
    ),
  );
}

class TopBarBackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  const TopBarBackButton({super.key, this.onPressed});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.only(left: 8),
      child: SizedBox(
        width: 48,
        height: 48,
        child: IconButton(
          tooltip: 'Kembali',
          style: _toolbarStyle(),
          onPressed: onPressed ?? () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded, size: 22),
        ),
      ),
    ),
  );
}

class SliverCustomAppBar extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget>? actions;
  final bool showSyncBadge;
  final bool isOnline;
  final Widget? statusBadge;
  final bool isSearch;
  final TextEditingController? searchController;
  final String? searchHint;
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback? onSearchClear;
  final VoidCallback? onFilterTap;
  final bool hasActiveFilter;
  final bool floating;
  final bool snap;
  final bool pinned;

  const SliverCustomAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions,
    this.showSyncBadge = false,
    this.isOnline = true,
    this.statusBadge,
    this.floating = true,
    this.snap = true,
    this.pinned = false,
  }) : isSearch = false,
       searchController = null,
       searchHint = null,
       onSearchChanged = null,
       onSearchClear = null,
       onFilterTap = null,
       hasActiveFilter = false;

  const SliverCustomAppBar.search({
    super.key,
    required this.searchController,
    this.searchHint = 'Cari...',
    this.onSearchChanged,
    this.onSearchClear,
    this.onFilterTap,
    this.hasActiveFilter = false,
    this.actions,
    this.leading,
    this.floating = true,
    this.snap = true,
    this.pinned = false,
  }) : title = null,
       subtitle = null,
       showSyncBadge = false,
       isOnline = true,
       statusBadge = null,
       isSearch = true;

  Widget _buildSearchTitle(BuildContext context) => Row(
    children: [
      Expanded(
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.dividerColor),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const SizedBox(width: 12),
              const Icon(
                Icons.search_rounded,
                size: 22,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: searchController,
                  onChanged: onSearchChanged,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: searchHint,
                    hintStyle: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    isDense: true,
                    filled: false,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              if (searchController != null && searchController!.text.isNotEmpty)
                IconButton(
                  tooltip: 'Hapus pencarian',
                  onPressed: () {
                    searchController!.clear();
                    onSearchClear?.call();
                    onSearchChanged?.call('');
                  },
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
            ],
          ),
        ),
      ),
      if (onFilterTap != null) ...[
        const SizedBox(width: 8),
        SizedBox(
          width: 48,
          height: 48,
          child: IconButton(
            tooltip: hasActiveFilter
                ? 'Filter aktif · ubah filter'
                : 'Filter & urutkan',
            style: _toolbarStyle(selected: hasActiveFilter),
            onPressed: onFilterTap,
            icon: const Icon(Icons.tune_rounded, size: 22),
          ),
        ),
      ],
    ],
  );

  Widget _wrapAction(Widget action) {
    if (action is IconButton &&
        action.onPressed != null &&
        action.icon is Icon) {
      return TopBarActionButton(
        icon: (action.icon as Icon).icon ?? Icons.circle,
        tooltip: action.tooltip ?? '',
        onTap: action.onPressed!,
      );
    }
    return action;
  }

  @override
  Widget build(BuildContext context) {
    final effectiveLeading =
        leading ??
        (ModalRoute.of(context)?.canPop == true
            ? const TopBarBackButton()
            : null);
    return SliverAppBar(
      floating: floating,
      snap: snap,
      pinned: pinned,
      backgroundColor: AppColors.surfaceBackground,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 72,
      automaticallyImplyLeading: false,
      leadingWidth: effectiveLeading != null ? 64 : 0,
      leading: effectiveLeading,
      titleSpacing: effectiveLeading != null ? 8 : 16,
      title: isSearch
          ? _buildSearchTitle(context)
          : _AppBarHeading(
              title: title ?? '',
              subtitle: subtitle,
              showSyncBadge: showSyncBadge,
              isOnline: isOnline,
              statusBadge: statusBadge,
            ),
      actions: actions == null
          ? null
          : [...actions!.map(_wrapAction), const SizedBox(width: 8)],
    );
  }
}

class _AppBarHeading extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool showSyncBadge;
  final bool isOnline;
  final Widget? statusBadge;
  const _AppBarHeading({
    required this.title,
    this.subtitle,
    this.showSyncBadge = false,
    this.isOnline = true,
    this.statusBadge,
  });

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          if (showSyncBadge) ...[
            const SizedBox(width: 8),
            AppBadge(
              label: isOnline ? 'Online' : 'Offline',
              tone: isOnline ? AppBadgeTone.positive : AppBadgeTone.warning,
            ),
          ],
          if (statusBadge != null) ...[const SizedBox(width: 8), statusBadge!],
        ],
      ),
      if (subtitle != null && subtitle!.isNotEmpty) ...[
        const SizedBox(height: 3),
        Text(
          subtitle!,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    ],
  );
}

class ScreenContextBar extends StatelessWidget {
  final IconData? leadingIcon;
  final String? leadingText;
  final Widget? leading;
  final Widget? trailing;
  final bool showBottomBorder;
  final EdgeInsetsGeometry padding;
  const ScreenContextBar({
    super.key,
    this.leadingIcon,
    this.leadingText,
    this.leading,
    this.trailing,
    this.showBottomBorder = false,
    this.padding = const EdgeInsets.fromLTRB(16, 10, 16, 6),
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      border: showBottomBorder
          ? const Border(bottom: BorderSide(color: AppColors.dividerColor))
          : null,
    ),
    child: Row(
      children: [
        Expanded(
          child:
              leading ??
              Row(
                children: [
                  if (leadingIcon != null) ...[
                    Icon(leadingIcon, size: 20, color: AppColors.primaryGreen),
                    const SizedBox(width: 8),
                  ],
                  if (leadingText != null)
                    Flexible(
                      child: Text(
                        leadingText!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
        ),
        if (trailing != null) ...[const SizedBox(width: 12), trailing!],
      ],
    ),
  );
}
