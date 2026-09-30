import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'png.dart';

/// A small, realistic app for feature tests: an app bar, a list of rows with
/// images, a never-ending progress indicator, and localised strings.
class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  static const rowKey = ValueKey('row-2');
  static const fabKey = ValueKey('fab');
  static const searchKey = ValueKey('search');

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, fontFamily: 'Roboto'),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
        fontFamily: 'Roboto',
      ),
      supportedLocales: const [Locale('en'), Locale('fr')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const _Inbox(),
    );
  }
}

class _Inbox extends StatelessWidget {
  const _Inbox();

  @override
  Widget build(BuildContext context) {
    final french = Localizations.localeOf(context).languageCode == 'fr';
    return Scaffold(
      appBar: AppBar(
        title: Text(french ? 'Messages' : 'Inbox'),
        actions: [
          IconButton(
            key: DemoApp.searchKey,
            onPressed: () {},
            icon: const Icon(Icons.search),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        key: DemoApp.fabKey,
        onPressed: () {},
        child: const Icon(Icons.edit),
      ),
      body: Column(
        children: [
          // Never settles, like a real app's live indicators.
          const LinearProgressIndicator(),
          Expanded(
            child: ListView(
              children: [
                for (var i = 0; i < 12; i++)
                  ListTile(
                    key: ValueKey('row-$i'),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.memory(
                        redPng,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                      ),
                    ),
                    title: Text(french ? 'Conversation $i' : 'Conversation $i'),
                    subtitle: Text(
                      french
                          ? 'Dernier message de la conversation'
                          : 'Latest message in the thread',
                    ),
                    trailing: Text('${9 + i % 3}:4$i'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
