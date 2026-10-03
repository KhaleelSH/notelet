import 'package:material_ui/material_ui.dart';

enum MediaNoteItemLoadState { loading, loaded, failed }

/// Shown in place of media that failed to load.
class MediaNoteItemFailedView extends StatelessWidget {
  const MediaNoteItemFailedView({super.key, required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(96),
      child: FittedBox(
        child: Icon(
          icon,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
