import 'dart:math' as math;

import 'package:flutter/material.dart';

class CampusFormSheet extends StatelessWidget {
  const CampusFormSheet({
    super.key,
    required this.title,
    required this.child,
    required this.primaryLabel,
    required this.onPrimaryPressed,
    this.subtitle,
    this.isSaving = false,
    this.secondaryLabel = 'Cancel',
    this.onSecondaryPressed,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final String primaryLabel;
  final VoidCallback? onPrimaryPressed;
  final bool isSaving;
  final String secondaryLabel;
  final VoidCallback? onSecondaryPressed;

  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: builder,
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboardHeight = media.viewInsets.bottom;

    final usableHeight = math.max(
      0.0,
      media.size.height -
          media.padding.top -
          keyboardHeight,
    );

    final sheetHeight = usableHeight * 0.90;

    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardHeight),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          width: double.infinity,
          height: sheetHeight,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 560,
              ),
              child: Material(
                color: colors.surface,
                clipBehavior: Clip.antiAlias,
                borderRadius:
                    const BorderRadius.vertical(
                  top: Radius.circular(26),
                ),
                child: Column(
                  children: [
                    // Fixed header.
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        20, 12, 12, 8,
                      ),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 38,
                              height: 5,
                              decoration: BoxDecoration(
                                color: colors.onSurface
                                    .withValues(alpha: 0.20),
                                borderRadius:
                                    BorderRadius.circular(10),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  style: theme
                                      .textTheme.headlineSmall
                                      ?.copyWith(
                                        fontWeight:
                                            FontWeight.w800,
                                      ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Close',
                                onPressed: isSaving
                                    ? null
                                    : () =>
                                        Navigator.pop(context),
                                icon: const Icon(
                                  Icons.close_rounded,
                                ),
                              ),
                            ],
                          ),
                          if (subtitle != null)
                            Text(
                              subtitle!,
                              style: theme.textTheme.bodyMedium,
                            ),
                        ],
                      ),
                    ),

                    // Scrollable form content.
                    Expanded(
                      child: SingleChildScrollView(
                        primary: false,
                        physics:
                            const ClampingScrollPhysics(),
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior
                                .onDrag,
                        padding: const EdgeInsets.fromLTRB(
                          20, 12, 20, 24,
                        ),
                        child: child,
                      ),
                    ),

                    // Fixed footer.
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(
                        20, 12, 20, 12,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        border: Border(
                          top: BorderSide(
                            color: colors.outlineVariant,
                          ),
                        ),
                      ),
                      child: SafeArea(
                        top: false,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: isSaving
                                    ? null
                                    : onPrimaryPressed,
                                icon: isSaving
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child:
                                            CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.check_rounded,
                                      ),
                                label: Text(
                                  isSaving
                                      ? 'Saving...'
                                      : primaryLabel,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: isSaving
                                  ? null
                                  : onSecondaryPressed ??
                                      () =>
                                          Navigator.pop(context),
                              child: Text(secondaryLabel),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}