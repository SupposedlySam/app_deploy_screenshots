import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() => runApp(const ChatApp());

/// A small chat app used to demonstrate `app_deploy_screenshots`.
///
/// It follows the system theme and locale, which is all the package needs to
/// render light, dark and translated screenshots.
class ChatApp extends StatelessWidget {
  const ChatApp({super.key, this.fontFamilyFallback});

  /// Extra fallback fonts. The screenshot test passes the package's emoji
  /// font here; a production app can leave it null.
  final List<String>? fontFamilyFallback;

  static const searchKey = ValueKey('search');
  static const composeKey = ValueKey('compose');
  static const photosKey = ValueKey('photos-chat');

  @override
  Widget build(BuildContext context) {
    ThemeData theme(Brightness brightness) => ThemeData(
      colorSchemeSeed: const Color(0xFF4F46E5),
      brightness: brightness,
      fontFamilyFallback: fontFamilyFallback,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Chatter',
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      themeMode: ThemeMode.system,
      supportedLocales: const [Locale('en'), Locale('fr')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const InboxPage(),
    );
  }
}

class _Chat {
  const _Chat(this.name, this.color, this.message, this.time, {this.unread = 0});

  final String name;
  final Color color;
  final Map<String, String> message;
  final String time;
  final int unread;
}

const _chats = [
  _Chat('Maya Chen', Color(0xFFEC4899), {
    'en': 'Dinner on Friday? 🍜',
    'fr': 'Dîner vendredi ? 🍜',
  }, '9:41', unread: 2),
  _Chat('Design Team', Color(0xFF8B5CF6), {
    'en': 'New mockups are up 🎨',
    'fr': 'Les nouvelles maquettes sont là 🎨',
  }, '9:30', unread: 5),
  _Chat('Leo Martin', Color(0xFF10B981), {
    'en': 'Sounds great, see you there!',
    'fr': 'Parfait, à tout à l’heure !',
  }, '9:12'),
  _Chat('Priya Patel', Color(0xFFF59E0B), {
    'en': 'Photos from the hike 🏔️',
    'fr': 'Les photos de la rando 🏔️',
  }, '8:47', unread: 1),
  _Chat('Sam Rivera', Color(0xFF3B82F6), {
    'en': 'Can you send the doc?',
    'fr': 'Tu peux m’envoyer le doc ?',
  }, 'Yesterday'),
  _Chat('Book Club', Color(0xFFEF4444), {
    'en': 'Next pick: Piranesi 📚',
    'fr': 'Prochain livre : Piranesi 📚',
  }, 'Yesterday'),
  _Chat('Noah Kim', Color(0xFF14B8A6), {
    'en': 'Thanks! 🙏',
    'fr': 'Merci ! 🙏',
  }, 'Mon'),
  _Chat('Ava Johnson', Color(0xFF6366F1), {
    'en': 'Running 5 min late',
    'fr': 'J’ai 5 min de retard',
  }, 'Mon'),
];

class InboxPage extends StatelessWidget {
  const InboxPage({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode == 'fr'
        ? 'fr'
        : 'en';
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(lang == 'fr' ? 'Discussions' : 'Chats'),
        actions: [
          IconButton(
            key: ChatApp.searchKey,
            onPressed: () {},
            icon: const Icon(Icons.search),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        key: ChatApp.composeKey,
        onPressed: () {},
        child: const Icon(Icons.edit_outlined),
      ),
      body: ListView.builder(
        itemCount: _chats.length,
        itemBuilder: (context, i) {
          final chat = _chats[i];
          return ListTile(
            key: i == 3 ? ChatApp.photosKey : null,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            leading: CircleAvatar(
              radius: 24,
              backgroundColor: chat.color,
              foregroundColor: Colors.white,
              child: Text(
                chat.name.split(' ').map((w) => w[0]).take(2).join(),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            title: Text(
              chat.name,
              style: TextStyle(
                fontWeight: chat.unread > 0 ? FontWeight.w700 : null,
              ),
            ),
            subtitle: Text(
              chat.message[lang]!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  chat.time,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const SizedBox(height: 6),
                if (chat.unread > 0)
                  Badge(
                    label: Text('${chat.unread}'),
                    backgroundColor: scheme.primary,
                    textColor: scheme.onPrimary,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
