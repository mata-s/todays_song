import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'user_archive_page.dart';

class ListenLaterPage extends StatelessWidget {
  const ListenLaterPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
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
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.arrow_back_ios_new,
                        color: Colors.white,
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        '後で聴く',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              Expanded(
                child: uid == null
                    ? const Center(
                        child: Text(
                          'ログイン情報がありません',
                          style: TextStyle(color: Colors.white70),
                        ),
                      )
                    : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('listen_later')
                            .where('userId', isEqualTo: uid)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            );
                          }

                          final rawDocs = snapshot.data?.docs ?? [];
final seenSongIds = <String>{};

final docs = rawDocs.where((doc) {
  final data = doc.data();

  final songId =
      data['songId'] as String? ?? doc.id;

  if (seenSongIds.contains(songId)) {
    return false;
  }

  seenSongIds.add(songId);
  return true;
}).toList();

                          if (docs.isEmpty) {
                            return const Center(
                              child: Text(
                                'まだ保存した曲がありません',
                                style: TextStyle(color: Colors.white70),
                              ),
                            );
                          }

                          return ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
                            itemCount: docs.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 14),
                            itemBuilder: (context, index) {
                              final data = docs[index].data();

                              final title = data['title'] as String? ?? '';
                              final artist = data['artist'] as String? ?? '';
                              final album = data['album'] as String? ?? '';
                              final artworkUrl =
                                  data['artworkUrl'] as String? ?? '';
                              final note = data['note'] as String? ?? '';
                              final ownerId = data['ownerId'] as String? ?? '';

                              return Dismissible(
                                key: ValueKey(docs[index].id),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 26),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFB94B4B),
                                    borderRadius: BorderRadius.circular(28),
                                  ),
                                  child: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                                onDismissed: (_) async {
                                  await FirebaseFirestore.instance
                                      .collection('listen_later')
                                      .doc(docs[index].id)
                                      .delete();
                                },
                                child: _ListenLaterItem(
                                  title: title,
                                  artist: artist,
                                  album: album,
                                  artworkUrl: artworkUrl,
                                  note: note,
                                  ownerId: ownerId,
                                ),
                              );
                            },
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

class _ListenLaterItem extends StatelessWidget {
  const _ListenLaterItem({
    required this.title,
    required this.artist,
    required this.album,
    required this.artworkUrl,
    required this.note,
    required this.ownerId,
  });

  final String title;
  final String artist;
  final String album;
  final String artworkUrl;
  final String note;
  final String ownerId;

  String get _artistLine => album.isEmpty ? artist : '$artist ・ $album';

  Stream<DocumentSnapshot<Map<String, dynamic>>>? get _ownerStream {
    if (ownerId.trim().isEmpty) return null;
    return FirebaseFirestore.instance.collection('users').doc(ownerId).snapshots();
  }

  String get _searchQuery {
  final parts = [
    title,
    artist,
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

Widget _wrapListenButton({
  required IconData icon,
  required String label,
  required VoidCallback onTap,
}) {
  return Material(
    color: Colors.transparent,
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.white.withOpacity(0.10),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: Colors.white.withOpacity(0.9),
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Icon(
              Icons.open_in_new,
              color: Colors.white.withOpacity(0.45),
              size: 17,
            ),
          ],
        ),
      ),
    ),
  );
}

  void _showDetailSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF243247),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(30),
        ),
      ),
      builder: (context) {
        final screenSize = MediaQuery.of(context).size;
        final artworkSize = (screenSize.width * 0.58).clamp(180.0, 260.0);

        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: screenSize.height * 0.86,
            ),
            child: Stack(
              children: [
                SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 30),
                  child: Column(
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
                      const SizedBox(height: 24),
                      Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: artworkUrl.isEmpty
                              ? Container(
                                  width: artworkSize,
                                  height: artworkSize,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(28),
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
                                  artworkUrl,
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
                      const SizedBox(height: 24),
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _artistLine,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.72),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      _OwnerNameText(
                        ownerStream: _ownerStream,
                        ownerId: ownerId,
                        prefix: 'by ',
                        fontSize: 13,
                        topPadding: 8,
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        'どこで聴く？',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _wrapListenButton(
                        icon: Icons.music_note,
                        label: 'Spotifyで探す',
                        onTap: () => _openUrl(
                          'https://open.spotify.com/search/$_searchQuery',
                        ),
                      ),
                      const SizedBox(height: 10),
                      _wrapListenButton(
                        icon: Icons.library_music_outlined,
                        label: 'Apple Musicで探す',
                        onTap: () => _openUrl(
                          'https://music.apple.com/search?term=$_searchQuery',
                        ),
                      ),
                      const SizedBox(height: 10),
                      _wrapListenButton(
                        icon: Icons.smart_display_outlined,
                        label: 'YouTube Musicで探す',
                        onTap: () => _openUrl(
                          'https://music.youtube.com/search?q=$_searchQuery',
                        ),
                      ),
                      const SizedBox(height: 10),
                      _wrapListenButton(
                        icon: Icons.headphones_outlined,
                        label: 'Amazon Musicで探す',
                        onTap: () => _openUrl(
                          'https://music.amazon.co.jp/search/$_searchQuery',
                        ),
                      ),
                      const SizedBox(height: 10),
                      _wrapListenButton(
                        icon: Icons.play_circle_outline,
                        label: 'YouTubeで探す',
                        onTap: () => _openUrl(
                          'https://www.youtube.com/results?search_query=$_searchQuery',
                        ),
                      ),
                      if (note.isNotEmpty) ...[
                        const SizedBox(height: 22),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.10),
                            ),
                          ),
                          child: Text(
                            note,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.92),
                              fontSize: 15,
                              height: 1.6,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 14,
                  child: Material(
                    color: Colors.white.withOpacity(0.10),
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      customBorder: const CircleBorder(),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          Icons.close_rounded,
                          color: Colors.white.withOpacity(0.82),
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        onTap: () => _showDetailSheet(context),
        borderRadius: BorderRadius.circular(28),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.14),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withOpacity(0.16),
            ),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: artworkUrl.isEmpty
                    ? Container(
                        width: 82,
                        height: 82,
                        decoration: BoxDecoration(
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
                              width: 52,
                              height: 52,
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
                              color: Colors.white.withOpacity(0.70),
                              size: 30,
                            ),
                          ],
                        ),
                      )
                    : Image.network(
                        artworkUrl,
                        width: 82,
                        height: 82,
                        fit: BoxFit.cover,
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _artistLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.72),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    _OwnerNameText(
                      ownerStream: _ownerStream,
                      ownerId: ownerId,
                      prefix: 'by ',
                      fontSize: 12,
                      topPadding: 6,
                      enableNavigation: false,
                    ),
                    if (note.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        note,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.90),
                          fontSize: 13,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: Colors.white.withOpacity(0.45),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _OwnerNameText extends StatelessWidget {
  const _OwnerNameText({
    required this.ownerStream,
    required this.ownerId,
    required this.prefix,
    required this.fontSize,
    required this.topPadding,
    this.enableNavigation = true,
  });

  final Stream<DocumentSnapshot<Map<String, dynamic>>>? ownerStream;
  final String prefix;
  final double fontSize;
  final double topPadding;
  final String ownerId;
  final bool enableNavigation;

  @override
  Widget build(BuildContext context) {
    final stream = ownerStream;
    if (stream == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final displayName = data?['displayName'] as String? ?? '';

        if (displayName.trim().isEmpty) {
          return const SizedBox.shrink();
        }

final nameText = Text(
  '$prefix${displayName.trim()}',
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
  style: TextStyle(
    color: Colors.white.withOpacity(0.52),
    fontSize: fontSize,
    fontWeight: FontWeight.w600,
  ),
);

if (!enableNavigation) {
  return Padding(
    padding: EdgeInsets.only(top: topPadding),
    child: nameText,
  );
}

return Padding(
  padding: EdgeInsets.only(top: topPadding),
  child: Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: ownerId.trim().isEmpty
          ? null
          : () {
              Navigator.of(context).pop();

              Future.microtask(() {
                if (!context.mounted) return;

                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => UserArchivePage(
                      userId: ownerId,
                      displayName: displayName.trim(),
                    ),
                  ),
                );
              });
            },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 2,
          vertical: 2,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: nameText),
            const SizedBox(width: 2),
            Icon(
              Icons.chevron_right,
              color: Colors.white.withOpacity(0.34),
              size: fontSize + 2,
            ),
          ],
        ),
      ),
    ),
  ),
);
      },
    );
  }
}