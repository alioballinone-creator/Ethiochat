import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/config/env.dart';
import '../../../../core/design/design.dart';
import '../../../../core/errors/failure.dart';
import '../../../profile/application/profile_controller.dart';
import '../../application/auth_providers.dart';

/// Profile setup — shown once after OTP verification, and from Settings.
///
/// Avatar, display name and an optional bio. Everything scrolls, the primary
/// action stays above the keyboard via [SafeArea] + [ListView].
class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key, this.isEditing = false});

  final bool isEditing;

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _name = TextEditingController();
  final _bio = TextEditingController();
  String? _avatarPath;
  bool _loaded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(userProfileProvider);
    if (profile.isComplete) {
      _loaded = true;
      _name.text = profile.name;
      _bio.text = profile.bio;
      _avatarPath = profile.avatarPath;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    super.dispose();
  }

  bool get _valid => _name.text.trim().length >= 2;

  Future<void> _pickPhoto() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1200,
      );
      if (picked == null || !mounted) return;
      setState(() => _avatarPath = picked.path);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            mapError(error).messageFor(
              Localizations.localeOf(context).languageCode,
            ),
          ),
        ),
      );
    }
  }

  Future<void> _save() async {
    if (!_valid || _saving) return;
    setState(() => _saving = true);
    final name = _name.text.trim();
    final bio = _bio.text.trim();
    final current = ref.read(userProfileProvider);

    await ref.read(userProfileProvider.notifier).save(
          name: name,
          bio: bio,
          avatarPath: _avatarPath,
          clearAvatarPath: _avatarPath == null,
        );

    // A production profile is only reported as saved after the authenticated
    // backend accepts it. The local-only path exists for credential-free
    // development builds only; release builds are blocked at startup when
    // Supabase is missing.
    if (Env.hasSupabase) {
      final result = await ref.read(authRepositoryProvider).completeProfile(
            displayName: name,
            bio: bio,
            phone: current.phone,
            avatarPath: _avatarPath,
          );
      if (!mounted) return;
      final failure = result.failureOrNull;
      if (failure != null) {
        await ref.read(userProfileProvider.notifier).save(
              name: current.name,
              bio: current.bio,
              phone: current.phone,
              avatarPath: current.avatarPath,
              clearAvatarPath: current.avatarPath == null,
            );
        setState(() => _saving = false);
        if (!mounted) return;
        final locale = Localizations.localeOf(context).languageCode;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              failure.messageFor(locale),
            ),
          ),
        );
        return;
      }
    }

    final remote = Env.hasSupabase
        ? (await ref.read(authRepositoryProvider).fetchProfile()).valueOrNull
        : null;
    if (remote != null) {
      await ref.read(userProfileProvider.notifier).save(
            name: remote.displayName,
            bio: remote.bio,
            avatarPath: remote.avatarUrl,
            clearAvatarPath: remote.avatarUrl == null,
          );
    }
    if (!mounted) return;
    setState(() => _saving = false);
    if (widget.isEditing) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated.')),
      );
      context.pop();
      return;
    }
    context.go('/chats');
  }

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);
    final text = Theme.of(context).textTheme;

    ref.listen<UserProfile>(userProfileProvider, (previous, next) {
      if (_loaded || !next.isComplete || _name.text.isNotEmpty) return;
      setState(() {
        _loaded = true;
        _name.text = next.name;
        _bio.text = next.bio;
        _avatarPath = next.avatarPath;
      });
    });

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text(
          widget.isEditing ? 'Edit profile' : 'Your profile',
          style: text.headlineMedium,
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: Sp.screen.copyWith(top: Sp.x4, bottom: Sp.x6),
          children: [
            Center(
              child: GestureDetector(
                onTap: _pickPhoto,
                child: Stack(
                  children: [
                    EthioAvatar(
                      name: _name.text.trim().isEmpty
                          ? 'New user'
                          : _name.text.trim(),
                      imageUrl: _avatarPath,
                      size: 104,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: EthioColors.goldGradient,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            width: 3,
                          ),
                        ),
                        child: const Icon(
                          Icons.camera_alt_outlined,
                          size: 18,
                          color: EthioColors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Sp.x3),
            Center(
              child: TextButton(
                onPressed: _pickPhoto,
                child: Text(
                  _avatarPath == null ? 'Add a photo' : 'Change photo',
                ),
              ),
            ),
            const SizedBox(height: Sp.x4),
            Text('Display name', style: text.titleMedium),
            const SizedBox(height: Sp.x2),
            EthioTextField(
              controller: _name,
              hint: 'e.g. Abebe Kebede',
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: Sp.x4),
            Text('About', style: text.titleMedium),
            const SizedBox(height: Sp.x2),
            EthioTextField(
              controller: _bio,
              hint: 'A short line about you',
              maxLength: 160,
            ),
            const SizedBox(height: Sp.x4),
            Container(
              padding: const EdgeInsets.all(Sp.x4),
              decoration: BoxDecoration(
                color: pal.chip,
                borderRadius: Rad.r14,
                border: Border.all(color: pal.line),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lock_outline_rounded, size: 18),
                  const SizedBox(width: Sp.x2),
                  Expanded(
                    child: Text(
                      'Your name and photo are visible to people you chat '
                      'with. You can change them later in Settings.',
                      style: text.bodySmall?.copyWith(color: pal.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Sp.x6),
            EthioButton(
              label: _saving
                  ? 'Saving…'
                  : widget.isEditing
                      ? 'Save changes'
                      : 'Continue',
              onPressed: _valid && !_saving ? _save : null,
            ),
          ],
        ),
      ),
    );
  }
}
