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
  static const photoMessageKey = ValueKey('photo-message');
  static const composerKey = ValueKey('composer');
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

class Chat {
  const Chat(this.name, this.color, this.message, this.time, {this.unread = 0});

  final String name;
  final Color color;
  final Map<String, String> message;
  final String time;
  final int unread;
}

const _chats = [
  Chat(
    'Maya Chen',
    Color(0xFFEC4899),
    {'en': 'Dinner on Friday? 🍜', 'fr': 'Dîner vendredi ? 🍜'},
    '9:41',
    unread: 2,
  ),
  Chat(
    'Design Team',
    Color(0xFF8B5CF6),
    {'en': 'New mockups are up 🎨', 'fr': 'Les nouvelles maquettes sont là 🎨'},
    '9:30',
    unread: 5,
  ),
  Chat('Leo Martin', Color(0xFF10B981), {
    'en': 'Sounds great, see you there!',
    'fr': 'Parfait, à tout à l’heure !',
  }, '9:12'),
  Chat(
    'Priya Patel',
    Color(0xFFF59E0B),
    {'en': 'Photos from the hike 🏔️', 'fr': 'Les photos de la rando 🏔️'},
    '8:47',
    unread: 1,
  ),
  Chat('Sam Rivera', Color(0xFF3B82F6), {
    'en': 'Can you send the doc?',
    'fr': 'Tu peux m’envoyer le doc ?',
  }, 'Yesterday'),
  Chat('Book Club', Color(0xFFEF4444), {
    'en': 'Next pick: Piranesi 📚',
    'fr': 'Prochain livre : Piranesi 📚',
  }, 'Yesterday'),
  Chat('Noah Kim', Color(0xFF14B8A6), {
    'en': 'Thanks! 🙏',
    'fr': 'Merci ! 🙏',
  }, 'Mon'),
  Chat('Ava Johnson', Color(0xFF6366F1), {
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
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ConversationPage(chat: chat),
              ),
            ),
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
                Text(chat.time, style: Theme.of(context).textTheme.labelSmall),
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

/// One conversation: message bubbles, a shared photo and a reaction.
class ConversationPage extends StatelessWidget {
  const ConversationPage({super.key, required this.chat});

  final Chat chat;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Read in build, not when the page is pushed, so it follows locale
    // changes, such as each screenshot variant.
    final fr = Localizations.localeOf(context).languageCode == 'fr';
    Widget bubble(String text, {required bool mine, Key? key, Widget? child}) {
      return Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          key: key,
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: const BoxConstraints(maxWidth: 280),
          decoration: BoxDecoration(
            color: mine ? scheme.primary : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(18),
          ),
          child:
              child ??
              Text(
                text,
                style: TextStyle(
                  color: mine ? scheme.onPrimary : scheme.onSurface,
                  fontSize: 15,
                ),
              ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: chat.color,
              foregroundColor: Colors.white,
              child: Text(chat.name.split(' ').map((w) => w[0]).take(2).join()),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(chat.name, style: const TextStyle(fontSize: 17)),
                Text(
                  fr ? 'En ligne' : 'Online',
                  style: TextStyle(fontSize: 12, color: scheme.primary),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.videocam_outlined),
          ),
          IconButton(onPressed: () {}, icon: const Icon(Icons.call_outlined)),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                bubble(
                  fr
                      ? 'Tu as vu le coucher de soleil ? 🌅'
                      : 'Did you see the sunset? 🌅',
                  mine: false,
                ),
                bubble(
                  '',
                  mine: false,
                  key: ChatApp.photoMessageKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 220,
                          height: 140,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color(0xFFF59E0B),
                                Color(0xFFEC4899),
                                Color(0xFF6366F1),
                              ],
                            ),
                          ),
                          alignment: Alignment.bottomCenter,
                          child: const Icon(
                            Icons.landscape,
                            size: 64,
                            color: Color(0xCC1E1B4B),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        fr ? 'Au sommet, 19 h 40' : 'From the top, 7:40 pm',
                        style: TextStyle(color: scheme.onSurface, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                bubble(
                  fr
                      ? 'Magnifique ! On y retourne samedi ?'
                      : 'Stunning! Same trail on Saturday?',
                  mine: true,
                ),
                bubble(fr ? 'Carrément 🙌' : 'Absolutely 🙌', mine: false),
                bubble(
                  fr ? 'Je réserve le café 9 h ☕️' : "I'll book coffee at 9 ☕️",
                  mine: true,
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              key: ChatApp.composerKey,
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Text(
                        fr ? 'Message' : 'Message',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: scheme.primary,
                    foregroundColor: scheme.onPrimary,
                    child: const Icon(Icons.send_rounded, size: 20),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
