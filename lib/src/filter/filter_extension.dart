import 'dart:async';

import 'package:stream_action_events/stream_action_events.dart';

extension FilterExtension<T> on Stream<StreamItemEvent<T>> {
  /// Filters the stream using the provided [filter] function.
  ///
  /// The [filter] function takes an item of type [T] and returns a boolean
  /// indicating whether the item should be included in the output stream.
  ///
  /// This extension method is necessary because the built-in [where] method
  /// does not handle visibility transitions. When an item changes from visible
  /// to invisible (or vice versa) due to the filter, the correct event must be
  /// emitted: a [StreamDeleteEvent] when an item becomes invisible, and a
  /// [StreamFetchEvent] when an item becomes visible. This ensures the output
  /// stream accurately reflects the filtered state of the items.
  ///
  Stream<StreamItemEvent<T>> filter(
    bool Function(T item)? filter,
  ) {
    // If filter is null, simply return the original stream
    if (filter == null) {
      return this;
    }

    // Create a stream controller
    StreamController<StreamItemEvent<T>> streamController =
        StreamController<StreamItemEvent<T>>();

    // Input stream subscription
    StreamSubscription<StreamItemEvent<T>>? inputStreamSubscription;

    // When the output stream is cancelled, close the stream controller
    streamController.onCancel = () {
      inputStreamSubscription?.cancel();
      inputStreamSubscription = null;
      streamController.close();
    };

    // When the output stream is listened to, listen to the input stream and
    // process the events using the stream parts
    streamController.onListen = () {
      // Create a set to keep track of visible items
      Set<T> visibleItems = <T>{};

      // Listen to the item events
      inputStreamSubscription = listen(
        (StreamItemEvent<T> event) {
          bool visibleBeforeFilter = visibleItems.contains(event.item);
          bool visibleAfterFilter =
              event is! StreamDeleteEvent<T> && filter(event.item);
          if (visibleAfterFilter) {
            visibleItems.add(event.item);
            // If an item changes from invisible to visible, and it is a
            // StreamChangeEvent, convert it to a StreamFetchEvent.
            if (!visibleBeforeFilter && event is StreamChangeEvent<T>) {
              streamController.add(
                StreamFetchEvent<T>(
                  item: event.item,
                  isLast: event.isLast,
                ),
              );
            } else {
              // Otherwise, simply forward the event to the stream controller.
              streamController.add(event);
            }
          } else if (visibleBeforeFilter) {
            visibleItems.remove(event.item);
            // If an item changes from visible to invisible, add a
            // StreamDeleteEvent to the output stream.
            streamController.add(
              StreamDeleteEvent<T>(item: event.item),
            );
          } else {
            // Do nothing if the item is not visible before or after the filter
          }
        },
        onError: (
          Object error,
          StackTrace? stackTrace,
        ) {
          // Forward any errors
          streamController.addError(
            error,
            stackTrace,
          );
        },
      );
    };

    return streamController.stream;
  }
}
