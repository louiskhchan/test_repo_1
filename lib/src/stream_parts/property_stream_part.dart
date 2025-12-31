import 'package:test_repo_1/src/stream_parts/stream_part.dart';
import 'package:stream_action_events/stream_action_events.dart';

/// The [PropertyStreamPart] class is an implementation of the [StreamPart]
/// class that manages the association of a property value with its parent item.
/// It listens to a stream of property events and updates parent objects with
/// the corresponding property values based on a property code. The class
/// maintains a set of parent references and a map of property codes to property
/// values, ensuring that when a property value changes, all relevant parents
/// are updated and notified accordingly.
///
class PropertyStreamPart<T, PropertyType> extends StreamPart<T, PropertyType> {
  PropertyStreamPart({
    required this.propertyEventStreamGetter,
    required this.setParentProperty,
    required this.getPropertyCodeFromParent,
    required this.getPropertyCodeFromChild,
  });

  /// A function that returns a stream of property events.
  ///
  final Stream<StreamItemEvent<PropertyType>> Function()
      propertyEventStreamGetter;

  /// A function that sets the parent property to the given property, or unsets
  /// it if null.
  ///
  final void Function(
    T parent,
    PropertyType? property,
  ) setParentProperty;

  /// A function that gets the property code from a parent item.
  ///
  final Object? Function(T parent) getPropertyCodeFromParent;

  /// A function that gets the property code from a property value.
  ///
  final Object Function(PropertyType propertyValue) getPropertyCodeFromChild;

  /// A set of parent references, used to update property value for all parents
  /// when property value changes.
  ///
  final Set<T> _parentSet = <T>{};

  /// A map of property code to the property value.
  ///
  final Map<Object, PropertyType> _propertyMap = <Object, PropertyType>{};

  @override
  void processChildEvent(
    StreamItemEvent<PropertyType> childEvent, {
    required void Function(StreamItemEvent<T> updatedParentEvent)
        addParentEventToSink,
  }) {
    final PropertyType propertyValue = childEvent.item;
    final Object propertyCode = getPropertyCodeFromChild(childEvent.item);

    // On property value event, save the property value by the property code.
    _propertyMap[propertyCode] = propertyValue;

    for (final T parent in _parentSet) {
      // Update parents of the property code with the new property value.
      if (getPropertyCodeFromParent(parent) == propertyCode) {
        setParentProperty(
          parent,
          propertyValue,
        );
        // Notify the change of property value with parent change event.
        addParentEventToSink(
          StreamChangeEvent<T>(item: parent),
        );
      }
    }
  }

  @override
  void processParentEvent(StreamItemEvent<T> parentEvent) {
    final T parent = parentEvent.item;
    final Object? parentPropertyCode = getPropertyCodeFromParent(parent);

    // Update the parent reference in the parent set.
    //
    // If this is a delete event, remove the parent from the set. Otherwise,
    // update it by removing and then adding it again, since Set does not
    // support direct replacement.
    //
    _parentSet.remove(parent);
    if (parentEvent is! StreamDeleteEvent) {
      _parentSet.add(parent);
    }

    // Set the property value on the parent using the property value map
    setParentProperty(
      parent,
      _propertyMap[parentPropertyCode],
    );
  }

  @override
  Stream<StreamItemEvent<PropertyType>> get stream =>
      propertyEventStreamGetter();
}
