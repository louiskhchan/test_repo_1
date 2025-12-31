import 'dart:async';

import 'package:repository/repository.dart';
import 'package:stream_action_events/stream_action_events.dart';

/// Combines data streams and UI action events into a unified output stream.
///
/// [StreamMaestro] serves as a central hub that accepts data events via
/// [addStream] and UI action events via [addEvent], then outputs a combined
/// stream of [StreamActionEvent] consumable by UI components like
/// [MasterDetailsView].
///
/// The output stream includes:
/// - Data events ([StreamItemEvent]): Records from the data source
/// - Action events ([StreamSortingEvent], [StreamGroupingEvent]): UI actions
///   that tell the UI component when to update its collection state
///
/// In CMiC apps, data typically comes from the `repository` package. The
/// [Repository.itemOperationsStream] returns [ItemOperation] events that must
/// be converted to [StreamItemEvent]s using [ItemEventStreamExtension.toItemEventStream]
/// before being added to [StreamMaestro].
///
class StreamMaestro<T> {
  StreamMaestro();
  //test adding some comment 2

  /// The [StreamController] to provide a sink for all UI events
  final StreamController<StreamActionEvent<T>> _streamController =
      StreamController<StreamActionEvent<T>>();

  /// Subscription to [StreamItemEvent] stream, if added via [addStream]
  StreamSubscription<StreamItemEvent<T>>? _streamSubscription;

  /// The output stream
  Stream<StreamActionEvent<T>> get stream => _streamController.stream;

  /// Subscribe to a [StreamItemEvent] stream and transfer all its events to the
  /// output stream via [_streamController].
  ///
  /// [stream]: The source stream, typically a stream of [StreamItemEvent]s. In
  /// most cases, this stream is derived from a [Repository] by converting its
  /// [itemOperationsStream] (which emits [ItemOperation] events) to a
  /// [StreamItemEvent] stream using the
  /// [ItemEventStreamExtension.toItemEventStream] method.
  ///
  void addStream(
    Stream<StreamItemEvent<T>> stream,
  ) {
    if (_streamSubscription != null) {
      throw StateError(
        'Cannot add a new stream while already listening to another stream. '
        'StreamMaestro only supports adding a stream once.',
      );
    }
    _streamSubscription = stream.listen(
      (StreamItemEvent<T> event) {
        addEvent(event);
      },
      onError: addError,
    );

    // Stop listening to the source stream, if the user stop listening to the
    // output stream.
    _streamController.onCancel = close;
  }

  /// Add a [StreamActionEvent] to the output stream via [_streamController]
  ///
  void addEvent(
    StreamActionEvent<T> event,
  ) {
    if (!_streamController.isClosed) {
      _streamController.add(event);
    }
  }

  /// Add an error to the output stream via [_streamController]
  ///
  void addError(
    Object e, [
    StackTrace? s,
  ]) {
    if (!_streamController.isClosed) {
      _streamController.addError(e, s);
    }
  }

  /// Close the [StreamMaestro].
  ///
  /// Usually, you should not need to manually close the [StreamMaestro] because
  /// it will be automatically closed when the output stream is cancelled. This
  /// method is provided only in case manual closing is necessary.
  Future<void> close() async {
    await _streamSubscription?.cancel();
    _streamSubscription = null;
    await _streamController.close();
  }
}
