import 'package:repository/repository.dart';
import 'package:stream_action_events/no_records_available_exception.dart';
import 'package:stream_action_events/stream_action_events.dart';
import 'package:test_repo_1/src/conversion_from_item_operations/item_operation_to_stream_item_event.dart';

extension ItemEventStreamExtension<T> on Stream<ItemOperation<T>> {
  /// This extension method transforms an [ItemOperation] stream obtained from
  /// [Repository.itemOperationsStream] into a [StreamItemEvent] stream, and
  /// converts any [NoDataException] into a [NoRecordsAvailableException].
  Stream<StreamItemEvent<T>> toItemEventStream() {
    return map<StreamItemEvent<T>>(
      itemOperationToStreamItemEvent,
    ).handleError((Object e, Object? s) {
      switch (e) {
        case NoDataException():
          throw NoRecordsAvailableException();
        default:
          throw e;
      }
    });
  }
}
