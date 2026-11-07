import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../characters/models/character_model.dart';
import '../../characters/presentation/character_appearance.dart';
import '../../shell/vilka_controller.dart';
import '../../shell/vilka_scope.dart';

/// Окно диалога с выбранной женой.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = VilkaScope.of(context);
    final character = controller.selected;
    final scheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        Column(
          children: [
            _ChatHeader(character: character),
            Expanded(
              child: controller.messages.isEmpty
                  ? const _EmptyChat()
                  : ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      itemCount: controller.messages.length,
                      itemBuilder: (context, index) {
                        final entry = controller
                            .messages[controller.messages.length - 1 - index];
                        return _Bubble(entry: entry);
                      },
                    ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('chat-input'),
                        controller: _input,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        enabled: !controller.busy && !controller.recording,
                        onSubmitted: controller.busy ? null : _submit,
                        decoration: InputDecoration(
                          hintText: character == null
                              ? 'Сначала выберите характер'
                              : 'Напишите ${character.name}',
                          filled: true,
                          fillColor: scheme.surfaceContainerHighest,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      key: const Key('send-button'),
                      tooltip: 'Отправить',
                      onPressed: controller.busy ? null : _submit,
                      icon: const Icon(Icons.send),
                    ),
                    const SizedBox(width: 4),
                    IconButton.filled(
                      key: const Key('mic-button'),
                      tooltip: 'Микрофон',
                      style: IconButton.styleFrom(
                        minimumSize: const Size(56, 56),
                        backgroundColor: scheme.tertiary,
                        foregroundColor: scheme.onTertiary,
                      ),
                      onPressed: controller.busy || controller.speaking
                          ? null
                          : controller.beginListening,
                      icon: const Icon(Icons.mic),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (controller.recording)
          _ListeningOverlay(onDone: () => controller.endListening()),
      ],
    );
  }

  void _submit([String? _]) {
    final text = _input.text;
    _input.clear();
    VilkaScope.of(context).sendMessage(text);
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({required this.character});

  final CharacterProfile? character;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mood = moodOf(character?.affectionLevel ?? 0.5);
    return Material(
      color: scheme.surfaceContainerLow,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          child: Icon(iconForCharacter(character?.id)),
        ),
        title: Text(
          character?.name ?? 'Характер не выбран',
          key: const Key('chat-title'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          character == null ? 'Откройте вкладку «Управление»' : mood.label,
          key: const Key('mood-label'),
        ),
        trailing: character == null
            ? null
            : Text(mood.emoji, style: const TextStyle(fontSize: 24)),
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Напишите сообщение или нажмите микрофон',
        style: Theme.of(context).textTheme.bodyLarge,
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.entry});

  final ChatEntry entry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fromUser = entry.fromUser;
    return Align(
      alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: fromUser
              ? scheme.primaryContainer
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(fromUser ? 18 : 4),
            bottomRight: Radius.circular(fromUser ? 4 : 18),
          ),
        ),
        child: Text(entry.text),
      ),
    );
  }
}

class _ListeningOverlay extends StatefulWidget {
  const _ListeningOverlay({required this.onDone});

  final VoidCallback onDone;

  @override
  State<_ListeningOverlay> createState() => _ListeningOverlayState();
}

class _ListeningOverlayState extends State<_ListeningOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.scrim.withValues(alpha: 0.55),
      child: Center(
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Слушаю…', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  'Запись имитируется. После остановки шёпот проверит локальный детектор.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                AnimatedBuilder(
                  animation: _wave,
                  builder: (context, _) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(5, (index) {
                        final phase = (_wave.value + index * 0.12) % 1;
                        final height =
                            14 +
                            34 * (0.5 + 0.5 * math.sin(phase * math.pi * 2));
                        return Container(
                          width: 8,
                          height: height,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        );
                      }),
                    );
                  },
                ),
                const SizedBox(height: 24),
                FilledButton(
                  key: const Key('listen-done'),
                  onPressed: widget.onDone,
                  child: const Text('Готово'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
