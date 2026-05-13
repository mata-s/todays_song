import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TransferPage extends StatefulWidget {
  const TransferPage({super.key});

  @override
  State<TransferPage> createState() => _TransferPageState();
}

class _TransferPageState extends State<TransferPage> {
  final _codeController = TextEditingController();
  final _passcodeController = TextEditingController();

  bool _isLoading = false;
  String? _generatedCode;
  String? _generatedPasscode;

  @override
  void dispose() {
    _codeController.dispose();
    _passcodeController.dispose();
    super.dispose();
  }

  String _hashPasscode(String passcode) {
    return sha256.convert(utf8.encode(passcode)).toString();
  }

  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    final first = List.generate(4, (_) => chars[random.nextInt(chars.length)]).join();
    final second = List.generate(4, (_) => chars[random.nextInt(chars.length)]).join();
    return '$first-$second';
  }

  String _generatePasscode() {
    final random = Random.secure();
    return List.generate(6, (_) => random.nextInt(10)).join();
  }

  Future<void> _generateTransferCode() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final code = _generateCode();
      final passcode = _generatePasscode();

      await FirebaseFirestore.instance.collection('transfer_codes').doc(code).set({
        'code': code,
        'passcodeHash': _hashPasscode(passcode),
        'oldUid': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'usedAt': null,
      });

      if (!mounted) return;

      setState(() {
        _generatedCode = code;
        _generatedPasscode = passcode;
      });

      _showGeneratedCodeSheet();
    } catch (_) {
      if (!mounted) return;
      _showSnack('引き継ぎコードを発行できませんでした');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _applyTransferCode() async {
    final newUser = FirebaseAuth.instance.currentUser;
    if (newUser == null) return;

    final code = _codeController.text.trim().toUpperCase();
    final passcode = _passcodeController.text.trim();

    if (code.isEmpty || passcode.isEmpty) {
      _showSnack('コードとパスコードを入力してください');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final firestore = FirebaseFirestore.instance;
      final codeRef = firestore.collection('transfer_codes').doc(code);
      final codeDoc = await codeRef.get();

      if (!codeDoc.exists) {
        _showSnack('引き継ぎコードが見つかりません');
        return;
      }

      final data = codeDoc.data() ?? {};
      final oldUid = data['oldUid'] as String? ?? '';
      final passcodeHash = data['passcodeHash'] as String? ?? '';
      final usedAt = data['usedAt'];

      if (oldUid.isEmpty) {
        _showSnack('引き継ぎコードが正しくありません');
        return;
      }

      if (oldUid == newUser.uid) {
        _showSnack('同じ端末では引き継ぎできません');
        return;
      }

      if (usedAt != null) {
        _showSnack('このコードはすでに使用されています');
        return;
      }


      if (_hashPasscode(passcode) != passcodeHash) {
        _showSnack('パスコードが違います');
        return;
      }

      await _moveUserData(oldUid: oldUid, newUid: newUser.uid);
      await codeRef.update({
        'usedAt': FieldValue.serverTimestamp(),
        'newUid': newUser.uid,
      });

      if (!mounted) return;

      _codeController.clear();
      _passcodeController.clear();
      _showSnack('データを引き継ぎました');
    } catch (_) {
      if (!mounted) return;
      _showSnack('引き継ぎに失敗しました');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _moveUserData({
    required String oldUid,
    required String newUid,
  }) async {
    final firestore = FirebaseFirestore.instance;

    final oldUserRef = firestore.collection('users').doc(oldUid);
    final newUserRef = firestore.collection('users').doc(newUid);
    final oldUserDoc = await oldUserRef.get();

    if (oldUserDoc.exists) {
      await newUserRef.set({
        ...oldUserDoc.data()!,
        'transferredFrom': oldUid,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    await _updateUserIdInCollection(
      collectionName: 'daily_songs',
      fieldName: 'userId',
      oldUid: oldUid,
      newUid: newUid,
    );

    await _updateUserIdInCollection(
      collectionName: 'listen_later',
      fieldName: 'userId',
      oldUid: oldUid,
      newUid: newUid,
    );

    await _updateUserIdInCollection(
      collectionName: 'listen_later',
      fieldName: 'ownerId',
      oldUid: oldUid,
      newUid: newUid,
    );

    await _updateUserIdInCollection(
      collectionName: 'song_views',
      fieldName: 'userId',
      oldUid: oldUid,
      newUid: newUid,
    );
  }

  Future<void> _updateUserIdInCollection({
    required String collectionName,
    required String fieldName,
    required String oldUid,
    required String newUid,
  }) async {
    final firestore = FirebaseFirestore.instance;
    final snapshot = await firestore
        .collection(collectionName)
        .where(fieldName, isEqualTo: oldUid)
        .get();

    if (snapshot.docs.isEmpty) return;

    WriteBatch batch = firestore.batch();
    var count = 0;

    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {
        fieldName: newUid,
        'updatedAt': FieldValue.serverTimestamp(),
      });
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

  void _showGeneratedCodeSheet() {
    final code = _generatedCode;
    final passcode = _generatedPasscode;
    if (code == null || passcode == null) return;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF243247),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
final screenHeight = MediaQuery.of(context).size.height;

return SafeArea(
  child: ConstrainedBox(
    constraints: BoxConstraints(
      maxHeight: screenHeight * 0.86,
    ),
    child: SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
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
                const SizedBox(height: 24),
                const Text(
                  '引き継ぎコードを発行しました',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  '新しい端末で、下のコードとパスコードを入力してください。',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.68),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                _CodeBox(label: '引き継ぎコード', value: code),
                const SizedBox(height: 12),
                _CodeBox(label: 'パスコード', value: passcode),
                const SizedBox(height: 18),
                Text(
                  'このコードは一度使うと無効になります。他の人には見せないでください。',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.48),
                    fontSize: 12,
                    height: 1.45,
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
          'データ引き継ぎ',
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
                  color: Colors.white.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.10),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '機種変更しても、今日の一曲を引き継げます。',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '今の端末でコードを発行し、新しい端末で入力してください。コードは一度使うと無効になります。',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.66),
                        fontSize: 14,
                        height: 1.55,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _TransferActionTile(
                icon: Icons.qr_code_2_rounded,
                title: '引き継ぎコードを発行',
                subtitle: 'この端末のデータを新しい端末へ移す準備をします',
                onTap: _isLoading ? null : _generateTransferCode,
              ),
              const SizedBox(height: 12),
              _TransferActionTile(
                icon: Icons.login_rounded,
                title: '引き継ぎコードを入力',
                subtitle: '前の端末で発行したコードを入力します',
                onTap: _isLoading ? null : _showInputDialog,
              ),
              const SizedBox(height: 22),
              Text(
                '※ 引き継ぎ後は、この端末の匿名アカウントにデータが移ります。コードは他の人に見せないでください。',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.48),
                  fontSize: 12,
                  height: 1.55,
                ),
              ),
            ],
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.22),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showInputDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF243247),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            '引き継ぎコードを入力',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _TransferTextField(
                controller: _codeController,
                label: '引き継ぎコード',
                hintText: 'ABCD-1234',
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 14),
              _TransferTextField(
                controller: _passcodeController,
                label: 'パスコード',
                hintText: '6桁の数字',
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'キャンセル',
                style: TextStyle(color: Colors.white.withOpacity(0.65)),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _applyTransferCode();
              },
              child: const Text(
                '引き継ぐ',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TransferActionTile extends StatelessWidget {
  const _TransferActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.06),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.09),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color: Colors.white.withOpacity(0.9),
                  size: 23,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.56),
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withOpacity(0.34),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CodeBox extends StatelessWidget {
  const _CodeBox({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.09),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.58),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Material(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(999),
                child: InkWell(
                  onTap: () async {
                    await Clipboard.setData(
                      ClipboardData(text: value),
                    );

                    if (!context.mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$label をコピーしました'),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(999),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.copy_rounded,
                          size: 15,
                          color: Colors.white.withOpacity(0.82),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'コピー',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.82),
                            fontSize: 11,
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
          const SizedBox(height: 10),
          SelectableText(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _TransferTextField extends StatelessWidget {
  const _TransferTextField({
    required this.controller,
    required this.label,
    required this.hintText,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.28)),
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.58)),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white.withOpacity(0.24)),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white),
        ),
      ),
    );
  }
}