import 'package:material_ui/material_ui.dart';
import 'package:notelet/notelet.dart';

/// Release notes for different versions of the app.
///
/// There are three note types: `.list`, `.image` and `.video`. Images and
/// videos can come from the network or from the app's assets.
const releaseNotes = <NoteletVersionNotes>[
  NoteletVersionNotes(
    // Matches `version` in this app's pubspec.yaml.
    version: '1.0.0',
    items: [
      .list(
        title: "What's new",
        rows: [
          NoteletListRow(
            icon: Icons.auto_fix_high,
            title: 'New editor tools',
            description: 'More formatting options with less taps.',
          ),
          NoteletListRow(
            icon: Icons.shield,
            title: 'Privacy update',
            description: 'Sensitive data handling is now stricter.',
          ),
        ],
      ),
      .image(
        image: .network('https://picsum.photos/id/1018/1000/1000'),
        title: 'Updated UI',
        description: 'Refreshed visuals across key screens.',
      ),
      .video(
        video: .network(
          'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
        ),
        title: 'Quick walkthrough',
        description: 'A short clip showing the new flow.',
      ),
    ],
  ),
  NoteletVersionNotes(
    version: '0.9.0',
    items: [
      .image(
        image: .network('https://picsum.photos/id/1043/1000/1000'),
        title: 'Journal Archive',
        description: 'Archive entries without deleting them permanently.',
      ),
    ],
  ),
];

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Notelet',
      theme: ThemeData(colorSchemeSeed: Colors.blue),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.blue,
        brightness: Brightness.dark,
      ),
      // Shows this version's notes on launch until the user dismisses them.
      home: NoteletSheet(
        notes: releaseNotes,
        version: .current,
        child: const HomeScreen(),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notelet')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.new_releases_outlined),
            title: const Text("What's new in 1.0.0"),
            onTap: () => showNoteletSheet(
              context: context,
              notes: releaseNotes,
              version: .v('1.0.0'),
              configuration: const NoteletConfiguration(
                accentColor: Colors.orange,
                sheetHeight: .full,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text("What's new in 0.9.0"),
            onTap: () => showNoteletSheet(
              context: context,
              notes: releaseNotes,
              version: .v('0.9.0'),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.restart_alt),
            title: const Text('Reset seen version'),
            subtitle: const Text('Shows the notes again on next launch'),
            onTap: () async {
              await const NoteletStorage().resetSeenVersion();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Seen version reset')),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
