import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../main.dart';
import '../services/profile_storage.dart';
import '../services/auth_api.dart';
import '../services/cloud_sync.dart';
import '../services/academic_notifications.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.appearance, required this.onAppearanceChanged, required this.onLogout});
  final CampusAppearance appearance;
  final ValueChanged<CampusAppearance> onAppearanceChanged;
  final Future<void> Function() onLogout;
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const institutionTypes = ['Federal University', 'State University', 'Private University', 'Federal Polytechnic', 'State Polytechnic', 'Private Polytechnic'];
  late StudentProfile _profile;
  bool _saving = false;
  @override
  void initState() { super.initState(); _profile = ProfileStorage.load(); }
  Color get _accent => Theme.of(context).colorScheme.primary;
  Color get _muted => Theme.of(context).colorScheme.onSurfaceVariant;

  Future<void> _edit() async {
    final name = TextEditingController(text: _profile.name);
    final institution = TextEditingController(text: _profile.institution);
    final department = TextEditingController(text: _profile.department);
    String level = _profile.level;
    String institutionType = _profile.institutionType;
    Uint8List? photo = _profile.photo;
    final key = GlobalKey<FormState>();
    try {
      await showModalBottomSheet<void>(
        context: context, isScrollControlled: true, showDragHandle: true,
        builder: (sheetContext) => StatefulBuilder(builder: (sheetContext, update) {
          Future<void> choosePhoto() async {
            try {
              final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512, imageQuality: 75);
              if (picked == null) return;
              final bytes = await picked.readAsBytes();
              if (bytes.lengthInBytes > 1024 * 1024) {
                if (sheetContext.mounted) ScaffoldMessenger.of(sheetContext).showSnackBar(const SnackBar(content: Text('Please choose a smaller photo (under 1 MB).')));
                return;
              }
              update(() => photo = bytes);
            } catch (_) {
              if (sheetContext.mounted) ScaffoldMessenger.of(sheetContext).showSnackBar(const SnackBar(content: Text('Photo could not be selected. Please try again.')));
            }
          }
          return SafeArea(child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
            child: ConstrainedBox(constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheetContext).height * .88),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Padding(padding: const EdgeInsets.fromLTRB(20, 4, 20, 12), child: Row(children: [
                  const Expanded(child: Text('Edit academic profile', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold))),
                  IconButton(onPressed: () => Navigator.pop(sheetContext), icon: const Icon(Icons.close_rounded)),
                ])),
                Expanded(child: Form(key: key, child: ListView(padding: const EdgeInsets.symmetric(horizontal: 20), children: [
                  Center(child: CircleAvatar(radius: 38, backgroundImage: photo == null ? null : MemoryImage(photo!), child: photo == null ? const Icon(Icons.person_rounded, size: 38) : null)),
                  Center(child: Wrap(alignment: WrapAlignment.center, children: [
                    TextButton.icon(onPressed: choosePhoto, icon: const Icon(Icons.add_a_photo_outlined), label: const Text('Choose photo (optional)')),
                    if (photo != null) TextButton(onPressed: () => update(() => photo = null), child: const Text('Remove')),
                  ])),
                  const SizedBox(height: 10),
                  TextFormField(controller: name, maxLength: 60, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Preferred name (optional)')),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: institutionTypes.contains(institutionType) ? institutionType : null,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Institution type *'),
                    items: institutionTypes.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
                    onChanged: (value) => update(() => institutionType = value ?? ''),
                    validator: (value) => (value ?? '').isEmpty ? 'Select your institution type' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(controller: institution, maxLength: 100, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Institution *', hintText: 'Your university or polytechnic'), validator: (v) => (v ?? '').trim().isEmpty ? 'Institution is required' : null),
                  const SizedBox(height: 12),
                  TextFormField(controller: department, maxLength: 100, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Department *', hintText: 'e.g. Computer Science'), validator: (v) => (v ?? '').trim().isEmpty ? 'Department is required' : null),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(initialValue: ['100 Level','200 Level','300 Level','400 Level','500 Level','600 Level','ND 1','ND 2','HND 1','HND 2','Postgraduate','Other'].contains(level) ? level : null,
                    decoration: const InputDecoration(labelText: 'Study level *'),
                    items: ['100 Level','200 Level','300 Level','400 Level','500 Level','600 Level','ND 1','ND 2','HND 1','HND 2','Postgraduate','Other'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                    onChanged: (v) => update(() => level = v ?? ''), validator: (v) => (v ?? '').isEmpty ? 'Study level is required' : null),
                  const SizedBox(height: 12),
                  Text('Your profile updates across devices when connected. Your photo stays on this device.', style: TextStyle(color: Theme.of(sheetContext).colorScheme.onSurfaceVariant, fontSize: 12)),
                  const SizedBox(height: 18),
                ]))),
                Padding(padding: const EdgeInsets.fromLTRB(20, 10, 20, 16), child: SizedBox(width: double.infinity, child: FilledButton(
                  onPressed: _saving ? null : () async {
                    if (!key.currentState!.validate()) return;
                    update(() => _saving = true);
                    try {
                      final updated = StudentProfile(name: name.text.trim(), institutionType: institutionType, institution: institution.text.trim(), department: department.text.trim(), level: level, photo: photo);
                      await ProfileStorage.save(updated);
                      try { await AuthApi.saveProfile({'preferred_name':updated.name, 'institution_type':updated.institutionType, 'institution':updated.institution, 'department':updated.department, 'level':updated.level}); await ProfileStorage.markCloudSynced(); }
                      catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved on your device. Connect to the internet and tap Data & sync to back it up.'))); }
                      if (!mounted) return;
                      setState(() => _profile = updated);
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                    } catch (_) {
                      if (sheetContext.mounted) ScaffoldMessenger.of(sheetContext).showSnackBar(const SnackBar(content: Text('Could not save profile. Please retry.')));
                    } finally { if (mounted) setState(() => _saving = false); }
                  }, child: Text(_saving ? 'Saving...' : 'Save profile'),
                ))),
              ]),
            ),
          ));
        }),
      );
    } finally { name.dispose(); institution.dispose(); department.dispose(); }
  }

  Future<void> _syncNow() async {
    try {
      await CloudSync.synchronize();
      final remote = await AuthApi.fetchProfile();
      final local = ProfileStorage.load();
      if (!local.complete && (remote['institution'] ?? '').toString().isNotEmpty) {
        final updated = StudentProfile(name:(remote['preferred_name'] ?? '').toString(), institutionType:(remote['institution_type'] ?? '').toString(), institution:(remote['institution'] ?? '').toString(), department:(remote['department'] ?? '').toString(), level:(remote['level'] ?? '').toString(), photo:local.photo);
        await ProfileStorage.save(updated);
        if (mounted) setState(() => _profile = updated);
      } else if (local.complete) {
        await AuthApi.saveProfile({'preferred_name':local.name,'institution_type':local.institutionType,'institution':local.institution,'department':local.department,'level':local.level});
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Your study data is up to date.')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not finish syncing. Your saved work is safe on this device. Please reconnect and try again.')));
    }
  }

  Future<void> _inviteFriends() async {
    try {
      final details = await AuthApi.myInvitation();
      if (!mounted) return;
      final code = (details['code'] ?? '').toString();
      final link = (details['link'] ?? '').toString();
      await showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
        title: const Text('Invite Friends 💜'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Invite classmates to CampusOS. There is no cash reward for student invitations.'),
          const SizedBox(height: 16),
          SelectableText('Your code: $code', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          SelectableText(link),
          const SizedBox(height: 8),
          Text('Friends invited: ${details['invitation_count'] ?? 0}'),
        ]),
        actions: [
          TextButton(onPressed: () async { await Clipboard.setData(ClipboardData(text: code)); }, child: const Text('Copy code')),
          TextButton(onPressed: () async { await Clipboard.setData(ClipboardData(text: link)); }, child: const Text('Copy link')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Done')),
        ],
      ));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connect to the internet to view your invitation link.')));
    }
  }

  Future<void> _changePassword() async {
    final current = TextEditingController();
    final next = TextEditingController();
    final confirmation = TextEditingController();
    try {
      if (!mounted) return;
      bool saving = false;
      String? error;
      await showDialog<void>(context: context, builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, update) {
          return AlertDialog(
            title: const Text('Change password'),
            content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Choose a strong password. You will need your current password to make this change.'),
              TextField(controller: current, obscureText: true, decoration: const InputDecoration(labelText: 'Current password')),
              TextField(controller: next, obscureText: true, decoration: const InputDecoration(labelText: 'New password')),
              TextField(controller: confirmation, obscureText: true, decoration: const InputDecoration(labelText: 'Confirm new password')),
              if (error != null) Text(error!, style: TextStyle(color: Theme.of(dialogContext).colorScheme.error)),
            ])),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
              FilledButton(onPressed: saving ? null : () async {
                if (next.text != confirmation.text) { update(() => error = 'New passwords do not match.'); return; }
                update(() { saving = true; error = null; });
                try {
                  await AuthApi.changePassword(current.text, next.text);
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password changed successfully.')));
                } catch (e) {
                  if (dialogContext.mounted) update(() => error = e.toString().replaceFirst('Exception: ', ''));
                } finally {
                  if (dialogContext.mounted) update(() => saving = false);
                }
              }, child: Text(saving ? 'Saving…' : 'Change password')),
            ],
          );
        },
      ));
    } finally {
      // Wait until the dialog exit animation finishes before disposing its fields.
      await Future<void>.delayed(const Duration(milliseconds: 350));
      current.dispose(); next.dispose(); confirmation.dispose();
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('Log out of CampusOS?'),
      content: const Text('You can log back in with your email and password. Your saved academic data will not be deleted.'),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Log out'))],
    ));
    if (confirmed == true) await widget.onLogout();
  }

  void _notReady(String title) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$title is coming soon')));
  Future<void> _notificationPreferences() async {
    final previous = AcademicNotifications.enabled;
    final enabled = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('Gentle reminders'),
      content: Text(previous
        ? 'Reminders are on. Turn them off? You can re-enable them anytime.'
        : 'Enable local lecture, deadline and study reminders? Alerts are limited to daytime hours and can work offline.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(dialogContext, !previous),
          child: Text(previous ? 'Turn off' : 'Enable reminders')),
      ],
    ));
    if (enabled == null) return;
    await AcademicNotifications.setEnabled(enabled);
    if (mounted) setState(() {});
  }

  Future<void> _pulsePreferences() async {
    if (!mounted) return;
    await showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('Campus Pulse privacy'),
      content: const Text('Campus Pulse uses aggregate study-mission completion totals from all eligible students. Student names, notes and individual study records are not displayed. You can view your private academic details only in your own account.'),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext),
        child: const Text('Understood'))],
    ));
  }
  Future<void> _openSupport() async {
    final pageMessenger = ScaffoldMessenger.of(context);
    final controller = TextEditingController();
    var category = 'bug';
    var sending = false;
    String? error;
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (sheetContext) => StatefulBuilder(builder: (sheetContext, update) => SafeArea(
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheetContext).height * .9),
              child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 22), shrinkWrap: true, children: [
                Text('Help & Support', style: Theme.of(sheetContext).textTheme.headlineSmall),
                const SizedBox(height: 10),
                const Text('FAQ · Your notes are kept locally for offline use. Sign in with the same account and use Data & sync when online. Never clear site data before making a backup.'),
                const SizedBox(height: 10),
                const Text('Payment help · Do not share bank details or passwords in support messages. Contact support about any payment discrepancy.'),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'What do you need help with?'),
                  items: const [
                    DropdownMenuItem(value: 'bug', child: Text('Report a problem')),
                    DropdownMenuItem(value: 'payment', child: Text('Payment help')),
                    DropdownMenuItem(value: 'privacy', child: Text('Privacy & account')),
                    DropdownMenuItem(value: 'general', child: Text('General question')),
                  ],
                  onChanged: sending ? null : (value) => update(() => category = value ?? 'bug'),
                ),
                const SizedBox(height: 12),
                TextField(controller: controller, minLines: 3, maxLines: 7, maxLength: 1500,
                  decoration: const InputDecoration(labelText: 'Describe the issue', border: OutlineInputBorder())),
                if (error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(error!, style: TextStyle(color: Theme.of(sheetContext).colorScheme.error))),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: sending ? null : () async {
                    if (controller.text.trim().length < 10) {
                      update(() => error = 'Please provide at least 10 characters.');
                      return;
                    }
                    update(() { sending = true; error = null; });
                    try {
                      await AuthApi.submitSupportTicket(category, controller.text.trim());
                      if (sheetContext.mounted) {
                        Navigator.pop(sheetContext);
                        pageMessenger.showSnackBar(
                          const SnackBar(content: Text('Your support request was received.')));
                      }
                    } catch (_) {
                      if (sheetContext.mounted) {
                        update(() => error =
                          'Could not send. Check the internet connection and try again; your message remains here.');
                      }
                    } finally {
                      if (sheetContext.mounted) {
                        update(() => sending = false);
                      }
                    }
                  },
                  icon: const Icon(Icons.send_outlined),
                  label: Text(sending ? 'Sending…' : 'Send support request'),
                ),
              ]),
            ),
          ),
        )),
      );
    } finally {
      // Prevent the outgoing sheet from rebuilding with a disposed controller.
      await Future<void>.delayed(const Duration(milliseconds: 400));
      controller.dispose();
    }
  }
  void _appearance() {
    showModalBottomSheet<void>(context: context, showDragHandle: true, builder: (sheetContext) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      for (final option in const [CampusAppearance.system, CampusAppearance.light, CampusAppearance.dark, CampusAppearance.nightComfort])
        ListTile(title: Text(switch(option) {CampusAppearance.system => 'Follow device', CampusAppearance.light => 'Light', CampusAppearance.dark => 'Dark', CampusAppearance.nightComfort => 'Night Comfort'}),
          trailing: widget.appearance == option ? Icon(Icons.check_circle, color: _accent) : null,
          onTap: () {widget.onAppearanceChanged(option); Navigator.pop(sheetContext);}),
      const SizedBox(height: 12),
    ])));
  }

  Widget _setting(IconData icon, String label, String detail, VoidCallback onTap) => ListTile(
    leading: Icon(icon, color: _accent), title: Text(label), subtitle: Text(detail, style: TextStyle(fontSize: 12, color: _muted)),
    trailing: const Icon(Icons.chevron_right_rounded), onTap: onTap,
  );
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(appBar: AppBar(title: const Text('My Profile')),
      body: SafeArea(child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(padding: const EdgeInsets.all(18), children: [
          Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [CircleAvatar(radius: 32, backgroundImage: _profile.photo == null ? null : MemoryImage(_profile.photo!),
              child: _profile.photo == null ? const Icon(Icons.person_rounded, size: 30) : null), const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_profile.name.isEmpty ? 'Your study space' : _profile.name, style: theme.textTheme.titleLarge),
                const SizedBox(height: 5),
                Text(_profile.complete ? '${_profile.department} · ${_profile.level}' : 'Make CampusOS yours in under a minute', style: TextStyle(color: _muted)),
                if (_profile.institution.isNotEmpty) Text(_profile.institution, style: TextStyle(color: _muted, fontSize: 12)),
              ])),
            ]), const SizedBox(height: 14),
            Text(_profile.complete ? 'Academic profile complete' : 'Complete your academic profile when you are ready', style: TextStyle(color: _accent, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _edit, icon: const Icon(Icons.edit_outlined), label: Text(_profile.complete ? 'Edit profile' : 'Set up profile'))),
          ]))),
          const SizedBox(height: 14),
          Card(child: Column(children: [
            const ListTile(title: Text('Academic information', style: TextStyle(fontWeight: FontWeight.bold))),
            _setting(Icons.apartment_outlined, 'Institution type', _profile.institutionType.isEmpty ? 'Not set' : _profile.institutionType, _edit),
            _setting(Icons.school_outlined, 'Institution', _profile.institution.isEmpty ? 'Not set' : _profile.institution, _edit),
            _setting(Icons.account_tree_outlined, 'Department', _profile.department.isEmpty ? 'Required for completed setup' : _profile.department, _edit),
            _setting(Icons.layers_outlined, 'Study level', _profile.level.isEmpty ? 'Not set' : _profile.level, _edit),
          ])),
          const SizedBox(height: 14),
          Card(child: Column(children: [
            const ListTile(title: Text('Preferences & account', style: TextStyle(fontWeight: FontWeight.bold))),
            _setting(Icons.card_giftcard_rounded, 'Invite Friends', 'Your personal code and invitation link', _inviteFriends),
            _setting(Icons.lock_outline_rounded, 'Change Password', 'Secure your CampusOS account', _changePassword),
            _setting(Icons.palette_outlined, 'Appearance', 'Light, Dark, Night Comfort, Follow device', _appearance),
            _setting(Icons.notifications_none_rounded, 'Reminders',
              AcademicNotifications.enabled ? 'Gentle reminders enabled' : 'Off · tap to enable', _notificationPreferences),
            _setting(Icons.shield_outlined, 'Campus Pulse privacy',
              'Aggregate progress · learn how it works', _pulsePreferences),
            _setting(Icons.workspace_premium_outlined, 'CampusOS Premium', '₦700 monthly · ₦2,000 quarterly · 3-day trial',
              () => _notReady('Payment activation')),
            _setting(Icons.cloud_outlined, 'Data & sync', 'Back up your study progress when connected', _syncNow),
            _setting(Icons.help_outline_rounded, 'Help & Support', 'FAQs, report a problem, payment and privacy help', _openSupport),
            const Divider(),
            ListTile(leading: Icon(Icons.logout_rounded, color: Theme.of(context).colorScheme.error), title: Text('Log out', style: TextStyle(fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.error)), subtitle: const Text('Sign out of this account'), onTap: _confirmLogout),
          ])),
          const SizedBox(height: 16),
          Center(child: Text('Private by default · Profile setup is optional to start studying', textAlign: TextAlign.center, style: TextStyle(color: _muted, fontSize: 12))),
          const SizedBox(height: 20),
        ]),
      ))),
    );
  }
}
