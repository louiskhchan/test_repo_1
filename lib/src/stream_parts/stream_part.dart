import 'dart:async';

import 'package:stream_action_events/stream_action_events.dart';

/// The [StreamPart] class is an interface that defines how to obtain a stream
/// of child or property events, how to map them with parents, and how to apply
/// these events to the parent.
///
abstract class StreamPart<T, ChildType> {
  /// Implement this method to provide a stream of child or property events.
  ///
  Stream<StreamItemEvent<ChildType>> get stream;

  /// Implement this method to define how to handle a child event.
  ///
  /// Typically, this involves attaching the child or property to the parent and
  /// adding a StreamChangeEvent<T> to the sink so that the parent update is
  /// notified.
  ///
  void processChildEvent(
    StreamItemEvent<ChildType> childEvent, {
    required void Function(StreamItemEvent<T> updatedParentEvent)
        addParentEventToSink,
  });

  /// Implement this method to define how to handle a parent event.
  ///
  /// This method provides an interface for StreamPart implementations to update
  /// their internal references to the parent, and to transfer children or
  /// properties from cached parents to the new parent as needed.
  ///
  void processParentEvent(
    StreamItemEvent<T> parentEvent,
  );
}
