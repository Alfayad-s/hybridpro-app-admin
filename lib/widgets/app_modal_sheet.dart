import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How many modal sheets are currently open (used to hide the shell nav + FAB).
final shellSheetDepthProvider =
    NotifierProvider<ShellSheetDepth, int>(ShellSheetDepth.new);

class ShellSheetDepth extends Notifier<int> {
  @override
  int build() => 0;

  void bump(int delta) {
    final next = (state + delta).clamp(0, 32);
    if (next != state) state = next;
  }
}

/// App-wide modal bottom sheet — hides the shell nav/FAB while open.
Future<T?> showAppModalBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Color? backgroundColor,
  Color? barrierColor,
  bool isScrollControlled = false,
  bool useSafeArea = false,
  bool isDismissible = true,
  bool enableDrag = true,
  bool? showDragHandle,
  AnimationController? transitionAnimationController,
  Offset? anchorPoint,
  ShapeBorder? shape,
  Clip? clipBehavior,
  BoxConstraints? constraints,
  double? elevation,
}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  container.read(shellSheetDepthProvider.notifier).bump(1);
  try {
    return await showModalBottomSheet<T>(
      context: context,
      builder: builder,
      backgroundColor: backgroundColor,
      barrierColor: barrierColor,
      isScrollControlled: isScrollControlled,
      useSafeArea: useSafeArea,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      showDragHandle: showDragHandle,
      transitionAnimationController: transitionAnimationController,
      anchorPoint: anchorPoint,
      shape: shape,
      clipBehavior: clipBehavior,
      constraints: constraints,
      elevation: elevation,
      useRootNavigator: true,
    );
  } finally {
    container.read(shellSheetDepthProvider.notifier).bump(-1);
  }
}
