import 'dart:async';

/// Combines several streams of the same type, emitting the latest value of
/// every source each time any of them emits (combineLatest semantics).
///
/// Intended for drift `watch()` streams, which do not complete.
Stream<List<T>> combineLatestStream<T>(List<Stream<T>> streams) {
  final controller = StreamController<List<T>>();
  final latest = List<T?>.filled(streams.length, null);
  final seen = List<bool>.filled(streams.length, false);
  final subscriptions = <StreamSubscription<T>>[];

  controller.onListen = () {
    for (var i = 0; i < streams.length; i++) {
      subscriptions.add(
        streams[i].listen(
          (value) {
            latest[i] = value;
            seen[i] = true;
            if (seen.every((s) => s) && !controller.isClosed) {
              controller.add(List<T>.unmodifiable(latest));
            }
          },
          onError: controller.addError,
        ),
      );
    }
  };

  controller.onCancel = () async {
    for (final sub in subscriptions) {
      await sub.cancel();
    }
    subscriptions.clear();
    if (!controller.isClosed) {
      await controller.close();
    }
  };

  return controller.stream;
}
