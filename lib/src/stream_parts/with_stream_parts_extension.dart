import 'dart:async';
import 'dart:core';

import 'package:test_repo_1/src/stream_parts/stream_part.dart';
import 'package:stream_action_events/stream_action_events.dart';

/// Composes and returns a modified stream from an item event stream by applying
/// a list of [StreamPart]s.
///
/// The [withStreamParts] function transforms the stream by applying each
/// [StreamPart]. Each [StreamPart] defines how to obtain a child or property
/// stream and how to map and attach these objects to their parent items.
///
extension WithStreamPartsExtension<T> on Stream<StreamItemEvent<T>> {
  Stream<StreamItemEvent<T>> withStreamParts(
    List<StreamPart<T, Object>> streamParts,
  ) {
    // Create a stream controller
    StreamController<StreamItemEvent<T>> streamController =
        StreamController<StreamItemEvent<T>>();

    // Input stream subscription
    StreamSubscription<StreamItemEvent<T>>? inputStreamSubscription;

    // Child stream subscriptions
    List<StreamSubscription<StreamItemEvent<Object>>> childStreamSubscriptions =
        <StreamSubscription<StreamItemEvent<Object>>>[];

    // When the output stream is cancelled, close the stream controller
    streamController.onCancel = () {
      for (StreamSubscription<StreamItemEvent<Object>> subscription
          in childStreamSubscriptions) {
        subscription.cancel();
      }
      childStreamSubscriptions.clear();
      inputStreamSubscription?.cancel();
      inputStreamSubscription = null;
      streamController.close();
    };

    // When the output stream is listened to, listen to the input stream
    // and process the events using the stream parts
    streamController.onListen = () {
      // Listen to the item events
      inputStreamSubscription = listen(
        (StreamItemEvent<T> event) {
          // When an item event is received, use each stream part to process the
          // event. It serves as the "parent event" for the stream part.

          for (StreamPart<T, Object> streamPart in streamParts) {
            streamPart.processParentEvent(event);
          }

          // Add the event to the stream controller
          streamController.add(event);
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

      // TODO: Test whether it is beneficial to wait for the first event.isLast
      //  for cache strategy always.

      // Listen to the child events from each stream part
      for (final StreamPart<T, Object> streamPart in streamParts) {
        //TODO: If the above TODO is adopted, we need to add an isClosed check
        // here
        childStreamSubscriptions.add(
          streamPart.stream.listen(
            (StreamItemEvent<Object> childEvent) {
              // Process the child event
              streamPart.processChildEvent(
                childEvent,
                addParentEventToSink: streamController.add,
              );
            },
            onError: (
              Object error,
              StackTrace? stackTrace,
            ) {
              // Ignore errors from child streams
            },
          ),
        );
      }
    };

    return streamController.stream;
  }
}
