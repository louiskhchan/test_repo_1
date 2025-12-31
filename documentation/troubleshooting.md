# Troubleshooting

Common issues and solutions for stream_maestro.

## Quick Diagnostic Checklist

Before diving into specific errors, verify:

- [ ] `flutter pub get` has been run after adding dependency
- [ ] You're importing `package:test_repo_1/stream_maestro.dart`
- [ ] Repository instance is properly initialized
- [ ] `toItemEventStream()` is called on repository stream
- [ ] `streamMaestro.close()` is called in `onDispose` or widget dispose

---

## Common Errors

### Error: "Cannot add a new stream while already listening to another stream"

**Symptom:**
```
StateError: Cannot add a new stream while already listening to another stream.
StreamMaestro only supports adding a stream once.
```

**Cause:**
You called `streamMaestro.addStream()` multiple times on the same `StreamMaestro` instance.

**Solution:**
Create a new `StreamMaestro` instance if you need to change the data source:

```dart
// ❌ Wrong
streamMaestro.addStream(stream1);
streamMaestro.addStream(stream2); // Throws error!

// ✅ Correct - create new instance
final streamMaestro1 = StreamMaestro<Record>();
streamMaestro1.addStream(stream1);

final streamMaestro2 = StreamMaestro<Record>();
streamMaestro2.addStream(stream2);
```

Or close the old one first:

```dart
await streamMaestro.close();
streamMaestro = StreamMaestro<Record>();
streamMaestro.addStream(newStream);
```

---

### Error: "NoRecordsAvailableException"

**Symptom:**
UI shows "No records available" error or exception is thrown.

**Cause:**
The repository returned a `NoDataException`, which was automatically converted to `NoRecordsAvailableException` by `toItemEventStream()`.

**Solution:**
This is expected behavior when no data exists. Handle it in your UI:

```dart
MasterDetailsView<Record>(
  dataStream: streamMaestro.stream,
  onError: (error) {
    if (error is NoRecordsAvailableException) {
      // Show empty state UI
      return const EmptyStateWidget(
        message: 'No records found',
      );
    }
    // Handle other errors
    return ErrorWidget(error);
  },
);
```

---

### Error: Type mismatch errors with generics

**Symptom:**
```
type 'StreamItemEvent<dynamic>' is not a subtype of type 'StreamItemEvent<Record>'
```

**Cause:**
Missing or incorrect type parameter on `StreamMaestro` or stream methods.

**Solution:**
Always specify the type parameter explicitly:

```dart
// ❌ Wrong
final streamMaestro = StreamMaestro(); // Missing type

// ✅ Correct
final streamMaestro = StreamMaestro<Record>(); // Explicit type
```

```dart
// ❌ Wrong
repo.itemOperationsStream(criteria, match: (_, __) => true)

// ✅ Correct
repo.itemOperationsStream<Record, Record>(criteria, match: (_, __) => true)
```

---

### Issue: Stream doesn't emit any events

**Symptom:**
UI doesn't update, no data appears, stream seems inactive.

**Debugging Steps:**

1. **Verify repository is fetching data:**
   ```dart
   repo.itemOperationsStream<Record, Record>(criteria, match: (_, __) => true)
     .listen((operation) {
       print('Repository operation: $operation');
     });
   ```

2. **Verify conversion is working:**
   ```dart
   repo.itemOperationsStream<Record, Record>(criteria, match: (_, __) => true)
     .toItemEventStream()
     .listen((event) {
       print('Stream item event: $event');
     });
   ```

3. **Verify StreamMaestro is outputting:**
   ```dart
   streamMaestro.stream.listen((event) {
     print('StreamMaestro event: $event');
   });
   ```

4. **Check if UI component is listening:**
   Ensure the UI widget is properly connected to `streamMaestro.stream`.

---

### Issue: Memory leak or stream not closing

**Symptom:**
App performance degrades over time, memory usage increases.

**Cause:**
`StreamMaestro` not being closed when widget is disposed.

**Solution:**
Always close the maestro:

```dart
class _MyWidgetState extends State<MyWidget> {
  late final StreamMaestro<Record> _streamMaestro;

  @override
  void dispose() {
    _streamMaestro.close(); // Important!
    super.dispose();
  }
}
```

Or use the `onDispose` callback in MDV:

```dart
MasterDetailsView<Record>(
  dataStream: streamMaestro.stream,
  onDispose: streamMaestro.close, // Automatically closes
);
```

---

### Issue: Child streams not attaching with `withStreamParts`

**Symptom:**
Parent items appear but child data is missing or not attached.

**Debugging Steps:**

1. **Verify `getChildStream` is called:**
   ```dart
   ChildrenStreamPart<Parent, Child>(
     getChildStream: (parent) {
       print('Fetching children for parent: ${parent.id}');
       return childStream;
     },
     attachToParent: (parent, children) => parent.copyWith(children: children),
   )
   ```

2. **Verify child stream emits data:**
   ```dart
   getChildStream: (parent) {
     final childStream = repo
       .itemOperationsStream<Child, Child>(...)
       .toItemEventStream();
     
     // Debug: listen to verify
     childStream.listen((event) {
       print('Child event for parent ${parent.id}: $event');
     });
     
     return childStream;
   }
   ```

3. **Verify `attachToParent` is called:**
   ```dart
   attachToParent: (parent, children) {
     print('Attaching ${children.length} children to parent ${parent.id}');
     return parent.copyWith(children: children);
   }
   ```

---

### Issue: Events arrive out of order

**Symptom:**
UI updates in unexpected sequence, data appears inconsistent.

**Cause:**
Multiple streams emitting events asynchronously without coordination.

**Solution:**
This is expected behavior with asynchronous streams. If order matters:

1. Use `StreamMaestro` with a single data source
2. Ensure repository fetch criteria properly filters data
3. Let UI components handle eventual consistency

---

### Error: "Bad state: Stream has already been listened to"

**Symptom:**
```
Bad state: Stream has already been listened to.
```

**Cause:**
Trying to listen to the same stream multiple times when it's a single-subscription stream.

**Solution:**
Convert to broadcast stream or ensure only one listener:

```dart
// Make stream broadcast if multiple listeners needed
final broadcastStream = repo
  .itemOperationsStream<Record, Record>(...)
  .toItemEventStream()
  .asBroadcastStream();

streamMaestro.addStream(broadcastStream);
```

---

## Platform-Specific Issues

### Android: No platform-specific issues identified

### iOS: No platform-specific issues identified

### Web: No platform-specific issues identified

---

## Debug Logging

Enable detailed logging for troubleshooting:

```dart
// Add logging to each stage
repo
  .itemOperationsStream<Record, Record>(criteria, match: (_, __) => true)
  .map((op) {
    print('[REPO] Operation: ${op.runtimeType}');
    return op;
  })
  .toItemEventStream()
  .map((event) {
    print('[STREAM] Event: ${event.runtimeType}, isLast: ${event.isLast}');
    return event;
  })
  .listen((event) {
    streamMaestro.addEvent(event);
  });
```

---

## Still Stuck?

If the above solutions don't resolve your issue:

1. **Check the example app:** Review working examples in the repository
2. **Review dependencies:** Ensure `repository` and `stream_action_events` are up to date
3. **Ask for help:** Contact the CMiC Flutter team with:
   - Error message (full stack trace)
   - Minimal code reproduction
   - What you've already tried
   - Flutter/Dart SDK versions
