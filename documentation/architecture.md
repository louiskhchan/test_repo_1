# Architecture

> **Note:** For basic integration, see [Getting Started](getting_started.md). This document is for developers who need to extend, debug, or contribute to stream_maestro.

## Overview

`stream_maestro` is a stream orchestration layer that sits between the `repository` package (data layer) and UI components (presentation layer).

### Architecture Diagram

```
┌───────────────────────────────────────────────────────────────┐
│                        UI Layer                                │
│  (MasterDetailsView, LovTab, custom widgets)                   │
└─────────────────────────┬─────────────────────────────────────┘
                          │
                          │ StreamActionEvent<T>
                          │
┌─────────────────────────▼─────────────────────────────────────┐
│                   StreamMaestro<T>                             │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │ StreamController<StreamActionEvent<T>>                   │ │
│  │  - Combines data events + UI action events              │ │
│  └──────────────────────────────────────────────────────────┘ │
│                          │                                     │
│       ┌──────────────────┼──────────────────┐                 │
│       │                  │                  │                  │
│   addStream()       addEvent()        addError()              │
│       │                  │                  │                  │
└───────┼──────────────────┼──────────────────┼─────────────────┘
        │                  │                  │
        │                  │                  │
┌───────▼──────────────────┼──────────────────┼─────────────────┐
│  Stream<StreamItemEvent<T>>                 │                  │
│  (from toItemEventStream)                   │                  │
│       │                                     │                  │
│  ┌────▼──────────────────────────┐          │                  │
│  │ ItemEventStreamExtension      │          │                  │
│  │  - Converts ItemOperation     │          │                  │
│  │    to StreamItemEvent         │          │                  │
│  │  - Transforms exceptions      │          │                  │
│  └────┬──────────────────────────┘          │                  │
│       │                                     │                  │
└───────┼─────────────────────────────────────┼──────────────────┘
        │                                     │
┌───────▼─────────────────────────────────────▼──────────────────┐
│                    Repository Layer                             │
│  - Emits Stream<ItemOperation<T>>                              │
│  - Manages data persistence and caching                        │
│  - Handles CRUD operations                                     │
└─────────────────────────────────────────────────────────────────┘
```

---

## Core Components

### 1. StreamMaestro Class

**File:** `lib/src/stream_maestro.dart`

**Purpose:** Central stream controller that aggregates data streams and UI action events.

**Key Responsibilities:**
- Maintain a `StreamController<StreamActionEvent<T>>` for output
- Subscribe to input data streams via `addStream()`
- Forward UI events via `addEvent()`
- Forward errors via `addError()`
- Clean up subscriptions on `close()`

**State Management:**
```dart
class StreamMaestro<T> {
  final StreamController<StreamActionEvent<T>> _streamController;
  StreamSubscription<StreamItemEvent<T>>? _streamSubscription;
  
  // Output stream exposed to UI
  Stream<StreamActionEvent<T>> get stream => _streamController.stream;
}
```

**Important Constraint:** Only supports adding a stream once. Attempting to call `addStream()` twice throws `StateError`.

**Lifecycle:**
1. Created via constructor
2. Stream added via `addStream()` (once)
3. Events added via `addEvent()` (multiple)
4. Output consumed via `.stream` getter
5. Cleaned up via `close()` when UI disposes

---

### 2. ItemEventStreamExtension

**File:** `lib/src/conversion_from_item_operations/item_event_stream_extension.dart`

**Purpose:** Extension method on `Stream<ItemOperation<T>>` to convert to `Stream<StreamItemEvent<T>>`.

**Why It Exists:**
- `ItemOperation` is repository's internal representation
- `StreamItemEvent` is UI component's expected format
- Provides exception translation layer

**Key Transformations:**
```dart
extension ItemEventStreamExtension<T> on Stream<ItemOperation<T>> {
  Stream<StreamItemEvent<T>> toItemEventStream() {
    return map<StreamItemEvent<T>>(
      itemOperationToStreamItemEvent, // Conversion function
    ).handleError((Object e, Object? s) {
      // Exception translation
      if (e is NoDataException) {
        throw NoRecordsAvailableException(); // UI-appropriate exception
      }
      throw e;
    });
  }
}
```

**Conversion Function:**

**File:** `lib/src/conversion_from_item_operations/item_operation_to_stream_item_event.dart`

Maps each `ItemOperation` type to corresponding `StreamItemEvent`:
- `ItemCreate<T>` → `StreamFetchEvent<T>`
- `ItemUpdate<T>` → `StreamChangeEvent<T>`
- `ItemDelete<T>` → `StreamDeleteEvent<T>`

---

### 3. WithStreamPartsExtension

**File:** `lib/src/stream_parts/with_stream_parts_extension.dart`

**Purpose:** Composes parent streams with child/property streams using `StreamPart` definitions.

**Architecture:**
```
Input: Stream<StreamItemEvent<Parent>>
         │
         ▼
   [withStreamParts([StreamPart, ...])]
         │
         ├─→ Creates new StreamController<StreamItemEvent<Parent>>
         │
         ├─→ Listens to input stream (parent events)
         │   └─→ For each parent event:
         │       └─→ Each StreamPart processes the event
         │
         ├─→ Listens to child streams from StreamParts
         │   └─→ For each child event:
         │       └─→ StreamPart attaches to parent
         │       └─→ Emits modified parent event
         │
         ▼
Output: Stream<StreamItemEvent<Parent>> (with children attached)
```

**Key Classes:**

#### StreamPart (Abstract Base)
**File:** `lib/src/stream_parts/stream_part.dart`

```dart
abstract class StreamPart<T, C> {
  Stream<StreamItemEvent<C>> get stream; // Child stream
  
  void processParentEvent(StreamItemEvent<T> parentEvent);
  
  void processChildEvent(
    StreamItemEvent<C> childEvent,
    {required void Function(StreamItemEvent<T>) addParentEventToSink}
  );
}
```

#### ChildrenStreamPart
**File:** `lib/src/stream_parts/children_stream_part.dart`

Attaches a **list** of child items to parent items.

```dart
ChildrenStreamPart<Parent, Child>(
  getChildStream: (parent) => Stream<StreamItemEvent<Child>>,
  attachToParent: (parent, children) => Parent,
)
```

#### PropertyStreamPart
**File:** `lib/src/stream_parts/property_stream_part.dart`

Attaches a **single** property value to parent items.

```dart
PropertyStreamPart<Parent, Property>(
  getPropertyStream: (parent) => Stream<StreamItemEvent<Property>>,
  attachToParent: (parent, property) => Parent,
)
```

---

## Data Flow

### Scenario 1: Simple Data Stream (No StreamMaestro)

```
Repository
   │
   │ itemOperationsStream()
   ▼
Stream<ItemOperation<T>>
   │
   │ .toItemEventStream()
   ▼
Stream<StreamItemEvent<T>>
   │
   │ Direct consumption
   ▼
UI Component (LOV)
```

### Scenario 2: StreamMaestro with UI Events

```
Repository                        User Interactions
   │                                     │
   │ itemOperationsStream()              │
   ▼                                     │
Stream<ItemOperation<T>>                │
   │                                     │
   │ .toItemEventStream()                │
   ▼                                     │
Stream<StreamItemEvent<T>>              │
   │                                     │
   │ streamMaestro.addStream()           │
   │                                     │
   ▼                                     │
┌────────────────────────────────────────▼────┐
│           StreamMaestro<T>                  │
│  Combines:                                  │
│   - Data events (StreamItemEvent)           │
│   - UI events (StreamSortingEvent, etc.)    │
└────────────────────┬────────────────────────┘
                     │
                     │ .stream (StreamActionEvent<T>)
                     ▼
              UI Component (MDV)
```

### Scenario 3: Parent-Child Streams

```
Repository (Parents)
   │
   │ itemOperationsStream()
   ▼
Stream<ItemOperation<Parent>>
   │
   │ .toItemEventStream()
   ▼
Stream<StreamItemEvent<Parent>>
   │
   │ .withStreamParts([ChildrenStreamPart(...)])
   ▼
┌─────────────────────────────────────────────┐
│  WithStreamPartsExtension                   │
│                                             │
│  For each Parent:                           │
│    ├─→ getChildStream(parent)               │
│    │      │                                 │
│    │      ▼                                 │
│    │   Repository (Children)                │
│    │      │                                 │
│    │      │ itemOperationsStream()          │
│    │      ▼                                 │
│    │   Stream<ItemOperation<Child>>         │
│    │      │                                 │
│    │      │ .toItemEventStream()            │
│    │      ▼                                 │
│    │   Stream<StreamItemEvent<Child>>       │
│    │                                        │
│    └─→ attachToParent(parent, children)     │
│           │                                 │
│           ▼                                 │
│        Parent (with children attached)      │
└─────────────────────┬───────────────────────┘
                      │
                      ▼
          Stream<StreamItemEvent<Parent>>
                      │
                      ▼
              StreamMaestro (optional)
                      │
                      ▼
                 UI Component
```

---

## Design Patterns

### 1. Stream Composition (Pipeline Pattern)
Streams are composed using extension methods and functional transformations:
```dart
repo.itemOperationsStream()      // Source
  .toItemEventStream()            // Transform
  .withStreamParts([...])         // Compose
  → streamMaestro.addStream()     // Sink
```

### 2. Event Aggregation (Mediator Pattern)
`StreamMaestro` acts as a mediator, aggregating multiple event sources into a single output stream.

### 3. Extension Methods
Heavy use of Dart extension methods to augment existing stream types without modifying their classes.

### 4. Generic Type Safety
Strong typing with generics ensures type safety throughout the pipeline:
```dart
Stream<ItemOperation<T>>
  → Stream<StreamItemEvent<T>>
  → StreamMaestro<T>
  → Stream<StreamActionEvent<T>>
```

---

## Key Files Overview

| File | Purpose | Exported? |
|------|---------|-----------|
| `lib/stream_maestro.dart` | Main entry point, exports public API | N/A (entry point) |
| `lib/src/stream_maestro.dart` | StreamMaestro class implementation | ✅ Yes |
| `lib/src/conversion_from_item_operations/item_event_stream_extension.dart` | toItemEventStream() extension | ✅ Yes |
| `lib/src/conversion_from_item_operations/item_operation_to_stream_item_event.dart` | Conversion function | ✅ Yes |
| `lib/src/stream_parts/stream_part.dart` | Abstract StreamPart base | ✅ Yes |
| `lib/src/stream_parts/children_stream_part.dart` | ChildrenStreamPart implementation | ✅ Yes |
| `lib/src/stream_parts/property_stream_part.dart` | PropertyStreamPart implementation | ✅ Yes |
| `lib/src/stream_parts/with_stream_parts_extension.dart` | withStreamParts() extension | ✅ Yes |
| `lib/src/filter/filter_extension.dart` | filter() extension for visibility-aware filtering | ✅ Yes |

---

## Dependencies

| Package | Purpose |
|---------|---------|
| `rxdart` | Stream utilities and operators |
| `repository` | Data layer, provides ItemOperation streams |
| `stream_action_events` | Event types (StreamItemEvent, StreamActionEvent, etc.) |

---

## Testing Considerations

When testing components that use `stream_maestro`:

1. **Mock Repository Streams:** Create test streams that emit `ItemOperation` events
2. **Verify Conversions:** Assert that `toItemEventStream()` produces correct events
3. **Test Event Ordering:** Ensure events arrive in expected sequence
4. **Test Cleanup:** Verify `close()` cancels all subscriptions
5. **Test Error Handling:** Verify exception transformations work correctly

---

## Performance Considerations

- **Stream Subscriptions:** Each `StreamMaestro` creates subscriptions. Close when done.
- **Child Streams:** `withStreamParts` can create many subscriptions if many parents. Monitor memory.
- **Broadcast Streams:** Use `.asBroadcastStream()` if multiple listeners needed.

---

## Extension Points

To extend stream_maestro:

1. **Custom StreamPart Implementations:** Create new `StreamPart` subclasses for different attachment strategies
2. **Custom Event Types:** Add new `StreamActionEvent` subtypes and handle in StreamMaestro
3. **Custom Conversion Logic:** Wrap or replace `toItemEventStream()` with custom transformations

---

## Contributing

When contributing to stream_maestro:

- Follow [Effective Dart](https://dart.dev/guides/language/effective-dart) guidelines
- Add doc comments (`///`) to all public APIs
- Update this architecture document if adding major features
- Ensure changes are backward compatible
