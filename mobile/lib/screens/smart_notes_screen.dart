import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../services/course_storage.dart';
import '../services/lesson_notes_storage.dart';
import '../services/document_text_extractor.dart';
import '../services/photo_text_recognizer.dart';
import '../services/cloud_sync.dart';
import 'focus_study_screen.dart';

/// Review-before-save local PDF and photo notes. Source files stay temporary.
class SmartNotesScreen extends StatefulWidget {
  const SmartNotesScreen({super.key});
  @override
  State<SmartNotesScreen> createState() => _SmartNotesScreenState();
}

class _SmartNotesScreenState extends State<SmartNotesScreen> {
  final titleController = TextEditingController();
  final notesController = TextEditingController();
  final imagePicker = ImagePicker();
  Uint8List? temporaryPhoto;
  String? photoName;
  List<XFile> photoBatch = [];
  bool extracting = false;
  String? importMessage;
  String selectedCourseId = '';
  bool loading = true;
  List<Map<String, dynamic>> savedNotes = [];
  String? activeNoteId;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    await LessonNotesStorage.initialize();
    if (mounted) setState(() { savedNotes = LessonNotesStorage.all(); loading = false; });
  }

  @override
  void dispose() {
    titleController.dispose();
    notesController.dispose();
    super.dispose();
  }

  Future<void> _selectImage(ImageSource source) async {
    try {
      final image = await imagePicker.pickImage(source: source, imageQuality: 75, maxWidth: 1800);
      if (image == null) return;
      final data = await image.readAsBytes();
      if (data.length > 3 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('The selected image is over 3 MB. Choose a smaller image.')));
        }
        return;
      }
      if (mounted) setState(() { temporaryPhoto = data; photoName = image.name; photoBatch = [image]; importMessage = null; });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the image picker on this device. You can still type your notes.')));
      }
    }
  }

  Future<void> _selectPhotos() async {
    try {
      final files = await imagePicker.pickMultiImage(imageQuality: 75, maxWidth: 1800);
      if (files.isEmpty) return;
      if (files.length > 10) throw const FormatException('Choose no more than ten pages at a time.');
      for (final file in files) {
        if (await file.length() > 3 * 1024 * 1024) {
          throw const FormatException('Each image must be smaller than 3 MB.');
        }
      }
      final preview = await files.first.readAsBytes();
      if (mounted) {
        setState(() {
          photoBatch = files;
          temporaryPhoto = preview;
          photoName = '${files.length} selected ${files.length == 1 ? 'page' : 'pages'}';
          importMessage = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => importMessage = 'Photo selection: $error');
    }
  }

  void _appendExtractedText(String text, String source) {
    final existing = notesController.text.trim();
    notesController.text = existing.isEmpty ? text : '$existing\n\n$text';
    if (mounted) setState(() => importMessage = '$source extracted. Review and correct the text before saving or generating recall questions.');
  }

  Future<void> _importPdf() async {
    if (extracting) return;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['pdf'], withData: true,
      );
      if (result == null) return;
      final file = result.files.single;
      if (file.size > DocumentTextExtractor.maximumPdfBytes) {
        throw const FormatException('Select a PDF smaller than 8 MB.');
      }
      final bytes = file.bytes;
      if (bytes == null) throw const FormatException('Could not read this PDF. Please choose a local file.');
      if (mounted) setState(() { extracting = true; importMessage = null; });
      final text = await DocumentTextExtractor.extractPdf(bytes);
      _appendExtractedText(text, 'PDF');
    } catch (error) {
      if (mounted) setState(() => importMessage = 'PDF import: $error');
    } finally {
      if (mounted) setState(() => extracting = false);
    }
  }

  Future<void> _extractPhoto() async {
    if (extracting || photoBatch.isEmpty) return;
    if (mounted) setState(() { extracting = true; importMessage = null; });
    try {
      final pages = <String>[];
      for (final photo in photoBatch) {
        pages.add(await PhotoTextRecognizer.extractFromPath(photo.path));
      }
      final text = pages.join('\n\n');
      if (text.length > DocumentTextExtractor.maximumTextCharacters) {
        throw const FormatException('Extracted notes are too long. Try a shorter page.');
      }
      _appendExtractedText(text, 'Photo');
    } catch (error) {
      if (mounted) setState(() => importMessage = 'Photo OCR: $error');
    } finally {
      if (mounted) setState(() => extracting = false);
    }
  }

  Future<String?> _save() async {
    if (notesController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add readable notes first. Photos by themselves do not produce text questions.')));
      return null;
    }
    final selected = CourseStorage.allForSync().where((course) => course.id == selectedCourseId);
    final course = selected.isNotEmpty ? selected.first : null;
    final id = await LessonNotesStorage.save(
      id: activeNoteId, title: titleController.text.trim().isEmpty ? 'Study notes' : titleController.text.trim(),
      text: notesController.text,
      courseId: selectedCourseId, courseName: course?.title ?? '', courseCode: course?.code ?? '',
    );
    activeNoteId = id;
    CloudSync.queueSync();
    if (mounted) await _load();
    return id;
  }

  Future<void> _startStudying() async {
    final id = await _save();
    if (id == null || !mounted) return;
    final selected = CourseStorage.allForSync().where((course) => course.id == selectedCourseId);
    final course = selected.isNotEmpty ? selected.first : null;
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => FocusStudyScreen(
      missionId: 'notes::$id',
      title: course?.title ?? 'Independent study',
      courseId: selectedCourseId,
      initialNotes: notesController.text,
      initialTopic: titleController.text,
    )));
  }

  void _openSaved(Map<String, dynamic> item) {
    setState(() {
      titleController.text = (item['title'] ?? '').toString();
      notesController.text = (item['text'] ?? '').toString();
      selectedCourseId = (item['course_id'] ?? '').toString();
      activeNoteId = (item['id'] ?? '').toString();
      temporaryPhoto = null;
      photoName = null;
      photoBatch = [];
      importMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final courses = CourseStorage.getCourses();
    final value = courses.any((course) => course.id == selectedCourseId) ? selectedCourseId : '';
    return Scaffold(
      appBar: AppBar(title: const Text('Smart Notes')),
      body: loading ? const Center(child: CircularProgressIndicator()) :
        ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: [
          const Text('Import PDF text or photograph notes. Review extracted text before saving and generating recall questions. Originals are not stored.'),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: value, isExpanded: true,
            decoration: const InputDecoration(labelText: 'Course (optional)', border: OutlineInputBorder()),
            items: [
              const DropdownMenuItem(value: '', child: Text('Independent study')),
              for (final course in courses)
                DropdownMenuItem(value: course.id, child: Text('${course.code} · ${course.title}', overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (courseId) => setState(() => selectedCourseId = courseId ?? ''),
          ),
          const SizedBox(height: 14),
          TextField(controller: titleController, maxLength: 120,
            decoration: const InputDecoration(labelText: 'Topic / note title', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: notesController, minLines: 7, maxLines: 15,
            decoration: const InputDecoration(labelText: 'Readable study notes', alignLabelWithHint: true,
              hintText: 'Type or paste text from your PDF, lecture notes or textbook...', border: OutlineInputBorder())),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 6, children: [
            OutlinedButton.icon(onPressed: extracting ? null : _importPdf,
              icon: const Icon(Icons.picture_as_pdf_outlined), label: const Text('Import PDF text')),
            OutlinedButton.icon(onPressed: () => _selectImage(ImageSource.gallery),
              icon: const Icon(Icons.image_outlined), label: const Text('Choose a photo')),
            OutlinedButton.icon(onPressed: _selectPhotos,
              icon: const Icon(Icons.collections_outlined), label: const Text('Choose up to 10 pages')),
            OutlinedButton.icon(onPressed: () => _selectImage(ImageSource.camera),
              icon: const Icon(Icons.photo_camera_outlined), label: const Text('Take a photo')),
            TextButton.icon(onPressed: () => setState(() { temporaryPhoto = null; photoName = null; photoBatch = []; }),
              icon: const Icon(Icons.delete_outline), label: const Text('Clear temporary photo')),
          ]),
          if (temporaryPhoto != null) ...[
            const SizedBox(height: 8),
            Text(photoName ?? 'Temporary image', style: Theme.of(context).textTheme.bodySmall),
            ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(
              temporaryPhoto!, height: 180, fit: BoxFit.contain)),
            const SizedBox(height: 6),
            FilledButton.icon(onPressed: extracting ? null : _extractPhoto,
              icon: const Icon(Icons.document_scanner_outlined), label: const Text('Extract text from photo')),
            const Text('Photo OCR works in installed Android/iOS apps. Chrome preview does not have native OCR. Clear printed text works best; handwriting may need manual correction.'),
          ],
          if (extracting) const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator()),
          if (importMessage != null) Padding(padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(importMessage!, style: Theme.of(context).textTheme.bodySmall)),
          const SizedBox(height: 8),
          FilledButton.icon(onPressed: _startStudying, icon: const Icon(Icons.menu_book_outlined),
            label: const Text('Save notes and start studying')),
          const SizedBox(height: 8),
          OutlinedButton.icon(onPressed: () async {
            final id = await _save();
            if (id != null && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Text notes saved on this device.')));
            }
          }, icon: const Icon(Icons.save_outlined), label: const Text('Save text notes')),
          const SizedBox(height: 22),
          Text('My saved notes', style: Theme.of(context).textTheme.titleMedium),
          if (savedNotes.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('No saved notes yet.')),
          for (final item in savedNotes)
            Card(child: ListTile(
              title: Text((item['title'] ?? 'Notes').toString()),
              subtitle: Text((item['course_name'] ?? '').toString().isEmpty
                ? 'Independent notes' : item['course_name'].toString()),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openSaved(item),
            )),
          const SizedBox(height: 12),
          const Text('PDF text extraction runs locally. Scanned PDFs without a text layer need a different OCR step. No paid AI or remote document upload is used.'),
        ]),
    );
  }
}
