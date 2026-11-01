import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_constants.dart';
import '../core/constants/categories.dart';
import '../core/theme/app_theme.dart';
import '../models/auth_user.dart';
import '../models/user_preferences.dart';
import '../repositories/article_repository.dart';
import '../repositories/auth_repository.dart';
import '../services/notification_service.dart';
import '../services/offline_cache_service.dart';
import 'auth_screen.dart';
import 'legal_screen.dart';
import 'reading_history_screen.dart';
import 'weekly_recap_screen.dart';

class ProfileScreen extends StatefulWidget {
  final AuthRepository authRepository;
  final ValueNotifier<ThemeMode> themeModeNotifier;
  final OfflineCacheService? cacheService;
  final INotificationService? notificationService;
  final FirebaseFirestore? firestore;
  final ArticleRepository? articleRepository;

  const ProfileScreen({
    super.key,
    required this.authRepository,
    required this.themeModeNotifier,
    this.cacheService,
    this.notificationService,
    this.firestore,
    this.articleRepository,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const String _pushKey = 'techdaily_push_enabled_v1';

  late final OfflineCacheService _cacheService;
  late final INotificationService _notificationService;
  FirebaseFirestore? _firestore;
  UserPreferences _preferences = UserPreferences.defaultPreferences();
  bool _pushEnabled = false;
  bool _pushBusy = false;

  @override
  void initState() {
    super.initState();
    _cacheService = widget.cacheService ?? OfflineCacheService();
    _firestore = widget.firestore;
    if (_firestore == null) {
      try {
        if (Firebase.apps.isNotEmpty) _firestore = FirebaseFirestore.instance;
      } catch (_) {}
    }
    _notificationService =
        widget.notificationService ?? TechDailyNotificationService(firestore: _firestore);
    _load();
  }

  Future<void> _load() async {
    final cached = await _cacheService.getCachedPreferences();
    bool push = false;
    try {
      push = (await SharedPreferences.getInstance()).getBool(_pushKey) ?? false;
    } catch (_) {}
    if (mounted) {
      setState(() {
        _preferences = cached;
        _pushEnabled = push;
      });
    }
    final user = widget.authRepository.currentUser;
    if (user != null && _firestore != null) {
      try {
        final doc = await _firestore!.collection('users').doc(user.uid).get();
        final raw = doc.data()?['preferences'];
        if (raw is Map) {
          final cloud = UserPreferences.fromMap(Map<String, dynamic>.from(raw));
          await _cacheService.cachePreferences(cloud);
          if (mounted) setState(() => _preferences = cloud);
        }
      } catch (_) {}
    }
  }

  Future<void> _savePreferences(UserPreferences prefs) async {
    setState(() => _preferences = prefs);
    await _cacheService.cachePreferences(prefs);
    await _notificationService.updateSubscriptions(prefs);
    final user = widget.authRepository.currentUser;
    if (user != null && _firestore != null) {
      try {
        await _firestore!.collection('users').doc(user.uid).set({
          'preferences': prefs.toMap(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {}
    }
  }

  Future<void> _togglePush(bool value) async {
    setState(() => _pushBusy = true);
    final uid = widget.authRepository.currentUser?.uid;
    String message;
    bool enabled;
    if (value) {
      final result = await _notificationService.enablePush(userId: uid);
      enabled = result.isEnabled;
      message = result.message;
    } else {
      await _notificationService.disablePush(userId: uid);
      enabled = false;
      message = 'Notifications are off.';
    }
    try {
      await (await SharedPreferences.getInstance()).setBool(_pushKey, enabled);
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _pushEnabled = enabled;
      _pushBusy = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _toggleCategory(String name) {
    final list = List<String>.from(_preferences.selectedCategories);
    list.contains(name) ? list.remove(name) : list.add(name);
    _savePreferences(_preferences.copyWith(selectedCategories: list));
  }

  void _openAuth({bool signUp = false}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AuthScreen(authRepository: widget.authRepository, initialIsSignUp: signUp),
    ));
  }

  Future<void> _signOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('Your saved stories stay in your account.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Sign out')),
        ],
      ),
    );
    if (ok == true) {
      await widget.authRepository.signOut();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Signed out')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Profile & settings')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              StreamBuilder<AuthUser?>(
                stream: widget.authRepository.authStateChanges,
                initialData: widget.authRepository.currentUser,
                builder: (context, snap) => _buildAccountCard(theme, snap.data),
              ),
              _heading('Your topics', 'Stories from these topics rank higher in your feed.'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AppCategories.all.map((c) {
                  final selected = _preferences.selectedCategories.contains(c.name);
                  return FilterChip(
                    label: Text(c.name),
                    selected: selected,
                    showCheckmark: false,
                    avatar: Icon(c.icon, size: 16, color: selected ? theme.scaffoldBackgroundColor : null),
                    onSelected: (_) => _toggleCategory(c.name),
                  );
                }).toList(),
              ),
              _heading('Notifications', 'At most a couple of alerts a day.'),
              _group([
                SwitchListTile(
                  key: const ValueKey('push-toggle'),
                  secondary: const Icon(Icons.notifications_active_outlined),
                  title: const Text('Push notifications'),
                  subtitle: const Text('Breaking news and the daily brief'),
                  value: _pushEnabled,
                  onChanged: _pushBusy ? null : _togglePush,
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.bolt_rounded),
                  title: const Text('Breaking news'),
                  value: _preferences.breakingNewsNotifications,
                  onChanged: !_pushEnabled
                      ? null
                      : (v) => _savePreferences(_preferences.copyWith(breakingNewsNotifications: v)),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.wb_sunny_outlined),
                  title: const Text('Daily brief'),
                  value: _preferences.dailyBriefNotifications,
                  onChanged: !_pushEnabled
                      ? null
                      : (v) => _savePreferences(_preferences.copyWith(dailyBriefNotifications: v)),
                ),
              ]),
              _heading('Appearance', null),
              ValueListenableBuilder<ThemeMode>(
                valueListenable: widget.themeModeNotifier,
                builder: (context, mode, _) => SegmentedButton<ThemeMode>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: ThemeMode.system, label: Text('Auto'), icon: Icon(Icons.brightness_auto_outlined)),
                    ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode_outlined)),
                    ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode_outlined)),
                  ],
                  selected: {mode},
                  onSelectionChanged: (s) => widget.themeModeNotifier.value = s.first,
                ),
              ),
              if (widget.articleRepository != null) ...[
                _heading('Reading', null),
                _group([
                  ListTile(
                    leading: const Icon(Icons.history_rounded),
                    title: const Text('Reading history'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ReadingHistoryScreen(
                        repository: widget.articleRepository!,
                        authRepository: widget.authRepository,
                      ),
                    )),
                  ),
                  ListTile(
                    leading: const Icon(Icons.auto_stories_outlined),
                    title: const Text('Weekly recap'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => WeeklyRecapScreen(
                        repository: widget.articleRepository!,
                        authRepository: widget.authRepository,
                      ),
                    )),
                  ),
                ]),
              ],
              _heading('About', null),
              _group([
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('Terms of Use'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const LegalScreen(doc: LegalDoc.terms),
                  )),
                ),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Privacy Policy'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const LegalScreen(doc: LegalDoc.privacy),
                  )),
                ),
              ]),
              const SizedBox(height: 20),
              Center(
                child: Text(
                  '${AppConstants.appName} ${AppConstants.appVersion}',
                  style: AppTheme.numeric(12, weight: FontWeight.w500, color: AppTheme.mutedOf(context)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heading(String title, String? subtitle) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTheme.display(20, color: theme.colorScheme.onSurface)),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle, style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }

  Widget _group(List<Widget> children) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, color: AppTheme.borderOf(context)),
            children[i],
          ],
        ],
      ),
    );
  }

  Widget _buildAccountCard(ThemeData theme, AuthUser? user) {
    if (user == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.isDark(context) ? AppTheme.paper : AppTheme.ink,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Keep your stories everywhere',
                style: AppTheme.display(22, color: AppTheme.isDark(context) ? AppTheme.ink : AppTheme.paper)),
            const SizedBox(height: 6),
            Text(
              'Sign in to sync saved stories and get alerts on all your devices.',
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: (AppTheme.isDark(context) ? AppTheme.ink : AppTheme.paper).withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: FilledButton(
                  onPressed: () => _openAuth(),
                  child: const FittedBox(fit: BoxFit.scaleDown, child: Text('Sign in')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    foregroundColor: AppTheme.isDark(context) ? AppTheme.ink : AppTheme.paper,
                    side: BorderSide(
                      color: (AppTheme.isDark(context) ? AppTheme.ink : AppTheme.paper).withValues(alpha: 0.4),
                    ),
                  ),
                  onPressed: () => _openAuth(signUp: true),
                  child: const FittedBox(fit: BoxFit.scaleDown, child: Text('Create account', maxLines: 1)),
                ),
              ),
            ]),
          ],
        ),
      );
    }
    final name = (user.displayName?.trim().isNotEmpty ?? false)
        ? user.displayName!.trim()
        : user.email.split('@').first;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: AppTheme.accent,
            child: Text(
              name.isEmpty ? '?' : name[0].toUpperCase(),
              style: AppTheme.display(22, color: Colors.white),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTheme.display(18, color: theme.colorScheme.onSurface)),
                Text(user.email, style: theme.textTheme.bodySmall, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          TextButton(onPressed: _signOut, child: const Text('Sign out')),
        ]),
      ),
    );
  }
}

