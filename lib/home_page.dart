import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:todays_song/listen_later_page.dart';
import 'post_today_song_page.dart';
import 'my_archive_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'user_archive_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final Set<String> _viewedSongIds = {};
  final Set<String> _swipedSongIds = {};
  final Set<String> _listenLaterSongIds = {};

  String? _loadedSwipedDate;

String get _todayKey => DateTime.now().toIso8601String().substring(0, 10);
String get _swipedSongIdsKey => 'swiped_song_ids_$_todayKey';

@override
void initState() {
  super.initState();
  _loadSwipedSongIds();
}

Future<void> _loadSwipedSongIds() async {
  final prefs = await SharedPreferences.getInstance();
  final today = _todayKey;
  final savedIds = prefs.getStringList(_swipedSongIdsKey) ?? [];

  if (!mounted) return;

  setState(() {
    _loadedSwipedDate = today;
    _swipedSongIds
      ..clear()
      ..addAll(savedIds);
  });
}

Future<void> _saveSwipedSongIds() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setStringList(_swipedSongIdsKey, _swipedSongIds.toList());
}

  Future<void> _recordSongView(SongPost song) async {
    final viewerId = FirebaseAuth.instance.currentUser?.uid;
    if (viewerId == null) return;
    if (song.id.isEmpty) return;
    if (song.userId == viewerId) return;
    if (_viewedSongIds.contains(song.id)) return;

    _viewedSongIds.add(song.id);

    final viewId = '${song.id}_$viewerId';
    final viewRef = FirebaseFirestore.instance.collection('song_views').doc(viewId);
    final songRef = FirebaseFirestore.instance.collection('daily_songs').doc(song.id);

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final viewSnapshot = await transaction.get(viewRef);
        if (viewSnapshot.exists) return;

        transaction.set(viewRef, {
          'songId': song.id,
          'ownerId': song.userId,
          'viewerId': viewerId,
          'createdAt': FieldValue.serverTimestamp(),
        });

        transaction.update(songRef, {
          'viewCount': FieldValue.increment(1),
        });
      });
    } catch (_) {
      _viewedSongIds.remove(song.id);
    }
  }

  Future<void> _toggleListenLater(SongPost song) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    if (song.id.isEmpty) return;

    final laterId = '${userId}_${song.id}';
    final laterRef = FirebaseFirestore.instance.collection('listen_later').doc(laterId);
    final isSaved = _listenLaterSongIds.contains(song.id);

    if (isSaved) {
      _listenLaterSongIds.remove(song.id);
    } else {
      _listenLaterSongIds.add(song.id);
    }

    try {
      if (isSaved) {
        await laterRef.delete();
      } else {
        await laterRef.set({
          'songId': song.id,
          'userId': userId,
          'ownerId': song.userId,
          'title': song.title,
          'artist': song.artist,
          'album': song.album,
          'artworkUrl': song.artworkUrl,
          'note': song.note,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (_) {
      if (isSaved) {
        _listenLaterSongIds.add(song.id);
      } else {
        _listenLaterSongIds.remove(song.id);
      }
    }
  }

  Future<void> _showDisplayNameDialog(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final controller = TextEditingController();

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    controller.text = userDoc.data()?['displayName'] as String? ?? '';

    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF243247),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            '表示名を設定',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: SingleChildScrollView(
            child: TextField(
              controller: controller,
              autofocus: true,
              maxLength: 20,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: '未設定なら匿名になります',
                hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.35),
                ),
                counterStyle: TextStyle(
                  color: Colors.white.withOpacity(0.45),
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: Colors.white.withOpacity(0.25),
                  ),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'キャンセル',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.65),
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                final displayName = controller.text.trim();

                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .set({
                  'displayName': displayName,
                  'updatedAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));

                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              },
              child: const Text(
                '保存',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDrawerProfile(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final displayName = data?['displayName'] as String? ?? '';
        final visibleName = displayName.trim().isEmpty ? '匿名' : displayName.trim();

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showDisplayNameDialog(context),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 18),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.16),
                      ),
                    ),
                    child: const Icon(
                      Icons.person_outline,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          visibleName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          displayName.trim().isEmpty ? '表示名を設定' : '表示名を変更',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.58),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: Colors.white.withOpacity(0.45),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now().toIso8601String().substring(0, 10);

    if (_loadedSwipedDate != today) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadSwipedSongIds();
        }
      });
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
      drawer: Drawer(
        backgroundColor: const Color(0xFF182235),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDrawerProfile(context),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Divider(
                  color: Colors.white.withOpacity(0.12),
                  height: 1,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(
                  Icons.library_music_outlined,
                  color: Colors.white,
                ),
                title: const Text(
                  'アーカイブ',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const MyArchivePage(),
                      ),
                    );
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.favorite_border,
                  color: Colors.white,
                ),
                title: const Text(
                  '後で聴く',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ListenLaterPage(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.settings_outlined,
                  color: Colors.white,
                ),
                title: const Text(
                  '設定',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const SettingsPage(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF7DA2C7),
              Color(0xFF243247),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Builder(
                      builder: (context) {
                        return Material(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(18),
                          child: InkWell(
                            onTap: () {
                              Scaffold.of(context).openDrawer();
                            },
                            borderRadius: BorderRadius.circular(18),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.18),
                                ),
                              ),
                              child: const Icon(
                                Icons.person_outline,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    Expanded(
                      child: Center(
                        child: Image.asset(
                          'assets/logo/onesong_logo.png',
                          height: 50,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    _PostTodayButton(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const PostTodaySongPage(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('daily_songs')
                      .where('postedDate', isEqualTo: today)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          '読み込みに失敗しました',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                      );
                    }

                    final songDocs = [...(snapshot.data?.docs ?? [])]
                      ..sort((a, b) => a.id.hashCode.compareTo(b.id.hashCode));
                    final allSongs = songDocs
                        .map((doc) => SongPost.fromFirestore(doc))
                        .toList();
                    final songs = allSongs
                        .where((song) => !_swipedSongIds.contains(song.id))
                        .toList();

                    if (songs.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                allSongs.isEmpty
                                    ? Icons.music_note_outlined
                                    : Icons.check_circle_outline,
                                color: Colors.white.withOpacity(0.72),
                                size: 42,
                              ),
                              const SizedBox(height: 14),
                              Text(
                                allSongs.isEmpty
                                    ? 'まだ今日は誰も置いていません'
                                    : '今日の曲は見終わりました',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.82),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (allSongs.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'また新しい一曲が置かれたら表示されます',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.58),
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }

                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted && songs.isNotEmpty) {
                        _recordSongView(songs.first);
                      }
                    });

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: CardSwiper(
                        cardsCount: songs.length,
                        isLoop: false,
                        numberOfCardsDisplayed: songs.length >= 2 ? 2 : 1,
                        backCardOffset: const Offset(0, 14),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        allowedSwipeDirection: const AllowedSwipeDirection.only(
                          left: true,
                          right: true,
                        ),
                        onSwipe: (previousIndex, currentIndex, direction) {
                          if (previousIndex >= 0 && previousIndex < songs.length) {
                            _swipedSongIds.add(songs[previousIndex].id);
                            _saveSwipedSongIds();
                          }
                          
                          if (currentIndex != null && currentIndex < songs.length) {
                            _recordSongView(songs[currentIndex]);
                          }
                          
                          return true;
                        },
                        onEnd: () {
                          for (final song in songs) {
                            _swipedSongIds.add(song.id);
                          }
                          _saveSwipedSongIds();
                          setState(() {});
                        },
                        cardBuilder: (
                          context,
                          index,
                          horizontalThresholdPercentage,
                          verticalThresholdPercentage,
                        ) {
                          return _SongCard(
                            key: ValueKey(songs[index].id),
                            song: songs[index],
                            isListenLater: _listenLaterSongIds.contains(songs[index].id),
                            onListenLaterTap: () => _toggleListenLater(songs[index]),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostTodayButton extends StatelessWidget {
  const _PostTodayButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.18),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withOpacity(0.18),
            ),
          ),
          child: const Icon(
            Icons.add,
            color: Colors.white,
            size: 26,
          ),
        ),
      ),
    );
  }
}

class _SongCard extends StatefulWidget {
  const _SongCard({
    super.key,
    required this.song,
    required this.isListenLater,
    required this.onListenLaterTap,
  });

  final SongPost song;
  final bool isListenLater;
  final VoidCallback onListenLaterTap;

  @override
  State<_SongCard> createState() => _SongCardState();
}

class _SongCardState extends State<_SongCard> {
  late bool _isListenLater;

  @override
  void initState() {
    super.initState();
    _isListenLater = widget.isListenLater;
  }

  void _handleListenLaterTap() {
    setState(() {
      _isListenLater = !_isListenLater;
    });

    widget.onListenLaterTap();
  }

  String get _searchQuery {
  final parts = [
    widget.song.title,
    widget.song.artist,
  ].where((text) => text.trim().isNotEmpty).join(' ');

  return Uri.encodeComponent(parts);
}

Future<void> _openUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;

  await launchUrl(
    uri,
    mode: LaunchMode.externalApplication,
  );
}

void _showListenSheet() {
  final query = _searchQuery;
  if (query.isEmpty) return;

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF243247),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(28),
      ),
    ),
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'どこで聴く？',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 18),

              _listenTile(
                icon: Icons.music_note,
                title: 'Spotifyで探す',
                onTap: () {
                  Navigator.pop(context);
                  _openUrl(
                    'https://open.spotify.com/search/$query',
                  );
                },
              ),

              _listenTile(
                icon: Icons.library_music_outlined,
                title: 'Apple Musicで探す',
                onTap: () {
                  Navigator.pop(context);
                  _openUrl(
                    'https://music.apple.com/search?term=$query',
                  );
                },
              ),

              _listenTile(
                icon: Icons.smart_display_outlined,
                title: 'YouTube Musicで探す',
                onTap: () {
                  Navigator.pop(context);
                  _openUrl(
                    'https://music.youtube.com/search?q=$query',
                  );
                },
              ),

              _listenTile(
                icon: Icons.headphones_outlined,
                title: 'Amazon Musicで探す',
                onTap: () {
                  Navigator.pop(context);
                  _openUrl(
                    'https://music.amazon.co.jp/search/$query',
                  );
                },
              ),

              _listenTile(
                icon: Icons.play_circle_outline,
                title: 'YouTubeで探す',
                onTap: () {
                  Navigator.pop(context);
                  _openUrl(
                    'https://www.youtube.com/results?search_query=$query',
                  );
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

Widget _listenTile({
  required IconData icon,
  required String title,
  required VoidCallback onTap,
}) {
  return Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 14,
          horizontal: 4,
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final cardHeight = (screenSize.height * 0.72).clamp(420.0, 640.0);
    final artworkSize = (screenSize.width * 0.58).clamp(170.0, 260.0);
    final noteMaxLines = screenSize.height < 700 ? 3 : 5;

    return SizedBox(
      height: cardHeight,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF465A78),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: Colors.white.withOpacity(0.10),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.28),
              blurRadius: 30,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(screenSize.height < 700 ? 16 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
Material(
  color: Colors.transparent,
  child: InkWell(
    onTap: widget.song.userId == null || widget.song.userId!.isEmpty
        ? null
        : () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => UserArchivePage(
                  userId: widget.song.userId!,
                  displayName: widget.song.displayName,
                ),
              ),
            );
          },
    borderRadius: BorderRadius.circular(18),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.white.withOpacity(0.12),
            child: const Icon(
              Icons.person,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SongOwnerName(song: widget.song),
                const SizedBox(height: 2),
                _RelativePostTime(createdAt: widget.song.createdAt),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: Colors.white.withOpacity(0.32),
            size: 20,
          ),
        ],
      ),
    ),
  ),
),
              const SizedBox(height: 16),
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: widget.song.artworkUrl.isEmpty
                      ? Container(
                          width: artworkSize,
                          height: artworkSize,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withOpacity(0.16),
                                Colors.white.withOpacity(0.06),
                              ],
                            ),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: artworkSize * 0.62,
                                height: artworkSize * 0.62,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.06),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.08),
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.album_rounded,
                                color: Colors.white.withOpacity(0.68),
                                size: artworkSize * 0.34,
                              ),
                            ],
                          ),
                        )
                      : Image.network(
                          widget.song.artworkUrl,
                          width: artworkSize,
                          height: artworkSize,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: artworkSize,
                              height: artworkSize,
                              color: Colors.white.withOpacity(0.10),
                              child: Icon(
                                Icons.broken_image_outlined,
                                color: Colors.white.withOpacity(0.55),
                                size: 64,
                              ),
                            );
                          },
                        ),
                ),
              ),
              SizedBox(height: screenSize.height < 700 ? 14 : 18),
              Text(
                widget.song.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: screenSize.height < 700 ? 22 : 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.song.album.isEmpty
                    ? widget.song.artist
                    : '${widget.song.artist} ・ ${widget.song.album}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: screenSize.height < 700 ? 10 : 12),
              if (widget.song.note.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: _NotePreview(
                    note: widget.song.note,
                    maxLines: noteMaxLines,
                  ),
                ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                    child: InkWell(
                      onTap: _showListenSheet,
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.20),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.16),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white.withOpacity(0.92),
                              size: 20,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '聴く',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.94),
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                    child: InkWell(
                      onTap: _handleListenLaterTap,
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          color: _isListenLater
                              ? Colors.white.withOpacity(0.26)
                              : Colors.white.withOpacity(0.20),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.16),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isListenLater
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: Colors.white.withOpacity(0.92),
                              size: 18,
                            ),
                            const SizedBox(width: 7),
                            Text(
                              _isListenLater ? '保存済み' : '後で聴く',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.94),
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SongOwnerName extends StatelessWidget {
  const _SongOwnerName({required this.song});

  final SongPost song;

  @override
  Widget build(BuildContext context) {
    final visibleName = song.displayName.trim().isEmpty
        ? '匿名'
        : song.displayName.trim();

    return Text(
      visibleName,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _RelativePostTime extends StatelessWidget {
  const _RelativePostTime({required this.createdAt});

  final DateTime? createdAt;

  String _formatRelativeTime() {
    if (createdAt == null) return '今日';

    final diff = DateTime.now().difference(createdAt!);

    if (diff.inMinutes < 1) return 'たった今';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分前';
    if (diff.inHours < 24) return '${diff.inHours}時間前';

    return '今日';
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _formatRelativeTime(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: Colors.white54,
        fontSize: 12,
      ),
    );
  }
}

class SongPost {
  const SongPost({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.artworkUrl,
    required this.note,
    required this.userId,
    required this.displayName,
    required this.viewCount,
    required this.createdAt,
  });

  factory SongPost.fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final createdAtTimestamp = data['createdAt'] as Timestamp?;

    return SongPost(
      id: doc.id,
      title: data['title'] as String? ?? '',
      artist: data['artist'] as String? ?? '',
      album: data['album'] as String? ?? '',
      artworkUrl: data['artworkUrl'] as String? ?? '',
      note: data['note'] as String? ?? '',
      userId: data['userId'] as String?,
      displayName: data['displayName'] as String? ?? '',
      viewCount: data['viewCount'] as int? ?? 0,
      createdAt: createdAtTimestamp?.toDate(),
    );
  }

  final String id;
  final String title;
  final String artist;
  final String album;
  final String artworkUrl;
  final String note;
  final String? userId;
  final String displayName;
  final int viewCount;
  final DateTime? createdAt;
}

class _NotePreview extends StatelessWidget {
  const _NotePreview({
    required this.note,
    required this.maxLines,
  });

  final String note;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(
      color: Colors.white,
      height: 1.5,
      fontSize: 15,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: note, style: textStyle),
          maxLines: maxLines,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: constraints.maxWidth);

        final hasOverflow = painter.didExceedMaxLines;

        void showFullNoteSheet() {
          showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            backgroundColor: const Color(0xFF243247),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            builder: (context) {
              return SafeArea(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.78,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 42,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        const Text(
                          'この曲に残したこと',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Flexible(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Text(
                              note,
                              style: const TextStyle(
                                color: Colors.white,
                                height: 1.6,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: hasOverflow ? showFullNoteSheet : null,
              child: Text(
                note,
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
                style: textStyle,
              ),
            ),
            if (hasOverflow) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: showFullNoteSheet,
                child: Text(
                  'もっと見る',
                  style: TextStyle(
                    color: const Color(0xFFD7ECFF).withOpacity(0.9),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
