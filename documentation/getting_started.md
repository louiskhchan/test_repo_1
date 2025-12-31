# Getting Started

Get stream_maestro working in your Flutter app in under 5 minutes.

## Prerequisites

- A Flutter project using CMiC Flutter architecture
- Access to a `Repository` instance
- Familiarity with `MasterDetailsView` or `LovTab` UI components

## Step 1: Add the Dependency

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  stream_maestro:
    git:
      url: https://github.com/CMiC-Flutter/stream_maestro
      ref: main
```

Or using [cmic_pacman](https://github.com/CMiC-Flutter/cmic_pacman):

```sh
cmic_pacman add dev:stream_maestro
```

Then run:

```bash
flutter pub get
```

## Step 2: Import the Package

```dart
import 'package:test_repo_1/stream_maestro.dart';
```

## Step 3: Create a StreamMaestro

Create a `StreamMaestro` instance for your data type:

```dart
final streamMaestro = StreamMaestro<Record>();
```

## Step 4: Connect Repository Stream

Convert your repository's `ItemOperation` stream to `StreamItemEvent` and add it to the maestro:

```dart
final repo = /* Your Repository instance */;
final fetchCriteria = /* Your RecordFetchCriteria */;

streamMaestro.addStream(
  repo
    .itemOperationsStream<Record, Record>(
      fetchCriteria,
      match: (_, __) => true,
    )
    .toItemEventStream(), // Converts ItemOperation to StreamItemEvent
);
```

## Step 5: Connect to UI Component

Use the maestro's output stream in your UI component:

```dart
MasterDetailsView<Record>(
  dataStream: streamMaestro.stream,
  onDispose: streamMaestro.close,
  // ... other MDV parameters
);
```

## Complete Working Example

Here's a minimal complete example:

```dart
import 'package:flutter/material.dart';
import 'package:test_repo_1/stream_maestro.dart';
import 'package:repository/repository.dart';
import 'package:master_details_view/master_details_view.dart';

class RecordListScreen extends StatefulWidget {
  const RecordListScreen({super.key});

  @override
  State<RecordListScreen> createState() => _RecordListScreenState();
}

class _RecordListScreenState extends State<RecordListScreen> {
  late final StreamMaestro<Record> _streamMaestro;
  late final Repository _repo;

  @override
  void initState() {
    super.initState();
    
    // Create StreamMaestro
    _streamMaestro = StreamMaestro<Record>();
    
    // Get repository instance
    _repo = RepositoryProvider.of(context);
    
    // Define fetch criteria
    final fetchCriteria = RecordFetchCriteria(
      // ... your criteria parameters
    );
    
    // Connect repository stream to maestro
    _streamMaestro.addStream(
      _repo
        .itemOperationsStream<Record, Record>(
          fetchCriteria,
          match: (_, __) => true,
        )
        .toItemEventStream(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Records')),
      body: MasterDetailsView<Record>(
        dataStream: _streamMaestro.stream,
        onDispose: _streamMaestro.close,
        // Configure MDV parameters...
      ),
    );
  }
}
```

## Adding UI Events

To add sorting, filtering, or other UI action events:

```dart
// Add a sorting event
final sortingOption = SortingOption<Record, String>(
  // ... sorting configuration
);

_streamMaestro.addEvent(
  StreamSortingEvent<Record>(item: sortingOption),
);

// Add a filtering event
_streamMaestro.addEvent(
  StreamFilteringEvent<Record>(/* ... */),
);
```

## Simple Use Case: Direct Stream (Without StreamMaestro)

For simple UI components like `LovTab` that don't need UI action management:

```dart
LovTab<Record>(
  dataStream: () {
    final fetchCriteria = /* Your criteria */;
    
    // Convert and return stream directly
    return repo
      .itemOperationsStream<Record, Record>(
        fetchCriteria,
        match: (_, __) => true,
      )
      .toItemEventStream();
  },
  // ... other LovTab parameters
);
```

## What's Next?

- **Need to understand concepts?** See [Core Concepts](core_concepts.md)
- **Want to attach child streams?** See [Core Concepts - Stream Parts](core_concepts.md#stream-parts)
- **Something not working?** See [Troubleshooting](troubleshooting.md)
- **Need architectural details?** See [Architecture](architecture.md)
