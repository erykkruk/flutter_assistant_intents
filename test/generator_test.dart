import 'package:flutter_assistant_intents/src/generator/generator.dart';
import 'package:flutter_test/flutter_test.dart';

const String _config = r'''
task_preset: package
android_task_labels:
  today_label: Na dzisiaj
actions:
  - id: order_coffee
    title: Order Coffee
    description: Orders a coffee.
    short_title: Coffee
    system_image: cup.and.saucer
    phrases:
      - "Order a coffee in ${app}"
    parameters:
      - name: size
        type: string
        title: Size
        optional: true
        dialog: Which size?
      - name: shots
        type: int
        optional: false
    android_shortcut:
      short_label: Coffee
      long_label: Order a coffee
  - id: clear_completed
    phrases:
      - "Clean up my tasks in ${applicationName}"
''';

void main() {
  group('GeneratorConfig', () {
    test('parses the full schema', () {
      final config = GeneratorConfig.fromYamlString(_config);

      expect(config.taskPreset, TaskPresetMode.package);
      expect(config.actions, hasLength(2));
      final coffee = config.actions.first;
      expect(coffee.id, 'order_coffee');
      expect(coffee.parameters, hasLength(2));
      expect(coffee.parameters.first.optional, isTrue);
      expect(coffee.parameters.last.type, ActionParameterType.int);
      expect(coffee.androidShortcut!.longLabel, 'Order a coffee');
      final cleanup = config.actions.last;
      expect(cleanup.title, 'Clear Completed', reason: 'derived from id');
      expect(cleanup.androidShortcut, isNull);
      expect(config.androidTaskLabels['today_label'], 'Na dzisiaj');
    });

    test('rejects a phrase without the app-name token', () {
      expect(
        () => GeneratorConfig.fromYamlString('''
actions:
  - id: bad
    phrases: ["Do the thing"]
'''),
        throwsA(isA<GeneratorConfigException>()),
      );
    });

    test('rejects duplicate ids, bad ids and bad task_preset', () {
      expect(
        () => GeneratorConfig.fromYamlString(
          'actions:\n  - id: a_b\n  - id: a_b\n',
        ),
        throwsA(isA<GeneratorConfigException>()),
      );
      expect(
        () => GeneratorConfig.fromYamlString('actions:\n  - id: BadId\n'),
        throwsA(isA<GeneratorConfigException>()),
      );
      expect(
        () => GeneratorConfig.fromYamlString('task_preset: sometimes'),
        throwsA(isA<GeneratorConfigException>()),
      );
    });

    test('rejects more than 10 app shortcuts', () {
      final actions = List.generate(
        11,
        (i) => '  - id: action_$i\n    phrases: ["Go \${app}"]',
      ).join('\n');
      expect(
        () => GeneratorConfig.fromYamlString('actions:\n$actions\n'),
        throwsA(isA<GeneratorConfigException>()),
      );
    });
  });

  group('generateSwift', () {
    test('emits intents, parameters, phrases and the package re-export', () {
      final swift = generateSwift(GeneratorConfig.fromYamlString(_config));

      expect(swift, contains('struct OrderCoffeeIntent: AppIntent'));
      expect(swift, contains('struct ClearCompletedIntent: AppIntent'));
      expect(
        swift,
        contains('@Parameter(title: "Size", requestValueDialog: '
            '"Which size?")'),
      );
      expect(swift, contains('var size: String?'));
      expect(swift, contains('var shots: Int\n'));
      expect(swift, contains('parameters["shots"] = shots'));
      expect(
        swift,
        contains('if let size = size { parameters["size"] = size }'),
      );
      expect(swift, contains(r'"Order a coffee in \(.applicationName)"'));
      expect(swift, contains(r'"Clean up my tasks in \(.applicationName)"'));
      expect(swift, contains('struct GeneratedAppShortcuts'));
      expect(swift, contains('systemImageName: "cup.and.saucer"'));
      expect(swift, contains('struct GeneratedAppIntentsPackage'));
      expect(swift, isNot(contains('AddTaskHostIntent')));
    });

    test('wrappers mode emits the task-preset intents instead', () {
      final swift = generateSwift(
        GeneratorConfig.fromYamlString('task_preset: wrappers'),
      );

      expect(swift, contains('struct AddTaskHostIntent: AppIntent'));
      expect(swift, contains('struct CompleteTaskHostIntent: AppIntent'));
      expect(swift, contains('struct QueryTasksHostIntent: AppIntent'));
      expect(swift, contains('performAddTask'));
      expect(swift, isNot(contains('GeneratedAppIntentsPackage')));
      expect(swift, contains(r'"Add a task in \(.applicationName)"'));
    });
  });

  group('generateDart', () {
    test('emits action constants and the Android shortcuts config', () {
      final dart = generateDart(GeneratorConfig.fromYamlString(_config));

      expect(
        dart,
        contains("const String orderCoffeeAction = 'order_coffee';"),
      );
      expect(
        dart,
        contains("const String clearCompletedAction = 'clear_completed';"),
      );
      expect(dart, contains('publishTaskShortcuts: true'));
      expect(dart, contains("queryTodayLabel: 'Na dzisiaj'"));
      expect(dart, contains("id: 'order_coffee'"));
      expect(dart, contains("shortLabel: 'Coffee'"));
      expect(
        dart,
        isNot(contains('clear_completed,')),
        reason: 'no android_shortcut declared for clear_completed',
      );
    });

    test('task_preset none disables the task shortcuts', () {
      final dart = generateDart(
        GeneratorConfig.fromYamlString('task_preset: none'),
      );

      expect(dart, contains('publishTaskShortcuts: false'));
    });
  });

  group('injectIntoPbxproj', () {
    const pbxproj = '''
/* Begin PBXBuildFile section */
\t\tAAAAAAAAAAAAAAAAAAAAAAAA /* AppDelegate.swift in Sources */ = {isa = PBXBuildFile; fileRef = BBBBBBBBBBBBBBBBBBBBBBBB /* AppDelegate.swift */; };
/* End PBXBuildFile section */
/* Begin PBXFileReference section */
\t\tBBBBBBBBBBBBBBBBBBBBBBBB /* AppDelegate.swift */ = {isa = PBXFileReference; fileEncoding = 4; lastKnownFileType = sourcecode.swift; path = AppDelegate.swift; sourceTree = "<group>"; };
/* End PBXFileReference section */
\t\tchildren = (
\t\t\t\tBBBBBBBBBBBBBBBBBBBBBBBB /* AppDelegate.swift */,
\t\t);
\t\tfiles = (
\t\t\t\tAAAAAAAAAAAAAAAAAAAAAAAA /* AppDelegate.swift in Sources */,
\t\t);
''';

    test('registers the file next to AppDelegate anchors', () {
      final updated = injectIntoPbxproj(pbxproj, 'AssistantIntents.g.swift');

      expect(
        updated,
        contains('/* AssistantIntents.g.swift in Sources */ = '
            '{isa = PBXBuildFile;'),
      );
      expect(updated, contains('path = "AssistantIntents.g.swift"'));
      final childrenIndex =
          updated.indexOf('/* AssistantIntents.g.swift */,\n');
      expect(childrenIndex, greaterThan(0));
    });

    test('is idempotent', () {
      final once = injectIntoPbxproj(pbxproj, 'AssistantIntents.g.swift');
      final twice = injectIntoPbxproj(once, 'AssistantIntents.g.swift');

      expect(twice, once);
    });

    test('leaves synchronized-group projects untouched', () {
      const synced = 'isa = PBXFileSystemSynchronizedRootGroup;';

      expect(injectIntoPbxproj(synced, 'X.g.swift'), synced);
    });

    test('throws when anchors are missing', () {
      expect(
        () => injectIntoPbxproj('not a real pbxproj', 'X.g.swift'),
        throwsA(isA<GeneratorConfigException>()),
      );
    });
  });

  group('removeFromPbxproj', () {
    const pbxproj = '''
/* Begin PBXBuildFile section */
\t\tAAAAAAAAAAAAAAAAAAAAAAAA /* AppDelegate.swift in Sources */ = {isa = PBXBuildFile; fileRef = BBBBBBBBBBBBBBBBBBBBBBBB /* AppDelegate.swift */; };
/* End PBXBuildFile section */
/* Begin PBXFileReference section */
\t\tBBBBBBBBBBBBBBBBBBBBBBBB /* AppDelegate.swift */ = {isa = PBXFileReference; fileEncoding = 4; lastKnownFileType = sourcecode.swift; path = AppDelegate.swift; sourceTree = "<group>"; };
/* End PBXFileReference section */
\t\tchildren = (
\t\t\t\tBBBBBBBBBBBBBBBBBBBBBBBB /* AppDelegate.swift */,
\t\t);
\t\tfiles = (
\t\t\t\tAAAAAAAAAAAAAAAAAAAAAAAA /* AppDelegate.swift in Sources */,
\t\t);
''';

    test('is the exact inverse of injectIntoPbxproj', () {
      final injected = injectIntoPbxproj(pbxproj, 'AssistantIntents.g.swift');
      final removed = removeFromPbxproj(injected, 'AssistantIntents.g.swift');

      expect(removed, pbxproj);
    });

    test('leaves unrelated files and unknown projects untouched', () {
      expect(removeFromPbxproj(pbxproj, 'Other.g.swift'), pbxproj);
      expect(removeFromPbxproj('not a pbxproj', 'X.g.swift'), 'not a pbxproj');
    });
  });

  group('isGeneratedContent', () {
    test('recognizes only files with the generator marker', () {
      expect(
        isGeneratedContent(
          generateDart(GeneratorConfig.fromYamlString(_config)),
        ),
        isTrue,
      );
      expect(
        isGeneratedContent(
          generateSwift(GeneratorConfig.fromYamlString(_config)),
        ),
        isTrue,
      );
      expect(isGeneratedContent('import Foundation\n// hand-written'), isFalse);
      expect(isGeneratedContent(''), isFalse);
    });
  });

  group('scaffoldTemplate', () {
    test('is itself a valid config', () {
      final config = GeneratorConfig.fromYamlString(scaffoldTemplate());

      expect(config.taskPreset, TaskPresetMode.package);
      expect(config.actions.single.id, 'example_action');
    });
  });
}
