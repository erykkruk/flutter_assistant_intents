/// `dart run flutter_assistant_intents:generate`
///
/// Reads `assistant_intents.yaml` from the app root and generates:
///  - the iOS Swift App Intents file (registered in project.pbxproj),
///  - the Dart glue file (action-id constants + Android shortcuts config).
///
/// Flags:
///  --init             write a starter assistant_intents.yaml and exit
///  --config <path>    config file (default: assistant_intents.yaml)
///  --dry-run          print what would be written, change nothing
library;

import 'dart:io';

import 'package:flutter_assistant_intents/src/generator/generator.dart';

const String _defaultConfigPath = 'assistant_intents.yaml';

Future<void> main(List<String> arguments) async {
  final dryRun = arguments.contains('--dry-run');
  final configIndex = arguments.indexOf('--config');
  final configPath = configIndex >= 0 && configIndex + 1 < arguments.length
      ? arguments[configIndex + 1]
      : _defaultConfigPath;
  final configFile = File(configPath);

  if (arguments.contains('--init')) {
    if (configFile.existsSync()) {
      _fail('$configPath already exists — refusing to overwrite.');
    }
    configFile.writeAsStringSync(scaffoldTemplate());
    stdout.writeln('Wrote starter $configPath — edit it, then run '
        '`dart run flutter_assistant_intents:generate`.');
    return;
  }

  if (!configFile.existsSync()) {
    _fail('$configPath not found. Run '
        '`dart run flutter_assistant_intents:generate --init` '
        'to create a starter config.');
  }

  final GeneratorConfig config;
  try {
    config = GeneratorConfig.fromYamlString(configFile.readAsStringSync());
  } on GeneratorConfigException catch (e) {
    _fail('$e');
  }

  final swift = generateSwift(config);
  final dart = generateDart(config);

  if (dryRun) {
    stdout
      ..writeln('--- ${config.swiftOutput} ---')
      ..writeln(swift)
      ..writeln('--- ${config.dartOutput} ---')
      ..writeln(dart);
    return;
  }

  _writeFile(config.swiftOutput, swift);
  _writeFile(config.dartOutput, dart);

  final pbxprojFile = File('ios/Runner.xcodeproj/project.pbxproj');
  final swiftFileName = config.swiftOutput.split('/').last;
  if (pbxprojFile.existsSync()) {
    try {
      final original = pbxprojFile.readAsStringSync();
      final updated = injectIntoPbxproj(original, swiftFileName);
      if (updated != original) {
        pbxprojFile.writeAsStringSync(updated);
        stdout.writeln('Registered $swiftFileName in project.pbxproj.');
      }
    } on GeneratorConfigException catch (e) {
      stderr.writeln('WARNING: $e');
    }
  } else {
    stdout.writeln('NOTE: ios/Runner.xcodeproj not found — if this app has '
        'an iOS target elsewhere, add $swiftFileName to it manually.');
  }

  stdout
    ..writeln('Generated:')
    ..writeln('  ${config.swiftOutput}')
    ..writeln('  ${config.dartOutput}')
    ..writeln('Actions: ${config.actions.map((a) => a.id).join(', ')} '
        '(task preset: ${config.taskPreset.name})');
}

void _writeFile(String path, String content) {
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(content);
}

Never _fail(String message) {
  stderr.writeln(message);
  exit(64);
}
