import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserArchivePage extends StatelessWidget {
  const UserArchivePage({
    super.key,
    required this.userId,
    required this.displayName,
  });

  final String userId;
  final String displayName;

  @override
  Widget build(BuildContext context) {
    final visibleName = displayName.trim().isEmpty ? '匿名' : displayName.trim();

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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.arrow_back_ios_new,
                        color: Colors.white,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '$visibleName のアーカイブ',
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
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
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('daily_songs')
                      .where('userId', isEqualTo: userId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      );
                    }

                    final docs = snapshot.data?.docs ?? [];

                    if (docs.isEmpty) {
                      return const Center(
                        child: Text(
                          'まだ投稿がありません',
                          style: TextStyle(color: Colors.white70),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final data = docs[index].data();

                        final title = data['title'] as String? ?? '';
                        final artist = data['artist'] as String? ?? '';
                        final album = data['album'] as String? ?? '';
                        final artworkUrl = data['artworkUrl'] as String? ?? '';
                        final note = data['note'] as String? ?? '';
                        final postedDate = data['postedDate'] as String? ?? '';
                        final songId = docs[index].id;
                        final ownerId = data['userId'] as String? ?? '';

                        return _UserArchiveItem(
                          title: title,
                          artist: artist,
                          album: album,
                          artworkUrl: artworkUrl,
                          note: note,
                          postedDate: postedDate,
                          displayName: visibleName,
                          songId: songId,
                          ownerId: ownerId,
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
class _UserArchiveItem extends StatelessWidget {
  const _UserArchiveItem({
    required this.title,
    required this.artist,
    required this.album,
    required this.artworkUrl,
    required this.note,
    required this.postedDate,
    required this.displayName,
    required this.songId,
    required this.ownerId,
  });

  final String title;
  final String artist;
  final String album;
  final String artworkUrl;
  final String note;
  final String postedDate;
  final String displayName;
  final String songId;
  final String ownerId;

  String get _artistLine => album.isEmpty ? artist : '$artist ・ $album';

  String get _formattedDate {
    if (postedDate.isEmpty) return '';
    final parts = postedDate.split('-');
    if (parts.length != 3) return postedDate.replaceAll('-', '/');
    final year = parts[0];
    final month = int.tryParse(parts[1])?.toString() ?? parts[1];
    final day = int.tryParse(parts[2])?.toString() ?? parts[2];
    return '$year/$month/$day';
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

  Future<void> _saveListenLater(BuildContext context) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final laterId = '${user.uid}_$songId';

  await FirebaseFirestore.instance.collection('listen_later').doc(laterId).set({
    'songId': songId,
    'userId': user.uid,
    'ownerId': ownerId,
    'title': title,
    'artist': artist,
    'album': album,
    'artworkUrl': artworkUrl,
    'note': note,
    'createdAt': FieldValue.serverTimestamp(),
  });

  if (!context.mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('後で聴くに保存しました'),
    ),
  );
}

Stream<DocumentSnapshot<Map<String, dynamic>>>? _listenLaterStream() {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return null;

  final laterId = '${user.uid}_$songId';
  return FirebaseFirestore.instance
      .collection('listen_later')
      .doc(laterId)
      .snapshots();
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

  Widget _artwork(double size, double radius) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: artworkUrl.isEmpty
          ? Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
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
                    width: size * 0.62,
                    height: size * 0.62,
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
                    size: size * 0.34,
                  ),
                ],
              ),
            )
          : Image.network(
              artworkUrl,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: size,
                  height: size,
                  color: Colors.white.withOpacity(0.10),
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white.withOpacity(0.55),
                    size: size * 0.28,
                  ),
                );
              },
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
                      Center(child: _artwork(artworkSize, 28)),
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
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              _artistLine,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.72),
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                            stream: _listenLaterStream(),
                            builder: (context, snapshot) {
                              final isSaved = snapshot.data?.exists ?? false;

                              return Material(
                                color: isSaved
                                    ? const Color(0xFFFFD7E1).withOpacity(0.24)
                                    : Colors.white.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(999),
                                child: InkWell(
                                  onTap: isSaved
                                      ? null
                                      : () async {
                                          await _saveListenLater(context);
                                          if (context.mounted) {
                                            Navigator.of(context).pop();
                                          }
                                        },
                                  borderRadius: BorderRadius.circular(999),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 9,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isSaved
                                              ? Icons.favorite
                                              : Icons.favorite_border,
                                          color: isSaved
                                              ? const Color(0xFFFFC1D1)
                                              : Colors.white.withOpacity(0.88),
                                          size: 17,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          isSaved ? '保存済み' : '後で聴く',
                                          style: TextStyle(
                                            color: isSaved
                                                ? const Color(0xFFFFD7E1)
                                                : Colors.white.withOpacity(0.90),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
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
                        const SizedBox(height: 24),
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
              _artwork(82, 20),
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
                    if (note.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        note,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.90),
                          fontSize: 13,
                          height: 1.45,
                        ),
                      ),
                    ],
                    if (_formattedDate.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        _formattedDate,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.48),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
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