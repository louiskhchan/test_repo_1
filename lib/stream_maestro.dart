/// A stream orchestration package for managing UI data and action events.
///
/// This library provides [StreamMaestro] for combining data streams from the
/// `repository` package with UI action events (sorting, filtering, grouping)
/// into a unified stream consumable by UI components like MasterDetailsView.
///
/// Key exports:
/// - [StreamMaestro]: Central hub for data and UI events
/// - [ItemEventStreamExtension]: Converts repository streams to UI events
/// - [FilterExtension]: Filters streams with visibility handling
/// - [WithStreamPartsExtension]: Attaches child/property streams to parents
/// - [StreamPart], [ChildrenStreamPart], [PropertyStreamPart]: Stream composition
///
/// See [documentation/getting_started.md] for quick setup.
library stream_maestro;

export 'src/conversion_from_item_operations/item_event_stream_extension.dart';
export 'src/conversion_from_item_operations/item_operation_to_stream_item_event.dart';
export 'src/filter/filter_extension.dart';
export 'src/stream_maestro.dart';
export 'src/stream_parts/children_stream_part.dart';
export 'src/stream_parts/property_stream_part.dart';
export 'src/stream_parts/stream_part.dart';
export 'src/stream_parts/with_stream_parts_extension.dart';
