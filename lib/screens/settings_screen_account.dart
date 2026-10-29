import 'dart:typed_data';
import 'dart:convert';
import '../services/local_account_store.dart';
import '../widgets/account_data_scope.dart';

import '../services/profile_photo_picker.dart';
import '../widgets/confirmation_dialog.dart';
import '../widgets/profile_scope.dart';
import 'package:flutter/material.dart';
import '../services/auth_api.dart';
import '../services/local_auth_api.dart';
import 'main_screen.dart';
import 'registration_screen.dart';
import '../theme/app_theme.dart';

abstract final class _AccountLayout {
  static const avatarSize = 72.0;
  static const cameraSize = 28.0;
  static const fieldHeight = 48.0;
  static const fieldRadius = 12.0;
  static const fieldGap = 12.0;
  static const pagePadding = 24.0;
}

class SettingsScreenAccount extends StatefulWidget {
  const SettingsScreenAccount({super.key, this.authApi});

  final AuthApi? authApi;

  @override
  State<SettingsScreenAccount> createState() => _SettingsScreenAccountState();
}

class _SettingsScreenAccountState extends State<SettingsScreenAccount> {
  final _focusedFields = <String>{};
  Uint8List? _avatarPhoto;
  bool _changingPhoto = false;
  bool _photoMenuOpen = false;
  bool _loggingOut = false;
  LocalAccountStore? _data;
  bool _initializedProfile = false;
  bool _savingProfile = false;
  final _values = <String, String>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _data = AccountDataScope.maybeOf(context);
    if (_data?.loaded == true && !_initializedProfile) {
      _initializedProfile = true;
      final profile = _data!.profile;
      final names = profile.name.trim().split(RegExp(r'\s+'));
      _values.addAll({
        'Name': names.first,
        'Surname': names.skip(1).join(' '),
        'Phone number': profile.phone,
        'Nickname': _data!.details['nickname'] as String? ?? '',
        'About me': _data!.details['about'] as String? ?? '',
        'Date of birth': _data!.details['birthday'] as String? ?? '',
      });
      _avatarPhoto = _data!.photo;
    }
  }

  Future<void> _saveProfile() async {
    if (_savingProfile || _data == null) return;
    final name = (_values['Name'] ?? '').trim();
    final phone = (_values['Phone number'] ?? '').trim();
    if (name.isEmpty ||
        !RegExp(
          r'^\+[1-9][0-9]{6,14}$',
        ).hasMatch(phone.replaceAll(RegExp(r'[ ()-]'), ''))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter your name and a valid phone number.'),
        ),
      );
      return;
    }
    setState(() => _savingProfile = true);
    try {
      await _data!.saveProfile({
        'name': [
          name,
          _values['Surname'] ?? '',
        ].where((p) => p.trim().isNotEmpty).join(' '),
        'phone': phone,
        'nickname': _values['Nickname'] ?? '',
        'about': _values['About me'] ?? '',
        'birthday': _values['Date of birth'] ?? '',
        'photo': _avatarPhoto == null ? null : base64Encode(_avatarPhoto!),
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile saved.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save profile.')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _logOut() async {
    if (_loggingOut) return;
    FocusScope.of(context).unfocus();
    setState(() => _loggingOut = true);
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Log out?',
      message:
          'You can sign in again with your email, password and verification code.',
      confirmLabel: 'Log out',
    );
    if (!mounted) return;
    if (confirmed != true) {
      setState(() => _loggingOut = false);
      return;
    }
    AuthProfile? remainingProfile;
    try {
      await (widget.authApi ?? AuthApi.instance).logout();
      if (widget.authApi case final LocalAuthApi local) {
        remainingProfile = await local.restoreSession();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loggingOut = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not log out. Please try again.')),
      );
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => remainingProfile == null
            ? RegistrationScreen(authApi: widget.authApi)
            : MainScreen(profile: remainingProfile, authApi: widget.authApi),
      ),
      (_) => false,
    );
  }

  Future<void> _changePhoto() async {
    if (_changingPhoto || _photoMenuOpen) return;
    FocusScope.of(context).unfocus();
    _photoMenuOpen = true;

    try {
      final choosePhoto = await showModalBottomSheet<bool>(
        context: context,
        showDragHandle: true,
        useSafeArea: true,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (sheetContext) {
          final colors = AppTheme.colorsOf(sheetContext);
          return SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Change profile photo',
                    style: Theme.of(sheetContext).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    leading: const CircleAvatar(
                      backgroundColor: AppTheme.photoAttachment,
                      foregroundColor: AppTheme.attachmentForeground,
                      child: Icon(Icons.photo_library_outlined),
                    ),
                    title: const Text('Photo'),
                    subtitle: Text(
                      'Choose a profile photo',
                      style: TextStyle(color: colors.secondaryText),
                    ),
                    onTap: () => Navigator.pop(sheetContext, true),
                  ),
                ],
              ),
            ),
          );
        },
      );
      if (!mounted || choosePhoto != true) return;

      setState(() => _changingPhoto = true);
      final bytes = await pickProfilePhoto();
      if (!mounted || bytes == null) return;
      setState(() => _avatarPhoto = bytes);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open photo. Please try again.'),
          ),
        );
      }
    } finally {
      _photoMenuOpen = false;
      if (mounted) setState(() => _changingPhoto = false);
    }
  }

  Widget _avatar(ColorScheme colors) => Center(
    child: SizedBox(
      width: _AccountLayout.avatarSize + 16,
      height: _AccountLayout.avatarSize + 16,
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: CircleAvatar(
                radius: _AccountLayout.avatarSize / 2,
                backgroundColor: colors.primaryContainer,
                foregroundImage: _avatarPhoto == null
                    ? null
                    : MemoryImage(_avatarPhoto!),
                child: _avatarPhoto == null
                    ? Icon(
                        Icons.person_outline_rounded,
                        size: 40,
                        color: colors.onPrimaryContainer,
                      )
                    : null,
              ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: IconButton.filled(
              tooltip: 'Change profile photo',
              style: IconButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.onPrimary,
                disabledBackgroundColor: colors.primary,
                disabledForegroundColor: colors.onPrimary,
                minimumSize: const Size(
                  _AccountLayout.cameraSize,
                  _AccountLayout.cameraSize,
                ),
                fixedSize: const Size(
                  _AccountLayout.cameraSize,
                  _AccountLayout.cameraSize,
                ),
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.padded,
                shape: CircleBorder(
                  side: BorderSide(color: colors.surface, width: 2),
                ),
              ),
              onPressed: _changingPhoto ? null : _changePhoto,
              icon: _changingPhoto
                  ? SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.onPrimary,
                      ),
                    )
                  : const Icon(Icons.camera_alt_outlined, size: 16),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _section(String title, ColorScheme colors) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      title,
      style: TextStyle(
        color: colors.primary,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
    ),
  );

  OutlineInputBorder _fieldBorder(BorderSide side) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(_AccountLayout.fieldRadius),
    borderSide: side,
  );

  Widget _field(
    ColorScheme colors,
    String label,
    String value,
    IconData icon, {
    TextInputType? keyboardType,
    TextCapitalization capitalization = TextCapitalization.none,
    Iterable<String>? autofillHints,
    String? initialValue,
    String? helperText,
    int maxLines = 1,
    bool last = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: _AccountLayout.fieldGap),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Focus(
          onFocusChange: (focused) => setState(() {
            if (focused) {
              _focusedFields.add(label);
            } else {
              _focusedFields.remove(label);
            }
          }),
          child: SizedBox(
            height: _AccountLayout.fieldHeight,
            child: TextFormField(
              initialValue: _values[label] ?? initialValue,
              onChanged: (text) => _values[label] = text,
              keyboardType:
                  keyboardType ??
                  (maxLines > 1 ? TextInputType.multiline : TextInputType.text),
              textCapitalization: capitalization,
              autofillHints: autofillHints,
              minLines: 1,
              maxLines: maxLines,
              style: const TextStyle(fontSize: 14),
              textInputAction: last
                  ? TextInputAction.done
                  : (maxLines > 1
                        ? TextInputAction.newline
                        : TextInputAction.next),
              decoration: InputDecoration(
                labelText: label,
                floatingLabelBehavior: FloatingLabelBehavior.always,
                hintText: _focusedFields.contains(label) ? null : value,
                prefixIcon: Icon(
                  icon,
                  size: 20,
                  color: colors.onSurfaceVariant,
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 44,
                  minHeight: _AccountLayout.fieldHeight,
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                fillColor: colors.surfaceContainerLow,
                border: _fieldBorder(BorderSide.none),
                enabledBorder: _fieldBorder(
                  BorderSide(color: colors.inputOutline),
                ),
                focusedBorder: _fieldBorder(
                  BorderSide(color: colors.primary, width: 2),
                ),
              ),
            ),
          ),
        ),
        if (helperText != null)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 4),
            child: Text(
              helperText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.secondaryText,
                fontSize: 11,
                height: 1.2,
              ),
            ),
          ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    final profile = ProfileScope.of(context);
    final names = profile.name.trim().split(RegExp(r'\s+'));
    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(
          _AccountLayout.pagePadding,
          24,
          _AccountLayout.pagePadding,
          32,
        ),
        children: [
          _avatar(colors),
          const SizedBox(height: 12),
          Text(
            'Your profile',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            'Personal details and contact information',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 28),
          _section('Personal information', colors),
          _field(
            colors,
            'Name',
            'Name',
            Icons.person_outline,
            capitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.givenName],
            initialValue: names.first,
          ),
          _field(
            colors,
            'Surname',
            'Surname',
            Icons.badge_outlined,
            capitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.familyName],
            initialValue: names.skip(1).join(' '),
          ),
          _field(
            colors,
            'Nickname',
            'Nickname',
            Icons.alternate_email_rounded,
            keyboardType: TextInputType.text,
            helperText: 'The name others can use to find you',
          ),
          _field(
            colors,
            'About me',
            'About me',
            Icons.info_outline,
            maxLines: 3,
            capitalization: TextCapitalization.sentences,
            helperText: 'A few words about yourself',
          ),
          _field(
            colors,
            'Date of birth',
            '01/01/2000',
            Icons.cake_outlined,
            keyboardType: TextInputType.datetime,
            helperText: 'DD/MM/YYYY',
          ),
          const SizedBox(height: 8),
          Divider(height: 24, thickness: 0.5, color: colors.outlineVariant),
          _section('Contact details', colors),
          _field(
            colors,
            'Phone number',
            '+380123456789',
            Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            autofillHints: const [AutofillHints.telephoneNumber],
            initialValue: profile.phone,
            helperText: 'Include your country code',
            last: true,
          ),
          const SizedBox(height: 24),
          if (_data != null) ...[
            FilledButton(
              onPressed: _savingProfile ? null : _saveProfile,
              child: Text(_savingProfile ? 'Saving…' : 'Save changes'),
            ),
            const SizedBox(height: 16),
          ],
          OutlinedButton.icon(
            onPressed: _loggingOut ? null : _logOut,
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.error,
              minimumSize: const Size.fromHeight(52),
            ),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Log out'),
          ),
        ],
      ),
    );
  }
}
