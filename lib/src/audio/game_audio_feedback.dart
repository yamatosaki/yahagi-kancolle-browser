import 'package:flutter/widgets.dart';

import '../localization/runtime_message_text.dart';

/// Native and preference errors can coexist; translate each app-owned wrapper.
String gameAudioErrorText(BuildContext context, String error) => error
    .split('\n')
    .map((line) => runtimeMessageText(context, line))
    .join('\n');
