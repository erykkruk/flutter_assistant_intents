/// Code generator for `dart run flutter_assistant_intents:generate`.
///
/// Pure string-in/string-out logic (testable without IO): parses
/// `assistant_intents.yaml`, emits the host's Swift App Intents file and the
/// Dart glue file, and registers the Swift file in `project.pbxproj`.
///
/// Not exported by the package barrel — host apps never import this.
library;

import 'package:yaml/yaml.dart';

/// Thrown for invalid `assistant_intents.yaml` content.
class GeneratorConfigException implements Exception {
  GeneratorConfigException(this.message);
  final String message;

  @override
  String toString() => 'assistant_intents.yaml: $message';
}

/// How the built-in task intents (AddTask/CompleteTask/QueryTasks) surface.
enum TaskPresetMode {
  /// Re-export the plugin's compiled intents via `AppIntentsPackage`
  /// (iOS 17+ runtime for the re-export).
  package,

  /// Generate the task intents directly in the Runner target — works on
  /// iOS 16.0+ and is immune to framework metadata-extraction gaps.
  wrappers,

  /// No task intents (custom actions only).
  none;

  static TaskPresetMode parse(Object? value) => switch (value) {
        null || 'package' => TaskPresetMode.package,
        'wrappers' => TaskPresetMode.wrappers,
        'none' => TaskPresetMode.none,
        _ => throw GeneratorConfigException(
            "task_preset must be 'package', 'wrappers' or 'none', "
            "got '$value'",
          ),
      };
}

/// Supported custom-action parameter types.
enum ActionParameterType {
  string('String'),
  int('Int'),
  double('Double'),
  bool('Bool');

  const ActionParameterType(this.swiftType);
  final String swiftType;

  static ActionParameterType parse(Object? value) =>
      ActionParameterType.values.asNameMap()[value] ??
      (throw GeneratorConfigException(
        "parameter type must be one of string/int/double/bool, got '$value'",
      ));
}

class ActionParameter {
  ActionParameter({
    required this.name,
    required this.type,
    required this.title,
    required this.optional,
    this.dialog,
  });

  factory ActionParameter.fromYaml(Object? node) {
    if (node is! Map) {
      throw GeneratorConfigException('each parameter must be a map');
    }
    final name = node['name'];
    if (name is! String || !_isSnakeOrCamel(name)) {
      throw GeneratorConfigException(
        "parameter 'name' is required (letters/digits/underscore)",
      );
    }
    return ActionParameter(
      name: name,
      type: ActionParameterType.parse(node['type'] ?? 'string'),
      title: (node['title'] as String?) ?? _titleCase(name),
      optional: (node['optional'] as bool?) ?? true,
      dialog: node['dialog'] as String?,
    );
  }

  final String name;
  final ActionParameterType type;
  final String title;
  final bool optional;
  final String? dialog;
}

class AndroidShortcutSpec {
  AndroidShortcutSpec({required this.shortLabel, required this.longLabel});

  final String shortLabel;
  final String longLabel;
}

class ActionSpec {
  ActionSpec({
    required this.id,
    required this.title,
    required this.description,
    required this.shortTitle,
    required this.systemImage,
    required this.phrases,
    required this.parameters,
    required this.openAppWhenRun,
    this.androidShortcut,
  });

  factory ActionSpec.fromYaml(Object? node) {
    if (node is! Map) {
      throw GeneratorConfigException('each action must be a map');
    }
    final id = node['id'];
    if (id is! String || !_isSnakeCase(id)) {
      throw GeneratorConfigException(
        "action 'id' is required and must be snake_case, got '$id'",
      );
    }
    final title = (node['title'] as String?) ?? _titleCase(id);
    final phrasesNode = node['phrases'];
    final phrases =
        phrasesNode is List ? phrasesNode.cast<String>() : const <String>[];
    for (final phrase in phrases) {
      if (!phrase.contains(r'${app}') &&
          !phrase.contains(r'${applicationName}')) {
        throw GeneratorConfigException(
          "action '$id': every Siri phrase must contain \${app} "
          "(Apple requires the application-name token): '$phrase'",
        );
      }
    }
    final parametersNode = node['parameters'];
    final androidNode = node['android_shortcut'];
    return ActionSpec(
      id: id,
      title: title,
      description: (node['description'] as String?) ?? '$title.',
      shortTitle: (node['short_title'] as String?) ?? title,
      systemImage: (node['system_image'] as String?) ?? 'bolt.circle',
      phrases: phrases,
      parameters: parametersNode is List
          ? parametersNode.map(ActionParameter.fromYaml).toList()
          : const <ActionParameter>[],
      openAppWhenRun: (node['open_app_when_run'] as bool?) ?? false,
      androidShortcut: androidNode is Map
          ? AndroidShortcutSpec(
              shortLabel:
                  (androidNode['short_label'] as String?) ?? _titleCase(id),
              longLabel: (androidNode['long_label'] as String?) ??
                  (androidNode['short_label'] as String?) ??
                  _titleCase(id),
            )
          : null,
    );
  }

  final String id;
  final String title;
  final String description;
  final String shortTitle;
  final String systemImage;
  final List<String> phrases;
  final List<ActionParameter> parameters;
  final bool openAppWhenRun;
  final AndroidShortcutSpec? androidShortcut;

  String get swiftStructName => '${_pascalCase(id)}Intent';
}

class GeneratorConfig {
  GeneratorConfig({
    required this.taskPreset,
    required this.actions,
    required this.swiftOutput,
    required this.dartOutput,
    required this.androidTaskLabels,
  });

  factory GeneratorConfig.fromYamlString(String source) {
    final Object? root;
    try {
      root = loadYaml(source);
    } on YamlException catch (e) {
      throw GeneratorConfigException('invalid YAML — ${e.message}');
    }
    if (root is! Map) {
      throw GeneratorConfigException('top level must be a map');
    }
    final actionsNode = root['actions'];
    final actions = actionsNode is List
        ? actionsNode.map(ActionSpec.fromYaml).toList()
        : <ActionSpec>[];
    final ids = <String>{};
    for (final action in actions) {
      if (!ids.add(action.id)) {
        throw GeneratorConfigException("duplicate action id '${action.id}'");
      }
    }
    final taskPreset = TaskPresetMode.parse(root['task_preset']);
    final phraseShortcuts = actions.where((a) => a.phrases.isNotEmpty).length +
        (taskPreset == TaskPresetMode.wrappers ? 3 : 0);
    if (phraseShortcuts > 10) {
      throw GeneratorConfigException(
        'Apple allows at most 10 App Shortcuts per app; '
        'this config declares $phraseShortcuts',
      );
    }
    final outputs = root['output'];
    final labelsNode = root['android_task_labels'];
    return GeneratorConfig(
      taskPreset: taskPreset,
      actions: actions,
      swiftOutput: outputs is Map
          ? (outputs['swift'] as String?) ??
              'ios/Runner/AssistantIntents.g.swift'
          : 'ios/Runner/AssistantIntents.g.swift',
      dartOutput: outputs is Map
          ? (outputs['dart'] as String?) ?? 'lib/assistant_intents.g.dart'
          : 'lib/assistant_intents.g.dart',
      androidTaskLabels: labelsNode is Map
          ? labelsNode.map((k, v) => MapEntry('$k', '$v'))
          : const <String, String>{},
    );
  }

  final TaskPresetMode taskPreset;
  final List<ActionSpec> actions;
  final String swiftOutput;
  final String dartOutput;
  final Map<String, String> androidTaskLabels;
}

const String _generatedHeader =
    '// GENERATED by `dart run flutter_assistant_intents:generate` — '
    'DO NOT EDIT.\n'
    '// Source of truth: assistant_intents.yaml\n';

/// Emits the host's Swift file: custom intents, optional task-preset
/// wrappers (or `AppIntentsPackage` re-export) and one `AppShortcutsProvider`.
String generateSwift(GeneratorConfig config) {
  final buffer = StringBuffer()
    ..writeln(_generatedHeader)
    ..writeln('import AppIntents')
    ..writeln('import flutter_assistant_intents')
    ..writeln();

  for (final action in config.actions) {
    _writeCustomIntent(buffer, action);
  }

  if (config.taskPreset == TaskPresetMode.wrappers) {
    buffer.writeln(_taskWrapperIntents);
  }
  if (config.taskPreset == TaskPresetMode.package) {
    buffer.writeln('''
/// Re-exports the plugin's built-in task intents so App Intents metadata
/// extraction finds them (requires iOS 17 at runtime for the re-export).
@available(iOS 17.0, *)
struct GeneratedAppIntentsPackage: AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] {
        [FlutterAssistantIntentsPackage.self]
    }
}
''');
  }

  _writeShortcutsProvider(buffer, config);
  return buffer.toString();
}

void _writeCustomIntent(StringBuffer buffer, ActionSpec action) {
  buffer.writeln('''
/// ${action.description}
@available(iOS 16.0, *)
struct ${action.swiftStructName}: AppIntent {
    static var title: LocalizedStringResource = ${_swiftString(action.title)}
    static var description = IntentDescription(${_swiftString(action.description)})
    static var openAppWhenRun: Bool = ${action.openAppWhenRun}
''');
  for (final parameter in action.parameters) {
    final dialog = parameter.dialog == null
        ? ''
        : ', requestValueDialog: ${_swiftString(parameter.dialog!)}';
    final optionalMark = parameter.optional ? '?' : '';
    buffer
      ..writeln(
        '    @Parameter(title: ${_swiftString(parameter.title)}$dialog)',
      )
      ..writeln(
        '    var ${_camelCase(parameter.name)}: '
        '${parameter.type.swiftType}$optionalMark',
      )
      ..writeln();
  }
  buffer.writeln(
    '    func perform() async throws -> some IntentResult & ProvidesDialog {',
  );
  if (action.parameters.isEmpty) {
    buffer.writeln(
      '        let result = try await AssistantIntentBridge.shared'
      '.performAction(id: ${_swiftString(action.id)})',
    );
  } else {
    buffer.writeln('        var parameters: [String: Any] = [:]');
    for (final parameter in action.parameters) {
      final name = _camelCase(parameter.name);
      if (parameter.optional) {
        buffer.writeln(
          '        if let $name = $name '
          '{ parameters[${_swiftString(parameter.name)}] = $name }',
        );
      } else {
        buffer.writeln(
          '        parameters[${_swiftString(parameter.name)}] = $name',
        );
      }
    }
    buffer.writeln(
      '        let result = try await AssistantIntentBridge.shared'
      '.performAction(id: ${_swiftString(action.id)}, '
      'parameters: parameters)',
    );
  }
  buffer.writeln('''
        return .result(dialog: IntentDialog(stringLiteral:
            result.message ?? (result.success ? "Done." : "Sorry, that failed.")
        ))
    }
}
''');
}

void _writeShortcutsProvider(StringBuffer buffer, GeneratorConfig config) {
  final withPhrases =
      config.actions.where((a) => a.phrases.isNotEmpty).toList();
  final hasWrappers = config.taskPreset == TaskPresetMode.wrappers;
  if (withPhrases.isEmpty && !hasWrappers) return;

  buffer.writeln('''
/// Siri phrases for the generated intents.
@available(iOS 16.0, *)
struct GeneratedAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {''');
  if (hasWrappers) buffer.writeln(_taskWrapperShortcuts);
  for (final action in withPhrases) {
    buffer
      ..writeln('        AppShortcut(')
      ..writeln('            intent: ${action.swiftStructName}(),')
      ..writeln('            phrases: [');
    for (final phrase in action.phrases) {
      buffer.writeln('                ${_swiftPhrase(phrase)},');
    }
    buffer
      ..writeln('            ],')
      ..writeln('            shortTitle: ${_swiftString(action.shortTitle)},')
      ..writeln(
        '            systemImageName: ${_swiftString(action.systemImage)}',
      )
      ..writeln('        )');
  }
  buffer
    ..writeln('    }')
    ..writeln('}');
}

/// Emits the Dart glue: action-id constants and the Android shortcuts config.
String generateDart(GeneratorConfig config) {
  final buffer = StringBuffer()
    ..writeln(_generatedHeader)
    ..writeln("import 'package:flutter_assistant_intents/"
        "flutter_assistant_intents.dart';")
    ..writeln();
  for (final action in config.actions) {
    buffer
      ..writeln('/// Action id of "${action.title}" — handle it in '
          '`onAction`.')
      ..writeln(
        "const String ${_camelCase(action.id)}Action = '${action.id}';",
      )
      ..writeln();
  }
  final labels = config.androidTaskLabels;
  buffer
    ..writeln('/// Android shortcuts declared in assistant_intents.yaml.')
    ..writeln('/// Pass to `AssistantIntents.instance.updateShortcuts`.')
    ..writeln('const AndroidShortcutsConfig generatedAndroidShortcuts =')
    ..writeln('    AndroidShortcutsConfig(')
    ..writeln(
      '  publishTaskShortcuts: '
      '${config.taskPreset != TaskPresetMode.none},',
    );
  for (final entry in const [
    ('add_task_label', 'addTaskLabel'),
    ('add_task_long_label', 'addTaskLongLabel'),
    ('today_label', 'queryTodayLabel'),
    ('today_long_label', 'queryTodayLongLabel'),
  ]) {
    final value = labels[entry.$1];
    if (value != null) {
      buffer.writeln('  ${entry.$2}: ${_dartString(value)},');
    }
  }
  final shortcuts =
      config.actions.where((a) => a.androidShortcut != null).toList();
  if (shortcuts.isNotEmpty) {
    buffer.writeln('  customShortcuts: [');
    for (final action in shortcuts) {
      final spec = action.androidShortcut!;
      buffer
        ..writeln('    AndroidCustomShortcut(')
        ..writeln("      id: '${action.id}',")
        ..writeln("      action: '${action.id}',")
        ..writeln('      shortLabel: ${_dartString(spec.shortLabel)},')
        ..writeln('      longLabel: ${_dartString(spec.longLabel)},')
        ..writeln('    ),');
    }
    buffer.writeln('  ],');
  }
  buffer.writeln(');');
  return buffer.toString();
}

/// Registers [fileName] (already on disk next to AppDelegate.swift) in an
/// old-style Xcode project. Returns the updated pbxproj content, or the
/// input unchanged when the file is already registered or the project uses
/// file-system-synchronized groups (which pick the file up automatically).
String injectIntoPbxproj(String pbxproj, String fileName) {
  if (pbxproj.contains(fileName)) return pbxproj;
  if (pbxproj.contains('PBXFileSystemSynchronizedRootGroup')) return pbxproj;

  final anchor = RegExp(
    r'([0-9A-F]{24}) /\* AppDelegate\.swift \*/ = \{isa = PBXFileReference',
  ).firstMatch(pbxproj);
  final buildAnchor = RegExp(
    r'([0-9A-F]{24}) /\* AppDelegate\.swift in Sources \*/ = '
    r'\{isa = PBXBuildFile',
  ).firstMatch(pbxproj);
  if (anchor == null || buildAnchor == null) {
    throw GeneratorConfigException(
      'could not find AppDelegate.swift anchors in project.pbxproj — '
      'add $fileName to the Runner target manually in Xcode',
    );
  }
  final fileRefId = _deterministicId('$fileName-ref');
  final buildFileId = _deterministicId('$fileName-build');

  var result = pbxproj;
  result = result.replaceFirst(
    '/* Begin PBXBuildFile section */',
    '/* Begin PBXBuildFile section */\n'
        '\t\t$buildFileId /* $fileName in Sources */ = '
        '{isa = PBXBuildFile; fileRef = $fileRefId /* $fileName */; };',
  );
  result = result.replaceFirst(
    '/* Begin PBXFileReference section */',
    '/* Begin PBXFileReference section */\n'
        '\t\t$fileRefId /* $fileName */ = {isa = PBXFileReference; '
        'fileEncoding = 4; lastKnownFileType = sourcecode.swift; '
        'path = "$fileName"; sourceTree = "<group>"; };',
  );
  // Group children: right after AppDelegate.swift's entry in the Runner group.
  result = result.replaceFirst(
    RegExp('\\t+${anchor.group(1)} /\\* AppDelegate\\.swift \\*/,\n'),
    '\t\t\t\t${anchor.group(1)} /* AppDelegate.swift */,\n'
    '\t\t\t\t$fileRefId /* $fileName */,\n',
  );
  // Sources build phase: right after AppDelegate.swift's build entry.
  result = result.replaceFirst(
    RegExp('\\t+${buildAnchor.group(1)} /\\* AppDelegate\\.swift in '
        'Sources \\*/,\n'),
    '\t\t\t\t${buildAnchor.group(1)} /* AppDelegate.swift in Sources */,\n'
    '\t\t\t\t$buildFileId /* $fileName in Sources */,\n',
  );
  if (!result.contains('$fileRefId /* $fileName */,') ||
      !result.contains('$buildFileId /* $fileName in Sources */,')) {
    throw GeneratorConfigException(
      'failed to register $fileName in project.pbxproj — '
      'add it to the Runner target manually in Xcode',
    );
  }
  return result;
}

/// Default `assistant_intents.yaml` written by `generate --init`.
String scaffoldTemplate() => r'''
# Configuration for `dart run flutter_assistant_intents:generate`.
#
# task_preset — how the built-in task intents (AddTask/CompleteTask/QueryTasks)
# surface on iOS:
#   package  — re-export the plugin's compiled intents (iOS 17+; default)
#   wrappers — generate them into the Runner target (iOS 16.0+, most robust)
#   none     — custom actions only
task_preset: package

# Optional output overrides:
# output:
#   swift: ios/Runner/AssistantIntents.g.swift
#   dart: lib/assistant_intents.g.dart

# Optional Android labels for the built-in task shortcuts (localize here):
# android_task_labels:
#   add_task_label: Add task
#   add_task_long_label: Add a new task
#   today_label: Today
#   today_long_label: Show today's tasks

# Custom, app-defined actions. Each one becomes:
#  - an iOS AppIntent with your Siri phrases (${app} = the app-name token),
#  - optionally an Android launcher shortcut,
#  - a Dart constant + entry in `generatedAndroidShortcuts`.
# Handle them in `AssistantIntents.instance.registerHandlers(onAction: ...)`.
actions:
  - id: example_action
    title: Example Action
    description: Describe what the assistant does here.
    short_title: Example
    system_image: bolt.circle
    phrases:
      - "Run my example in ${app}"
    parameters:
      - name: note
        type: string
        title: Note
        optional: true
    android_shortcut:
      short_label: Example
      long_label: Run my example
''';

// --- Task preset wrappers (Swift) ---

const String _taskWrapperIntents = r'''
/// Adds a task to the app's list (task-preset wrapper).
@available(iOS 16.0, *)
struct AddTaskHostIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Task"
    static var description = IntentDescription("Adds a new task to your list.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Title", requestValueDialog: "What should the task be called?")
    var taskTitle: String

    @Parameter(title: "Due date")
    var dueDate: Date?

    @Parameter(title: "Notes")
    var notes: String?

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let result = try await AssistantIntentBridge.shared.performAddTask(
            title: taskTitle, dueDate: dueDate, notes: notes
        )
        return .result(dialog: IntentDialog(stringLiteral:
            result.message ?? (result.success ? "Done. Task added." : "Sorry, the task could not be added.")
        ))
    }
}

/// Marks a task as completed (task-preset wrapper).
@available(iOS 16.0, *)
struct CompleteTaskHostIntent: AppIntent {
    static var title: LocalizedStringResource = "Complete Task"
    static var description = IntentDescription("Marks a task from your list as done.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Task", requestValueDialog: "Which task should be completed?")
    var taskTitle: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let result = try await AssistantIntentBridge.shared.performCompleteTask(title: taskTitle)
        return .result(dialog: IntentDialog(stringLiteral:
            result.message ?? (result.success ? "Done. Task completed." : "Sorry, I could not find that task.")
        ))
    }
}

/// Filter for QueryTasksHostIntent (task-preset wrapper).
@available(iOS 16.0, *)
enum HostTaskFilter: String, AppEnum {
    case today
    case all

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Task Filter"
    static var caseDisplayRepresentations: [HostTaskFilter: DisplayRepresentation] = [
        .today: "Today",
        .all: "All",
    ]
}

/// Reads back the user's tasks (task-preset wrapper).
@available(iOS 16.0, *)
struct QueryTasksHostIntent: AppIntent {
    static var title: LocalizedStringResource = "Show Tasks"
    static var description = IntentDescription("Tells you which tasks are on your list.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Filter", default: .today)
    var filter: HostTaskFilter

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let tasks = try await AssistantIntentBridge.shared
            .performQueryTasks(filter: filter.rawValue)
            .filter { !$0.isCompleted }
        let scope = filter == .today ? " for today" : ""
        if tasks.isEmpty {
            return .result(dialog: IntentDialog(stringLiteral: "You have no tasks\(scope)."))
        }
        let titles = tasks.prefix(5).map(\.title).joined(separator: ", ")
        let suffix = tasks.count > 5 ? ", and \(tasks.count - 5) more" : ""
        let plural = tasks.count == 1 ? "task" : "tasks"
        return .result(dialog: IntentDialog(stringLiteral:
            "You have \(tasks.count) \(plural)\(scope): " + titles + suffix + "."
        ))
    }
}
''';

const String _taskWrapperShortcuts = '''
        AppShortcut(
            intent: AddTaskHostIntent(),
            phrases: [
                "Add a task in \\(.applicationName)",
                "Add a task to \\(.applicationName)",
                "Create a task in \\(.applicationName)",
                "New task in \\(.applicationName)",
            ],
            shortTitle: "Add Task",
            systemImageName: "plus.circle"
        )
        AppShortcut(
            intent: CompleteTaskHostIntent(),
            phrases: [
                "Complete a task in \\(.applicationName)",
                "Finish a task in \\(.applicationName)",
                "Mark a task done in \\(.applicationName)",
            ],
            shortTitle: "Complete Task",
            systemImageName: "checkmark.circle"
        )
        AppShortcut(
            intent: QueryTasksHostIntent(),
            phrases: [
                "What are my tasks in \\(.applicationName)",
                "Show my \\(.applicationName) tasks",
                "What's on my \\(.applicationName) list today",
            ],
            shortTitle: "Show Tasks",
            systemImageName: "list.bullet.circle"
        )''';

// --- Helpers ---

String _swiftString(String value) =>
    '"${value.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';

String _dartString(String value) =>
    "'${value.replaceAll(r'\', r'\\').replaceAll("'", r"\'")}'";

/// Converts `${app}` / `${applicationName}` into the Swift
/// `\(.applicationName)` token inside a phrase literal.
String _swiftPhrase(String phrase) {
  final escaped = phrase
      .replaceAll(r'\', r'\\')
      .replaceAll('"', r'\"')
      .replaceAll(r'${app}', r'\(.applicationName)')
      .replaceAll(r'${applicationName}', r'\(.applicationName)');
  return '"$escaped"';
}

String _pascalCase(String snake) => snake
    .split('_')
    .where((part) => part.isNotEmpty)
    .map((part) => part[0].toUpperCase() + part.substring(1))
    .join();

String _camelCase(String snake) {
  final pascal = _pascalCase(snake);
  return pascal[0].toLowerCase() + pascal.substring(1);
}

String _titleCase(String snake) => snake
    .split('_')
    .where((part) => part.isNotEmpty)
    .map((part) => part[0].toUpperCase() + part.substring(1))
    .join(' ');

bool _isSnakeCase(String value) => RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(value);

bool _isSnakeOrCamel(String value) =>
    RegExp(r'^[a-zA-Z][a-zA-Z0-9_]*$').hasMatch(value);

/// Stable 24-hex-char Xcode object id derived from [seed], so repeated runs
/// produce identical pbxproj edits.
String _deterministicId(String seed) {
  var h1 = 0x811c9dc5;
  var h2 = 0x01000193;
  var h3 = 0xdeadbeef;
  for (final unit in seed.codeUnits) {
    h1 = ((h1 ^ unit) * 0x01000193) & 0xffffffff;
    h2 = ((h2 + unit) * 0x85ebca6b) & 0xffffffff;
    h3 = ((h3 ^ (unit << 3)) * 0xc2b2ae35) & 0xffffffff;
  }
  return (h1.toRadixString(16).padLeft(8, '0') +
          h2.toRadixString(16).padLeft(8, '0') +
          h3.toRadixString(16).padLeft(8, '0'))
      .toUpperCase();
}
