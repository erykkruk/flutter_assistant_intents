Pod::Spec.new do |s|
  s.name             = 'flutter_assistant_intents'
  s.version          = '1.0.0'
  s.summary          = 'Voice-assistant task actions for Flutter apps — iOS App Intents + Android shortcuts.'
  s.description      = <<-DESC
Expose task-app actions to voice assistants. On iOS this plugin ships App Intents
(AddTaskIntent, CompleteTaskIntent, QueryTasksIntent) plus an AppShortcutsProvider so
Siri, Spotlight and the Shortcuts app can drive any Flutter task/todo app through a
typed Dart handler API.
                       DESC
  s.homepage         = 'https://github.com/erykkruk/flutter_assistant_intents'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = { 'Eryk Kruk' => 'eryk.kruk@codigee.com' }
  s.source           = { :http => 'https://github.com/erykkruk/flutter_assistant_intents' }
  s.source_files     = 'Classes/**/*.swift'
  s.dependency 'Flutter'
  s.platform         = :ios, '16.0'
  s.swift_version    = '5.9'

  s.frameworks = 'Foundation'
  s.weak_frameworks = 'AppIntents'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
  }
end
