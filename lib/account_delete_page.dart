import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AccountDeletePage extends StatefulWidget {
  const AccountDeletePage({super.key});

  @override
  State<AccountDeletePage> createState() => _AccountDeletePageState();
}

class _AccountDeletePageState extends State<AccountDeletePage> {
  bool _isDeleting = false;

  Future<_DeleteCounts> _loadDeleteCounts() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const _DeleteCounts(
        posts: 0,
        listenLater: 0,
      );
    }

    final uid = user.uid;
    final firestore = FirebaseFirestore.instance;

    final results = await Future.wait([
      firestore
          .collection('daily_songs')
          .where('userId', isEqualTo: uid)
          .count()
          .get(),
      firestore
          .collection('listen_later')
          .where('userId', isEqualTo: uid)
          .count()
          .get(),
    ]);

    return _DeleteCounts(
      posts: results[0].count ?? 0,
      listenLater: results[1].count ?? 0,
    );
  }

  Future<void> _deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnack('ユーザー情報が見つかりません');
      return;
    }

    setState(() => _isDeleting = true);

    try {
      final uid = user.uid;
      final firestore = FirebaseFirestore.instance;

      await _deleteDocsByField(
        collectionName: 'daily_songs',
        fieldName: 'userId',
        uid: uid,
      );
      await _deleteDocsByField(
        collectionName: 'listen_later',
        fieldName: 'userId',
        uid: uid,
      );
      await _deleteDocsByField(
        collectionName: 'song_views',
        fieldName: 'userId',
        uid: uid,
      );
      await _deleteDocsByField(
        collectionName: 'transfer_codes',
        fieldName: 'oldUid',
        uid: uid,
      );

      await firestore.collection('users').doc(uid).delete();
      await user.delete();

      if (!mounted) return;

      Navigator.of(context).popUntil((route) => route.isFirst);
      _showSnack('アカウントを削除しました');
    } catch (_) {
      if (!mounted) return;
      _showSnack('アカウントを削除できませんでした');
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  Future<void> _deleteDocsByField({
    required String collectionName,
    required String fieldName,
    required String uid,
  }) async {
    final firestore = FirebaseFirestore.instance;
    final snapshot = await firestore
        .collection(collectionName)
        .where(fieldName, isEqualTo: uid)
        .get();

    if (snapshot.docs.isEmpty) return;

    WriteBatch batch = firestore.batch();
    var count = 0;

    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
      count++;

      if (count >= 450) {
        await batch.commit();
        batch = firestore.batch();
        count = 0;
      }
    }

    if (count > 0) {
      await batch.commit();
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1C2740),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            '本当に削除しますか？',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            '投稿、後で聴く、プロフィールなどのデータが削除されます。この操作は取り消せません。',
            style: TextStyle(
              color: Colors.white.withOpacity(0.74),
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                'キャンセル',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.72),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text(
                '削除する',
                style: TextStyle(
                  color: Color(0xFFFF8FA3),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _deleteAccount();
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141B2D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        title: const Text(
          'アカウントを削除',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 32),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF8FA3).withOpacity(0.09),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: const Color(0xFFFF8FA3).withOpacity(0.16),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '削除すると元に戻せません',
                      style: TextStyle(
                        color: Color(0xFFFFB3C1),
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '投稿、アーカイブ、後で聴く、プロフィールなど、このアカウントに紐づくデータを削除します。',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.70),
                        fontSize: 14,
                        height: 1.55,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              FutureBuilder<_DeleteCounts>(
                future: _loadDeleteCounts(),
                builder: (context, snapshot) {
                  final counts = snapshot.data;

                  return Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.08),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '削除されるデータ',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (snapshot.connectionState == ConnectionState.waiting)
                          Text(
                            '件数を確認しています…',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.62),
                              fontSize: 13,
                            ),
                          )
                        else ...[
                          _DeleteCountRow(
                            label: '投稿・アーカイブ',
                            count: counts?.posts ?? 0,
                          ),
                          const SizedBox(height: 10),
                          _DeleteCountRow(
                            label: '後で聴く',
                            count: counts?.listenLater ?? 0,
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.08),
                  ),
                ),
                child: Text(
                  '削除する前に、必要であれば「データ引き継ぎ」でコードを発行してください。',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.62),
                    fontSize: 13,
                    height: 1.55,
                  ),
                ),
              ),
              const SizedBox(height: 26),
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: _isDeleting ? null : _confirmDelete,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF8FA3),
                    foregroundColor: const Color(0xFF20121A),
                    disabledBackgroundColor:
                        const Color(0xFFFF8FA3).withOpacity(0.34),
                    disabledForegroundColor:
                        const Color(0xFF20121A).withOpacity(0.42),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'アカウントを削除する',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_isDeleting)
            Container(
              color: Colors.black.withOpacity(0.24),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

class _DeleteCounts {
  const _DeleteCounts({
    required this.posts,
    required this.listenLater,
  });

  final int posts;
  final int listenLater;
}

class _DeleteCountRow extends StatelessWidget {
  const _DeleteCountRow({
    required this.label,
    required this.count,
  });

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.68),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          '$count件',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}