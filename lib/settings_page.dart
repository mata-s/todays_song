import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'transfer_page.dart';
import 'account_delete_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF1B2740),
                Color(0xFF182338),
              ],
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
        centerTitle: true,
        title: const Text(
          '設定',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF182338),
              Color(0xFF141B2D),
            ],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
          children: [
          _SettingsTile(
            icon: Icons.sync_rounded,
            title: 'データ引き継ぎ',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const TransferPage(),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _SettingsTile(
            icon: Icons.mail_outline_rounded,
            title: 'お問い合わせ',
            onTap: () async {
              final uri = Uri.parse(
                'https://one-song-nine.vercel.app/contact.html',
              );
              await launchUrl(
                uri,
                mode: LaunchMode.externalApplication,
              );
            },
          ),
          const SizedBox(height: 12),
          _SettingsTile(
            icon: Icons.description_outlined,
            title: '利用規約',
            onTap: () async {
              final uri = Uri.parse(
                'https://one-song-nine.vercel.app/terms.html',
              );
              await launchUrl(
                uri,
                mode: LaunchMode.externalApplication,
              );
            },
          ),
          const SizedBox(height: 12),
          _SettingsTile(
            icon: Icons.privacy_tip_outlined,
            title: 'プライバシーポリシー',
            onTap: () async {
              final uri = Uri.parse(
                'https://one-song-nine.vercel.app/privacy.html',
              );
              await launchUrl(
                uri,
                mode: LaunchMode.externalApplication,
              );
            },
          ),
          const SizedBox(height: 12),
          _SettingsTile(
            icon: Icons.delete_forever_rounded,
            title: 'アカウントを削除',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AccountDeletePage(),
                ),
              );
            },
          ),
        ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    this.onTap,
  });

  final IconData icon;
  final String title;
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
          padding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 18,
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: Colors.white.withOpacity(0.88),
                  size: 21,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
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