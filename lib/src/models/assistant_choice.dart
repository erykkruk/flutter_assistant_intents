/// How the assistant presents one option of a confirmation prompt.
///
/// Maps to `IntentChoiceOption.Style` on iOS 26 and above.
enum AssistantChoiceStyle {
  /// An ordinary option.
  normal('normal'),

  /// An option that destroys data, highlighted accordingly by the system.
  destructive('destructive'),

  /// The option that backs out without doing anything.
  cancel('cancel');

  const AssistantChoiceStyle(this.wireValue);

  /// Value carried over the method channel to the native side.
  final String wireValue;

  /// Decodes a style from its [wireValue], falling back to [normal].
  static AssistantChoiceStyle fromWire(String? value) {
    for (final style in AssistantChoiceStyle.values) {
      if (style.wireValue == value) return style;
    }
    return AssistantChoiceStyle.normal;
  }
}

/// One option the assistant offers before a handler commits.
///
/// Built by [AssistantTaskResult.needsConfirmation]; the [id] comes back to
/// the handler on the follow-up call as `request.choice`.
///
/// ```dart
/// const AssistantChoice(
///   id: 'delete',
///   title: 'Delete them',
///   style: AssistantChoiceStyle.destructive,
/// )
/// ```
class AssistantChoice {
  /// Creates an option shown in the assistant's confirmation prompt.
  const AssistantChoice({
    required this.id,
    required this.title,
    this.style = AssistantChoiceStyle.normal,
  });

  /// App-defined identifier, handed back as `request.choice` when the user
  /// picks this option.
  final String id;

  /// Short, speakable label, for example "Delete them".
  final String title;

  /// How the system presents the option.
  final AssistantChoiceStyle style;

  /// Encodes the option for the method-channel response.
  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'title': title,
        'style': style.wireValue,
      };

  /// The option that backs out without doing anything.
  ///
  /// The assistant styles it as the cancel action; picking it calls the
  /// handler again with `request.choice == 'cancel'`.
  static const AssistantChoice cancel = AssistantChoice(
    id: 'cancel',
    title: 'Cancel',
    style: AssistantChoiceStyle.cancel,
  );
}
