import 'package:test_repo_1/src/stream_parts/stream_part.dart';
import 'package:stream_action_events/stream_action_events.dart';

/// The [ChildrenStreamPart] class is a implementation of the [StreamPart] class
/// that handles the association of child items with their parent items. It
/// manages a stream of child events and applies them to the appropriate parent
/// items based on the provided mapping functions.
///
class ChildrenStreamPart<T, ChildType> extends StreamPart<T, ChildType> {
  ChildrenStreamPart({
    required this.childEventsStreamGetter,
    required this.getParentIdsFromChild,
    required this.getParentIdFromParent,
    required this.applyChildEventOnParent,
    required this.childrenCopier,
  });

  /// A function that returns a stream of child events.
  ///
  final Stream<StreamItemEvent<ChildType>> Function() childEventsStreamGetter;

  /// A function that returns a list of parent identifiers for a given child
  /// item. This is used to associate each child item with its parent(s).
  ///
  final List<Object> Function(ChildType child) getParentIdsFromChild;

  /// A function that returns the parent identifier for a given parent item.
  ///
  final Object Function(T parent) getParentIdFromParent;

  /// A function that applies a child event to a parent item.
  ///
  final void Function(T parent, StreamItemEvent<ChildType> childEvent)
      applyChildEventOnParent;

  /// A function that copies the children from one parent to another.
  ///
  final void Function(T oldParent, T newParent) childrenCopier;

  /// A map of parent identifiers to the references to the parents.
  ///
  final Map<Object, T> _parentMap = <Object, T>{};

  /// Stores child events that are waiting for their corresponding parent to be
  /// available. The key is the parent ID, and the value is a list of pending
  /// child events for that parent.
  ///
  final Map<Object, List<StreamItemEvent<ChildType>>> _pendingChildEventMap =
      <Object, List<StreamItemEvent<ChildType>>>{};

  @override
  Stream<StreamItemEvent<ChildType>> get stream => childEventsStreamGetter();

  @override
  void processChildEvent(
    StreamItemEvent<ChildType> childEvent, {
    required void Function(StreamItemEvent<T> updatedParentEvent)
        addParentEventToSink,
  }) {
    // For each parent ID associated with the child event
    for (Object parentId in getParentIdsFromChild(childEvent.item)) {
      // If the parent exists in the parent map, apply the child event
      if (_parentMap[parentId] case T parent) {
        applyChildEventOnParent(parent, childEvent);
        // Notify that the parent has changed due to the child event
        addParentEventToSink(
          StreamChangeEvent<T>(item: parent, isLast: childEvent.isLast),
        );
      } else {
        // If the parent is not available yet, store the child event as pending
        (_pendingChildEventMap[parentId] ??= <StreamItemEvent<ChildType>>[])
            .add(childEvent);
      }
    }
  }

  @override
  void processParentEvent(StreamItemEvent<T> parentEvent) {
    final T newParent = parentEvent.item;
    final Object parentId = getParentIdFromParent(newParent);

    // Update the parent map with the new parent item

    if (parentEvent is StreamDeleteEvent) {
      _parentMap.remove(parentId);
    } else {
      // If this item already exists in the parent map, copy the existing
      // children from the old parent to the new parent.
      if (_parentMap[parentId] case T oldParent) {
        childrenCopier(oldParent, newParent);
      }
      // Store the new parent item in the parent map
      _parentMap[parentId] = newParent;
    }

    // Apply any pending child events to the new parent.

    if (parentEvent is StreamDeleteEvent) {
      _pendingChildEventMap.remove(parentId);
    } else {
      // If there are pending child events for this parent, apply them now.
      if (_pendingChildEventMap[parentId]
          case List<StreamItemEvent<ChildType>> pendingChildEvents) {
        while (pendingChildEvents.isNotEmpty) {
          applyChildEventOnParent(newParent, pendingChildEvents.removeAt(0));
        }
      }
    }
  }
}
