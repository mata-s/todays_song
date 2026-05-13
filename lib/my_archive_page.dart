import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'post_today_song_page.dart';

class MyArchivePage extends StatelessWidget {
  const MyArchivePage({super.key});

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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    _GlassIconButton(
                      icon: Icons.arrow_back_ios_new,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const Expanded(
                      child: Text(
                        'アーカイブ',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 44),
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
                            .collection('daily_songs')
                            .where('userId', isEqualTo: uid)
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
                              final viewCount = data['viewCount'] as int? ?? 0;
                              final postedDate = data['postedDate'] as String? ?? '';
                              final formattedDate = postedDate.isEmpty
                                  ? ''
                                  : postedDate.replaceAll('-', '/').replaceFirst('/0', '/');
                              final songId = docs[index].id;

                              return Dismissible(
                                key: ValueKey(songId),
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
                                confirmDismiss: (_) async {
                                  return await showDialog<bool>(
                                        context: context,
                                        builder: (dialogContext) {
                                          return AlertDialog(
                                            backgroundColor:
                                                const Color(0xFF243247),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(24),
                                            ),
                                            title: const Text(
                                              '投稿を削除しますか？',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            content: Text(
                                              '「$title」をアーカイブから削除します。',
                                              style: TextStyle(
                                                color: Colors.white
                                                    .withOpacity(0.82),
                                                height: 1.5,
                                              ),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () {
                                                  Navigator.of(dialogContext)
                                                      .pop(false);
                                                },
                                                child: Text(
                                                  'キャンセル',
                                                  style: TextStyle(
                                                    color: Colors.white
                                                        .withOpacity(0.65),
                                                  ),
                                                ),
                                              ),
                                              TextButton(
                                                onPressed: () {
                                                  Navigator.of(dialogContext)
                                                      .pop(true);
                                                },
                                                child: const Text(
                                                  '削除',
                                                  style: TextStyle(
                                                    color: Color(0xFFFF8D8D),
                                                    fontWeight:
                                                        FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      ) ??
                                      false;
                                },
                                onDismissed: (_) async {
                                  await FirebaseFirestore.instance
                                      .collection('daily_songs')
                                      .doc(songId)
                                      .delete();
                                },
                                child: _MyArchiveItem(
                                  songId: songId,
                                  title: title,
                                  artist: artist,
                                  album: album,
                                  artworkUrl: artworkUrl,
                                  note: note,
                                  viewCount: viewCount,
                                  formattedDate: formattedDate,
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

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.16),
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
          child: Icon(
            icon,
            color: Colors.white,
            size: 21,
          ),
        ),
      ),
    );
  }
}
class _MyArchiveItem extends StatelessWidget {
  const _MyArchiveItem({
    required this.title,
    required this.artist,
    required this.album,
    required this.artworkUrl,
    required this.note,
    required this.viewCount,
    required this.formattedDate,
    required this.songId,
  });

  final String title;
  final String artist;
  final String album;
  final String artworkUrl;
  final String note;
  final int viewCount;
  final String formattedDate;
  final String songId;

  String get _artistLine => album.isEmpty ? artist : '$artist ・ $album';

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
                      const SizedBox(height: 44),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Material(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(999),
                          child: InkWell(
                            onTap: () {
                              Navigator.of(context).pop();
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => PostTodaySongPage(
                                    editingSongId: songId,
                                    initialTitle: title,
                                    initialArtist: artist,
                                    initialAlbum: album,
                                    initialArtworkUrl: artworkUrl,
                                    initialNote: note,
                                  ),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(999),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 9,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.edit_outlined,
                                    color: Colors.white.withOpacity(0.88),
                                    size: 17,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '編集',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.90),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
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
                      Text(
                        _artistLine,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.72),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
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
                      if (formattedDate.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Text(
                            formattedDate,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.42),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
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
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 22,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _artwork(82, 20),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            formattedDate,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.62),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.13),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '$viewCount 届いた',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.82),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
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
            ],
          ),
        ),
      ),
    );
  }
}