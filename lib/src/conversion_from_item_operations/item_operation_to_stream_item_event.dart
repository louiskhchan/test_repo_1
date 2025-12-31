import 'package:repository/repository.dart';
import 'package:stream_action_events/stream_action_events.dart';

/// Converts an [ItemOperation] event into a corresponding [StreamItemEvent].
///
StreamItemEvent<T> itemOperationToStreamItemEvent<T>(
  ItemOperation<T> itemOperation,
) {
  return switch (itemOperation) {
    ItemCreate<T> itemOperation => StreamFetchEvent<T>(
        item: itemOperation.item,
        isLast: itemOperation.isLast,
      ),
    ItemUpdate<T> itemOperation => StreamChangeEvent<T>(
        item: itemOperation.item,
        oldItem: itemOperation.oldItem,
        isLast: itemOperation.isLast,
      ),
    ItemDelete<T> itemOperation => StreamDeleteEvent<T>(
        item: itemOperation.item,
        isLast: itemOperation.isLast,
      ),
  };
}
