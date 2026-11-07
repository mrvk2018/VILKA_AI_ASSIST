import 'package:flutter/material.dart';

import '../../scheduler/models/initiative_alarm_model.dart';
import '../../shell/vilka_controller.dart';
import '../../shell/vilka_scope.dart';
import '../models/character_model.dart';
import 'character_appearance.dart';

/// Карусель характеров и список будильников инициативы.
class ControlPanelScreen extends StatelessWidget {
  const ControlPanelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = VilkaScope.of(context);
    final selectedId = controller.selected?.id;
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text('Жёны', style: Theme.of(context).textTheme.titleLarge),
        ),
        SizedBox(
          height: 188,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: controller.profiles.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final profile = controller.profiles[index];
              return _CharacterCard(
                profile: profile,
                selected: profile.id == selectedId,
                onTap: () => controller.selectCharacter(profile.id),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            'Будильники инициативы',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              key: const Key('add-alarm'),
              onPressed: () => _addAlarm(context, controller),
              icon: const Icon(Icons.add),
              label: const Text('Добавить будильник'),
            ),
          ),
        ),
        if (controller.alarms.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text('Будильников пока нет'),
          )
        else
          for (final alarm in controller.alarms)
            _AlarmTile(alarm: alarm, controller: controller),
      ],
    );
  }

  Future<void> _addAlarm(
    BuildContext context,
    VilkaController controller,
  ) async {
    final created = await showDialog<InitiativeAlarm>(
      context: context,
      builder: (context) => const _AlarmEditorDialog(),
    );
    if (!context.mounted || created == null) return;
    await controller.addAlarm(created);
  }
}

class _CharacterCard extends StatelessWidget {
  const _CharacterCard({
    required this.profile,
    required this.selected,
    required this.onTap,
  });

  final CharacterProfile profile;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mood = moodOf(profile.affectionLevel);
    return SizedBox(
      width: 220,
      child: Card(
        key: Key('character-${profile.id}'),
        margin: EdgeInsets.zero,
        elevation: selected ? 0 : 1,
        color: selected ? scheme.primaryContainer : scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: scheme.secondaryContainer,
                      child: Icon(iconForCharacter(profile.id)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        profile.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  mood.label,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: profile.affectionLevel.clamp(0, 1),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  formatLastActivity(profile.lastInteractionTime),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AlarmTile extends StatelessWidget {
  const _AlarmTile({required this.alarm, required this.controller});

  final InitiativeAlarm alarm;
  final VilkaController controller;

  @override
  Widget build(BuildContext context) {
    final time =
        '${alarm.hour.toString().padLeft(2, '0')}:'
        '${alarm.minute.toString().padLeft(2, '0')}';
    return ListTile(
      title: Text(time, style: Theme.of(context).textTheme.titleMedium),
      subtitle: Text('${formatDays(alarm.daysOfWeek)}\n${alarm.topic}'),
      isThreeLine: true,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: Key('test-alarm-${alarm.id}'),
            tooltip: 'Тест',
            onPressed: controller.busy
                ? null
                : () => controller.testAlarm(alarm),
            icon: const Icon(Icons.play_circle_outline),
          ),
          Switch(
            value: alarm.isEnabled,
            onChanged: (enabled) => controller.setAlarmEnabled(alarm, enabled),
          ),
        ],
      ),
    );
  }
}

class _AlarmEditorDialog extends StatefulWidget {
  const _AlarmEditorDialog();

  @override
  State<_AlarmEditorDialog> createState() => _AlarmEditorDialogState();
}

class _AlarmEditorDialogState extends State<_AlarmEditorDialog> {
  final _topic = TextEditingController();
  TimeOfDay _time = const TimeOfDay(hour: 7, minute: 30);
  final _days = <int>{1, 2, 3, 4, 5};

  @override
  void dispose() {
    _topic.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final labels = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    return AlertDialog(
      title: const Text('Новый будильник'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Время'),
              subtitle: Text(_time.format(context)),
              trailing: const Icon(Icons.schedule),
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: _time,
                );
                if (picked == null) return;
                setState(() => _time = picked);
              },
            ),
            TextField(
              key: const Key('alarm-topic'),
              controller: _topic,
              decoration: const InputDecoration(
                labelText: 'Тема',
                hintText: 'Разбуди меня на работу',
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              children: [
                for (var day = 1; day <= 7; day++)
                  FilterChip(
                    label: Text(labels[day - 1]),
                    selected: _days.contains(day),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _days.add(day);
                        } else {
                          _days.remove(day);
                        }
                      });
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          key: const Key('save-alarm'),
          onPressed: _save,
          child: const Text('Сохранить'),
        ),
      ],
    );
  }

  void _save() {
    final topic = _topic.text.trim();
    if (topic.isEmpty) return;
    Navigator.pop(
      context,
      InitiativeAlarm(
        id: 'alarm-${DateTime.now().microsecondsSinceEpoch}',
        hour: _time.hour,
        minute: _time.minute,
        topic: topic,
        isEnabled: true,
        daysOfWeek: _days.toList()..sort(),
      ),
    );
  }
}

String formatLastActivity(String? iso) {
  final parsed = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
  if (parsed == null) return 'Ещё не общались';
  final day = parsed.day.toString().padLeft(2, '0');
  final month = parsed.month.toString().padLeft(2, '0');
  final hour = parsed.hour.toString().padLeft(2, '0');
  final minute = parsed.minute.toString().padLeft(2, '0');
  return 'Была $day.$month $hour:$minute';
}

String formatDays(List<int> days) {
  const labels = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
  if (days.isEmpty) return 'Без дней';
  final sorted = [...days]..sort();
  if (sorted.length == 7) return 'Каждый день';
  return sorted.map((day) => labels[day - 1]).join(' ');
}
