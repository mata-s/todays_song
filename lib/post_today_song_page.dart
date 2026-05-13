import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PostTodaySongPage extends StatefulWidget {
  const PostTodaySongPage({
    super.key,
    this.editingSongId,
    this.initialTitle = '',
    this.initialArtist = '',
    this.initialAlbum = '',
    this.initialArtworkUrl = '',
    this.initialNote = '',
  });

  final String? editingSongId;
  final String initialTitle;
  final String initialArtist;
  final String initialAlbum;
  final String initialArtworkUrl;
  final String initialNote;

  bool get isEditing => editingSongId != null;

  @override
  State<PostTodaySongPage> createState() => _PostTodaySongPageState();
}

class _PostTodaySongPageState extends State<PostTodaySongPage> {
  final TextEditingController _songTitleController = TextEditingController();
  final TextEditingController _artistController = TextEditingController();
  final TextEditingController _albumController = TextEditingController();
  final TextEditingController _artworkUrlController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  bool _isPosting = false;
  String _selectedArtworkAsset = '';

  bool get _canPost =>
      _songTitleController.text.trim().isNotEmpty &&
      _artistController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _songTitleController.addListener(_refresh);
    _artistController.addListener(_refresh);
    _albumController.addListener(_refresh);
    _artworkUrlController.addListener(_refresh);
    _noteController.addListener(_refresh);
    if (widget.isEditing) {
      _songTitleController.text = widget.initialTitle;
      _artistController.text = widget.initialArtist;
      _albumController.text = widget.initialAlbum;
      _artworkUrlController.text = widget.initialArtworkUrl;
      _noteController.text = widget.initialNote;
    }
  }

  void _selectArtworkAsset(String assetPath) {
    setState(() {
      _selectedArtworkAsset = assetPath;
      _artworkUrlController.clear();
    });
  }

  void _refresh() {
    setState(() {});
  }

  @override
  void dispose() {
    _songTitleController.dispose();
    _artistController.dispose();
    _albumController.dispose();
    _artworkUrlController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _postTodaySong() async {
    if (!_canPost || _isPosting) return;

    setState(() {
      _isPosting = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      final userDoc = user == null
      ? null
      : await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
      final displayName = userDoc?.data()?['displayName'] as String? ?? '';

      if (widget.isEditing) {
        await FirebaseFirestore.instance
            .collection('daily_songs')
            .doc(widget.editingSongId)
            .update({
          'displayName': displayName,
          'title': _songTitleController.text.trim(),
          'artist': _artistController.text.trim(),
          'album': _albumController.text.trim(),
          'artworkUrl': _artworkUrlController.text.trim(),
          'artworkAsset': _selectedArtworkAsset,
          'note': _noteController.text.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('投稿を保存しました'),
          ),
        );

        Navigator.of(context).pop();
        return;
      }

      await FirebaseFirestore.instance.collection('daily_songs').add({
        'userId': user?.uid,
        'displayName': displayName,
        'title': _songTitleController.text.trim(),
        'artist': _artistController.text.trim(),
        'album': _albumController.text.trim(),
        'artworkUrl': _artworkUrlController.text.trim(),
        'artworkAsset': _selectedArtworkAsset,
        'note': _noteController.text.trim(),
        'postedDate': DateTime.now().toIso8601String().substring(0, 10),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('「${_songTitleController.text.trim()}」を今日の一曲にしました'),
        ),
      );

      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('保存に失敗しました: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPosting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar:
          MediaQuery.of(context).viewInsets.bottom > 0
              ? Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: Container(
                    height: 44,
                    color: const Color(0xFFEEF2F7),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        GestureDetector(
                          onTap: () {
                            FocusScope.of(context).unfocus();
                          },
                          child: const Text(
                            '完了',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.blue,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : null,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1B2440),
              Color(0xFF0B1020),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    _CircleIconButton(
                      icon: Icons.close,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const Expanded(
                      child: Text(
                        '今日の一曲を投稿',
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
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '今日は、どの一曲？',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '紹介したい曲や、あとで振り返りたい曲を選びます。',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.65),
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 32),
                      _SongTextField(
                        controller: _songTitleController,
                        label: '曲名',
                        hintText: '例：ロビンソン',
                        icon: Icons.music_note,
                      ),
                      const SizedBox(height: 14),
                      _SongTextField(
                        controller: _artistController,
                        label: 'アーティスト',
                        hintText: '例：スピッツ',
                        icon: Icons.person,
                      ),
                      const SizedBox(height: 14),
                      _SongTextField(
                        controller: _albumController,
                        label: 'アルバム・シングル名',
                        hintText: '例：ハチミツ',
                        icon: Icons.album,
                      ),
                      const SizedBox(height: 14),
                      _SongTextField(
                        controller: _artworkUrlController,
                        label: '画像URL（任意）',
                        hintText: '使いたい画像URLがあれば貼れます',
                        icon: Icons.image,
                        keyboardType: TextInputType.url,
                      ),
                      const SizedBox(height: 12),
                      _ArtworkAssetPicker(
                        selectedAssetPath: _selectedArtworkAsset,
                        onSelected: _selectArtworkAsset,
                      ),
                      const SizedBox(height: 28),
                      _SelectedSongPreview(
                        title: _songTitleController.text.trim(),
                        artist: _artistController.text.trim(),
                        album: _albumController.text.trim(),
                        artworkUrl: _artworkUrlController.text.trim(),
                        artworkAsset: _selectedArtworkAsset,
                      ),
                      const SizedBox(height: 28),
                      
                      _NoteInputBox(controller: _noteController),
                      const SizedBox(height: 36),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _canPost && !_isPosting ? _postTodaySong : null,
                          style: ElevatedButton.styleFrom(
                            disabledBackgroundColor:
                                Colors.white.withOpacity(0.12),
                            disabledForegroundColor:
                                Colors.white.withOpacity(0.35),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(22),
                            ),
                          ),
                          child: _isPosting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  widget.isEditing ? '編集を保存' : '今日の一曲にする',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SongTextField extends StatelessWidget {
  const _SongTextField({
    required this.controller,
    required this.label,
    required this.hintText,
    required this.icon,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;
  final IconData icon;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Colors.white.withOpacity(0.62),
        ),
        hintText: hintText,
        hintStyle: TextStyle(
          color: Colors.white.withOpacity(0.30),
        ),
        prefixIcon: Icon(
          icon,
          color: Colors.white.withOpacity(0.65),
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(
            color: Colors.white.withOpacity(0.12),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(
            color: Colors.white.withOpacity(0.35),
          ),
        ),
      ),
    );
  }
}

class _ArtworkAssetPicker extends StatelessWidget {
  const _ArtworkAssetPicker({
    required this.selectedAssetPath,
    required this.onSelected,
  });

  final String selectedAssetPath;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white.withOpacity(0.65),
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              '画像がない場合は、雰囲気カードを選べます',
              style: TextStyle(
                color: Colors.white.withOpacity(0.58),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 148,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _artworkAssetGroups.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, groupIndex) {
              final group = _artworkAssetGroups[groupIndex];
              return SizedBox(
                width: 188,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 2, bottom: 8),
                      child: Text(
                        group.title,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.70),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: group.items.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final item = group.items[index];
                          final isSelected = item.assetPath == selectedAssetPath;
                          return _ArtworkAssetCard(
                            item: item,
                            isSelected: isSelected,
                            onTap: () => onSelected(item.assetPath),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ArtworkAssetCard extends StatelessWidget {
  const _ArtworkAssetCard({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final _ArtworkAssetItem item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 86,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? Colors.white.withOpacity(0.82)
                : Colors.white.withOpacity(0.12),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.12),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(17),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                item.assetPath,
                fit: BoxFit.cover,
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.50),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (isSelected)
                Positioned(
                  top: 7,
                  right: 7,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.90),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Color(0xFF1B2440),
                      size: 15,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArtworkAssetGroup {
  const _ArtworkAssetGroup({
    required this.title,
    required this.items,
  });

  final String title;
  final List<_ArtworkAssetItem> items;
}

class _ArtworkAssetItem {
  const _ArtworkAssetItem({
    required this.label,
    required this.assetPath,
  });

  final String label;
  final String assetPath;
}

const List<_ArtworkAssetGroup> _artworkAssetGroups = [
  _ArtworkAssetGroup(
    title: '時間・景色',
    items: [
      _ArtworkAssetItem(label: '電車', assetPath: 'assets/time/densilya.png'),
      _ArtworkAssetItem(label: '帰り道', assetPath: 'assets/time/kaerimiti.png'),
      _ArtworkAssetItem(label: '曇り', assetPath: 'assets/time/kumori.png'),
      _ArtworkAssetItem(label: '深夜', assetPath: 'assets/time/shinya.png'),
      _ArtworkAssetItem(label: '夕方', assetPath: 'assets/time/yuugata.png'),
      _ArtworkAssetItem(label: '雨', assetPath: 'assets/time/ame.png'),
      _ArtworkAssetItem(label: '朝', assetPath: 'assets/time/asa.png'),
      _ArtworkAssetItem(label: '青空', assetPath: 'assets/time/aozora.png'),
    ],
  ),
  _ArtworkAssetGroup(
    title: '感情',
    items: [
      _ArtworkAssetItem(label: '上がる', assetPath: 'assets/emotion/agaru.png'),
      _ArtworkAssetItem(label: 'チル', assetPath: 'assets/emotion/chill.png'),
      _ArtworkAssetItem(label: 'エモい', assetPath: 'assets/emotion/emoi.png'),
      _ArtworkAssetItem(label: '癒し', assetPath: 'assets/emotion/iyashi.png'),
      _ArtworkAssetItem(label: '孤独', assetPath: 'assets/emotion/kodoku.png'),
      _ArtworkAssetItem(label: '前向き', assetPath: 'assets/emotion/maemuki.png'),
      _ArtworkAssetItem(label: '考える', assetPath: 'assets/emotion/think.png'),
      _ArtworkAssetItem(label: 'ときめき', assetPath: 'assets/emotion/tokimeki.png'),
    ],
  ),
  _ArtworkAssetGroup(
    title: 'ジャンル',
    items: [
      _ArtworkAssetItem(label: 'HipHop', assetPath: 'assets/genre/hiphop.png'),
      _ArtworkAssetItem(label: '邦ロック', assetPath: 'assets/genre/hou-rock.png'),
      _ArtworkAssetItem(label: '邦楽', assetPath: 'assets/genre/hougaku.png'),
      _ArtworkAssetItem(label: 'J-POP', assetPath: 'assets/genre/j-pop.png'),
      _ArtworkAssetItem(label: 'Jazz', assetPath: 'assets/genre/jaz.png'),
      _ArtworkAssetItem(label: 'K-POP', assetPath: 'assets/genre/k-pop.png'),
      _ArtworkAssetItem(label: '洋ポップ', assetPath: 'assets/genre/you-pop.png'),
      _ArtworkAssetItem(label: '洋ロック', assetPath: 'assets/genre/you-rock.png'),
      _ArtworkAssetItem(label: '洋楽', assetPath: 'assets/genre/yougaku.png'),
    ],
  ),
];

class _SelectedSongPreview extends StatelessWidget {
  const _SelectedSongPreview({
    required this.title,
    required this.artist,
    required this.album,
    required this.artworkUrl,
    required this.artworkAsset,
  });

  final String title;
  final String artist;
  final String album;
  final String artworkUrl;
  final String artworkAsset;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Container(
              width: 72,
              height: 72,
              color: Colors.white.withOpacity(0.08),
              child: artworkUrl.isNotEmpty
                  ? Image.network(
                      artworkUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white.withOpacity(0.45),
                          size: 30,
                        );
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white.withOpacity(0.55),
                            ),
                          ),
                        );
                      },
                    )
                  : artworkAsset.isNotEmpty
                      ? Image.asset(
                          artworkAsset,
                          fit: BoxFit.cover,
                        )
                      : Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 48,
                              height: 48,
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
                              color: Colors.white.withOpacity(0.55),
                              size: 28,
                            ),
                          ],
                        ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.isEmpty ? 'まだ曲は選ばれていません' : title,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.72),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  artist.isEmpty
                      ? '曲名とアーティストを入力します。'
                      : album.isEmpty
                          ? artworkUrl.isEmpty && artworkAsset.isEmpty
                              ? '$artist ・ 画像未設定'
                              : artist
                          : '$artist ・ $album',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.45),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteInputBox extends StatelessWidget {
  const _NoteInputBox({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: 4,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 15,
        height: 1.5,
      ),
      decoration: InputDecoration(
        counterStyle: TextStyle(
          color: Colors.white.withOpacity(0.35),
        ),
        hintText: '例：夜の帰り道にずっと流してた。',
        hintStyle: TextStyle(
          color: Colors.white.withOpacity(0.35),
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        contentPadding: const EdgeInsets.all(18),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(
            color: Colors.white.withOpacity(0.10),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(
            color: Colors.white.withOpacity(0.28),
          ),
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.10),
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
              color: Colors.white.withOpacity(0.12),
            ),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 22,
          ),
        ),
      ),
    );
  }
}