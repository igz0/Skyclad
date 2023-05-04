import 'package:flutter/material.dart';
import 'package:bluesky/bluesky.dart' as bsky;
import 'package:timeago/timeago.dart' as timeago;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 別スクリーン
import 'package:skyclad/notifications.dart';
import 'package:skyclad/user_profile.dart';
import 'package:skyclad/timeline.dart';
import 'package:skyclad/login.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  timeago.setLocaleMessages("ja", timeago.JaMessages());

  final sharedPreferences = await SharedPreferences.getInstance();
  final isLoggedIn = sharedPreferences.getString('id') != null;

  final goRouter = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        pageBuilder: (context, state) =>
            MaterialPage(child: isLoggedIn ? const MyApp() : LoginScreen()),
      ),
    ],
  );

  runApp(
    ProviderScope(
      child: MaterialApp.router(
        title: 'Skyclad',
        theme: ThemeData.dark(),
        routerDelegate: goRouter.routerDelegate,
        routeInformationParser: goRouter.routeInformationParser,
      ),
    ),
  );
}

final isLoggedInProvider =
    StateNotifierProvider<IsLoggedInNotifier, bool>((ref) {
  return IsLoggedInNotifier();
});

class IsLoggedInNotifier extends StateNotifier<bool> {
  IsLoggedInNotifier() : super(false);

  void setLoggedIn(bool value) {
    state = value;
  }
}

final currentIndexProvider =
    StateNotifierProvider<CurrentIndexNotifier, int>((ref) {
  return CurrentIndexNotifier();
});

class CurrentIndexNotifier extends StateNotifier<int> {
  CurrentIndexNotifier() : super(0);

  void updateIndex(int newIndex) {
    state = newIndex;
  }
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  final GlobalKey<BlueskyTimelineState> blueskyTimelineKey =
      GlobalKey<BlueskyTimelineState>();

  @override
  Widget build(BuildContext context) {
    int currentIndex = ref.watch(currentIndexProvider);
    return MaterialApp(
      title: 'Skyclad',
      theme: ThemeData.dark(),
      home: Scaffold(
        appBar: currentIndex != 3
            ? AppBar(
                centerTitle: true,
                title: Text([
                  'Timeline',
                  '検索',
                  '通知',
                  'プロフィール',
                ][currentIndex]),
                backgroundColor: Colors.blue[600],
              )
            : null,
        body: [
          BlueskyTimeline(
            timelineKey: blueskyTimelineKey,
          ),
          const Placeholder(),
          const NotificationScreen(),
          UserProfileScreen(actor: dotenv.get('BLUESKY_ID')),
        ][currentIndex],
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            _showCreatePostDialog(context);
          },
          backgroundColor: Colors.blue[600],
          child: const Icon(Icons.edit, color: Colors.white),
        ),
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.search),
              label: '検索',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.notifications),
              label: '通知',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_circle),
              label: 'プロフィール',
            ),
          ],
          currentIndex: currentIndex,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white38,
          showUnselectedLabels: true,
          onTap: (int index) {
            ref.read(currentIndexProvider.notifier).updateIndex(index);
          },
        ),
        drawer: Drawer(
          child: ListView(
            children: [
              const DrawerHeader(
                decoration: BoxDecoration(color: Colors.lightBlue),
                child: Text('Test App'),
              ),
              ListTile(
                title: const Text('ログアウト'),
                onTap: () async {
                  // ログアウト処理
                  final sharedPreferences =
                      await SharedPreferences.getInstance();
                  sharedPreferences.remove('id');
                  sharedPreferences.remove('password');

                  // ログイン画面に遷移
                  // ignore: use_build_context_synchronously
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      // 遷移先のクラス
                      builder: (BuildContext context) => LoginScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        drawerEdgeDragWidth: 0, // ドロワーを開くジェスチャーを無効化
      ),
    );
  }

  // 新しい投稿作成ダイアログを表示
  Future<void> _showCreatePostDialog(BuildContext context) async {
    TextEditingController postController = TextEditingController();
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('新しい投稿を作成'),
          content: TextField(
            controller: postController,
            decoration: const InputDecoration(
              hintText: '投稿内容を入力してください',
            ),
            maxLines: 4,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () async {
                if (postController.text.trim().isNotEmpty) {
                  Navigator.pop(context);

                  await _createPost(postController.text.trim());
                  postController.clear();

                  // コールバックを呼び出してタイムラインを更新
                  // blueskyTimelineKey.currentState!._refreshTimeline();
                }
              },
              child: const Text('投稿'),
            ),
          ],
        );
      },
    );
  }

  // 投稿を作成する
  Future<void> _createPost(String text) async {
    final session = await bsky.createSession(
      identifier: dotenv.get('BLUESKY_ID'),
      password: dotenv.get('BLUESKY_PASSWORD'),
    );
    final bluesky = bsky.Bluesky.fromSession(session.data);
    await bluesky.feeds.createPost(
      text: text,
    );
  }
}
