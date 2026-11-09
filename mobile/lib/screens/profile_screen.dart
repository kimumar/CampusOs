import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../main.dart';
import '../services/profile_storage.dart';
import '../services/auth_api.dart';
import '../services/cloud_sync.dart';

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
                  Text('Profile details sync to Django when online. Photos remain on this device for now.', style: TextStyle(color: Theme.of(sheetContext).colorScheme.onSurfaceVariant, fontSize: 12)),
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
                      catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved on this device. Cloud upload is pending; retry Data & sync.'))); }
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Academic data synchronized with Django.')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sync could not finish. Local data is safe. Check your connection and retry.')));
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
            _setting(Icons.palette_outlined, 'Appearance', 'Light, Dark, Night Comfort, Follow device', _appearance),
            _setting(Icons.notifications_none_rounded, 'Reminders', 'Coming soon', () => _notReady('Reminders')),
            _setting(Icons.shield_outlined, 'Privacy', 'Community participation will be opt-in', () => _notReady('Privacy controls')),
            _setting(Icons.workspace_premium_outlined, 'CampusOS Premium', 'Plans and trial details coming soon', () => _notReady('Subscriptions')),
            _setting(Icons.cloud_outlined, 'Data & sync', 'Tap to synchronize courses, timetable and profile with Django', _syncNow),
            _setting(Icons.help_outline_rounded, 'Help & feedback', 'Coming soon', () => _notReady('Help & feedback')),
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
