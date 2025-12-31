# Core Concepts

This document explains the key abstractions in stream_maestro. Understanding these concepts will help you integrate effectively.

## Overview

```
┌─────────────────────────────────────────────────┐
│            Repository (Data Source)              │
│         produces ItemOperation stream            │
└────────────────────┬────────────────────────────┘
                     │
                     ▼
         ┌───────────────────────┐
         │  toItemEventStream()  │ (extension method)
         │  Converts operations  │
         └───────────┬───────────┘
                     │
                     ▼
       ┌─────────────────────────┐
       │  StreamItemEvent stream │
       └─────────────┬───────────┘
                     │
         ┌───────────┴───────────┐
         │                       │
         ▼                       ▼
   ┌─────────┐          ┌──────────────┐
   │  LOV    │          │ StreamMaestro│
   │ (Simple)│          │  (Complex)   │
   └─────────┘          └──────┬───────┘
                               │
                               │ Manages UI events
                               │ (sorting, filtering)
                               │
                               ▼
                     ┌──────────────────┐
                     │ StreamActionEvent│
                     │      stream      │
                     └────────┬─────────┘
                              │
                              ▼
                     ┌──────────────────┐
                     │ MasterDetailsView│
                     │      (MDV)       │
                     └──────────────────┘
```

## StreamMaestro

### What It Is
A stream manager that combines data streams with UI action events into a single output stream.

### Why It Exists
UI components like `MasterDetailsView` need both data updates AND user action events (sorting, filtering, grouping) in a unified stream. `StreamMaestro` acts as a central hub that:
- Receives data from repository
- Receives UI actions from user interactions
- Outputs a combined stream to the UI component

### When to Use

| Use Case | Use StreamMaestro? | Rationale |
|----------|-------------------|-----------|
| MasterDetailsView with sorting/filtering | ✅ Yes | Needs to manage multiple event types |
| Simple List of Values (LOV) | ❌ No | Only needs data, use `toItemEventStream()` directly |
| Custom widget needing data + actions | ✅ Yes | Benefits from unified stream |
| Read-only data display | ❌ No | Use direct stream conversion |

### How to Create

```dart
final streamMaestro = StreamMaestro<YourDataType>();
```

### Key Methods

```dart
// Add a data stream from repository
streamMaestro.addStream(Stream<StreamItemEvent<T>> stream);

// Add a UI action event (sorting, filtering, etc.)
streamMaestro.addEvent(StreamActionEvent<T> event);

// Add an error
streamMaestro.addError(Object error, [StackTrace? stackTrace]);

// Get the output stream
Stream<StreamActionEvent<T>> outputStream = streamMaestro.stream;

// Clean up when done
await streamMaestro.close();
```

---

## ItemOperation & StreamItemEvent

### What They Are
- **`ItemOperation<T>`**: Low-level data operation from repository (add, update, remove records)
- **`StreamItemEvent<T>`**: UI-ready event containing the operation and metadata

### Why the Conversion Exists
The repository speaks in "operations" (database language), but UI components speak in "events" (UI language). The conversion bridges this gap and also:
- Transforms `NoDataException` into `NoRecordsAvailableException` (UI-appropriate error)
- Adds metadata for UI rendering

### How to Convert

```dart
Stream<ItemOperation<Record>> repoStream = repo.itemOperationsStream(...);

// Use the extension method
Stream<StreamItemEvent<Record>> uiStream = repoStream.toItemEventStream();
```

### Example Flow

```dart
// Repository produces ItemOperation
ItemCreate(item: record, isLast: true) 
  ↓
// Extension converts to StreamItemEvent  
StreamFetchEvent(item: record, isLast: true)
  ↓
// UI renders the change
```

---

## StreamActionEvent (Base Type)

### What It Is
The parent type for all events in the output stream. Subtypes include:
- **`StreamItemEvent<T>`**: Data events (records added/updated/removed)
- **`StreamSortingEvent<T>`**: Sorting action events
- **`StreamFilteringEvent<T>`**: Filtering action events
- **`StreamGroupingEvent<T>`**: Grouping action events

### Why It Exists
Allows the UI component to handle different event types from a single stream using pattern matching or type checking.

### Example Usage

```dart
streamMaestro.stream.listen((event) {
  switch (event) {
    case StreamItemEvent<Record> itemEvent:
      // Handle data update
      handleDataChange(itemEvent);
    case StreamSortingEvent<Record> sortEvent:
      // Handle sorting
      applySorting(sortEvent.item);
    // ... other event types
  }
});
```

---

## Stream Parts

### What They Are
`StreamPart` objects that define how to attach child or property streams to parent items. Two types:
- **`ChildrenStreamPart`**: Attaches a list of child items to parents
- **`PropertyStreamPart`**: Attaches a single property value to parents

### Why They Exist
In complex UIs, parent records often need related child data (e.g., a Project needs its Tasks). Stream parts automatically:
- Fetch child streams when parent items arrive
- Attach child data to the correct parent items
- Update children when they change

> **Note:** Stream Parts have a complex API designed for advanced use cases. The examples below are simplified for conceptual understanding. Refer to the actual class documentation for complete API details.

### Conceptual Example

```dart
// Simplified conceptual example - actual API is more complex
streamMaestro.addStream(
  repo
    .itemOperationsStream<Project, Project>(...)
    .toItemEventStream()
    .withStreamParts([
      ChildrenStreamPart<Project, Task>(
        // Actual API requires 5 parameters:
        // - childEventsStreamGetter: () => Stream<StreamItemEvent<Task>>
        // - getParentIdsFromChild: (child) => List<Object> (parent IDs)
        // - getParentIdFromParent: (parent) => Object (parent ID)
        // - applyChildEventOnParent: (parent, childEvent) => void
        // - childrenCopier: (oldParent, newParent) => void
        
        // See class documentation for actual usage
      ),
    ]),
);
```

### Actual ChildrenStreamPart API

The real `ChildrenStreamPart` constructor requires these parameters:

```dart
ChildrenStreamPart<Parent, Child>({
  // Function that returns the child events stream
  required Stream<StreamItemEvent<Child>> Function() childEventsStreamGetter,
  
  // Get parent IDs from a child item (supports multiple parents)
  required List<Object> Function(Child) getParentIdsFromChild,
  
  // Get the ID from a parent item
  required Object Function(Parent) getParentIdFromParent,
  
  // Apply a child event to its parent (mutates parent)
  required void Function(Parent, StreamItemEvent<Child>) applyChildEventOnParent,
  
  // Copy children from old parent to new parent when parent updates
  required void Function(Parent oldParent, Parent newParent) childrenCopier,
})
```

This API is designed for flexibility and performance, handling cases where:
- Children can belong to multiple parents
- Parents need to maintain child collections
- Child events need to be queued if parent hasn't arrived yet

### Actual PropertyStreamPart API

The real `PropertyStreamPart` constructor requires these parameters:

```dart
PropertyStreamPart<Parent, Property>({
  // Function that returns the property events stream
  required Stream<StreamItemEvent<Property>> Function() propertyEventStreamGetter,
  
  // Set the property on a parent (mutates parent)
  required void Function(Parent, Property?) setParentProperty,
  
  // Get the property code from a parent (e.g., categoryId)
  required Object? Function(Parent) getPropertyCodeFromParent,
  
  // Get the property code from a property value (e.g., category.id)
  required Object Function(Property) getPropertyCodeFromChild,
})
```

This API is used for lookup/reference data where:
- Multiple parents may reference the same property by a code (e.g., categoryId)
- Property updates should reflect on all parents that reference it
- Property values are cached by their code for efficiency

### Visual Flow

```
Parent Stream (Projects)
        │
        ▼
   withStreamParts([...])
        │
        ├─→ For each Project, fetch Task stream
        │   
        ├─→ When Tasks arrive, attach to Project
        │
        ▼
Modified Stream (Projects with Tasks attached)
```

---

## FilterExtension

### What It Is
An extension method on `Stream<StreamItemEvent<T>>` that filters items while properly handling visibility transitions.

### Why It Exists
The standard Dart `where()` method doesn't handle the case where an item changes from visible to invisible (or vice versa). When filtering, items need to:
- Emit `StreamDeleteEvent` when becoming invisible
- Emit `StreamFetchEvent` when becoming visible
- Be tracked to know their previous visibility state

### How to Use

```dart
repo
  .itemOperationsStream<Record, Record>(...)
  .toItemEventStream()
  .filter((record) => record.status == 'active') // Only show active records
```

### Visual Flow

```
ItemUpdate(item: record, status: 'inactive')
  ↓ toItemEventStream()
StreamChangeEvent(item: record)
  ↓ filter((r) => r.status == 'active')
StreamDeleteEvent(item: record)  // Item filtered out
  ↓
UI removes the record
```

### Key Behavior

| Scenario | Input Event | Output Event |
|----------|-------------|--------------|
| Item starts visible, stays visible | `StreamChangeEvent` | `StreamChangeEvent` (pass through) |
| Item starts visible, becomes invisible | `StreamChangeEvent` | `StreamDeleteEvent` (filtered out) |
| Item starts invisible, becomes visible | `StreamChangeEvent` | `StreamFetchEvent` (newly visible) |
| Item starts invisible, stays invisible | `StreamChangeEvent` | (no event) |

---

## How Concepts Work Together

### Scenario 1: Simple Data Display (LOV)

1. Get `ItemOperation` stream from **Repository**
2. Convert using **`toItemEventStream()`** extension
3. Feed directly to **LOV component**
4. LOV renders the data

### Scenario 2: Complex UI with Actions (MDV)

1. Create a **StreamMaestro**
2. Get `ItemOperation` stream from **Repository**
3. Convert using **`toItemEventStream()`**
4. Add converted stream to **StreamMaestro** via `addStream()`
5. User triggers sorting → add **StreamSortingEvent** via `addEvent()`
6. **MDV** listens to `streamMaestro.stream` and handles all events

### Scenario 3: Parent-Child Relationships

1. Create a **StreamMaestro**
2. Get parent `ItemOperation` stream from **Repository**
3. Convert using **`toItemEventStream()`**
4. Apply **`withStreamParts()`** to attach children
5. **StreamPart** fetches child streams and attaches them
6. Add composed stream to **StreamMaestro**
7. **MDV** receives parents with children already attached

---

## Quick Reference Table

| Concept | One-Line Description | Example |
|---------|---------------------|---------|
| `StreamMaestro` | Central hub for data + UI events | `StreamMaestro<Record>()` |
| `ItemOperation` | Repository's data operation | `ItemCreate(item: record)` |
| `StreamItemEvent` | UI-ready data event | `StreamFetchEvent(item: record)` |
| `StreamActionEvent` | Base type for all stream events | `StreamSortingEvent(...)` |
| `toItemEventStream()` | Converts operations to events | `repoStream.toItemEventStream()` |
| `StreamPart` | Defines child/property attachment | `ChildrenStreamPart(...)` |
| `withStreamParts()` | Applies stream parts to stream | `.withStreamParts([...])` |
| `filter()` | Filters stream with visibility handling | `.filter((item) => condition)` |

---

## Decision Flowchart

```
Do you need to manage UI actions (sorting, filtering)?
│
├─ Yes → Use StreamMaestro
│        │
│        └─ Do you need parent-child relationships?
│           │
│           ├─ Yes → Use withStreamParts() with StreamMaestro
│           └─ No → Just use StreamMaestro with toItemEventStream()
│
└─ No → Use toItemEventStream() directly
         (No StreamMaestro needed)
```
