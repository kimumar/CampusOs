import 'package:flutter/material.dart';

import 'campus_responsive.dart';

abstract final class CampusDialog {
  static Future<bool> confirm({
    required BuildContext context,
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final colors = Theme.of(dialogContext).colorScheme;

        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: CampusResponsive.dialogMaxWidth,
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(dialogContext)
                        .textTheme
                        .titleLarge,
                  ),
                  const SizedBox(height: 14),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Text(message),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      TextButton(
                        onPressed: () =>
                            Navigator.pop(
                              dialogContext,
                              false,
                            ),
                        child: Text(cancelLabel),
                      ),
                      FilledButton(
                        style: destructive
                            ? FilledButton.styleFrom(
                                backgroundColor:
                                    colors.error,
                                foregroundColor:
                                    colors.onError,
                              )
                            : null,
                        onPressed: () =>
                            Navigator.pop(
                              dialogContext,
                              true,
                            ),
                        child: Text(confirmLabel),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    return result ?? false;
  }
}