import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/note.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';

class NoteFormScreen extends StatefulWidget {
  const NoteFormScreen({super.key, this.note});

  final Note? note;

  @override
  State<NoteFormScreen> createState() => _NoteFormScreenState();
}

class _NoteFormScreenState extends State<NoteFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _firestoreService = FirestoreService();
  final _storageService = StorageService();
  final _imagePicker = ImagePicker();
  File? _selectedImage;
  bool _removeExistingImage = false;
  bool _isSaving = false;
  double? _uploadProgress;

  bool get _isEditing => widget.note != null;

  @override
  void initState() {
    super.initState();
    final note = widget.note;
    if (note != null) {
      _titleController.text = note.title;
      _contentController.text = note.content;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 80,
      );

      if (image == null) {
        return;
      }

      final file = File(image.path);
      final size = await file.length();
      if (size > StorageService.maxImageSizeBytes) {
        _showSnackBar('Image must be smaller than 5 MB.');
        return;
      }

      setState(() {
        _selectedImage = file;
        _removeExistingImage = false;
      });
    } catch (error) {
      _showSnackBar('Could not pick image: $error');
    }
  }

  void _removePhoto() {
    setState(() {
      _selectedImage = null;
      _removeExistingImage = widget.note?.imageUrl != null;
    });
  }

  Future<void> _saveNote() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
      _uploadProgress = null;
    });
    try {
      final title = _titleController.text;
      final content = _contentController.text;

      if (_isEditing) {
        await _updateExistingNote(title, content);
      } else {
        await _createNewNote(title, content);
      }

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isEditing ? 'Note updated.' : 'Note created.')),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _uploadProgress = null;
        });
      }
    }
  }

  Future<void> _createNewNote(String title, String content) async {
    final noteId = await _firestoreService.createNote(title, content);
    final imageFile = _selectedImage;
    if (imageFile == null) {
      return;
    }

    final imageUrl = await _uploadImage(imageFile, noteId);
    await _firestoreService.updateNoteImage(
      noteId,
      imageUrl,
      storagePath: _storageService.lastUploadedPath,
    );
  }

  Future<void> _updateExistingNote(String title, String content) async {
    final note = widget.note!;
    final imageFile = _selectedImage;

    if (imageFile != null) {
      final imageUrl = await _uploadImage(imageFile, note.id);
      await _deleteExistingImage(note);
      await _firestoreService.updateNote(
        note.id,
        title,
        content,
        imageUrl: imageUrl,
        storagePath: _storageService.lastUploadedPath,
      );
      return;
    }

    if (_removeExistingImage) {
      await _deleteExistingImage(note);
      await _firestoreService.updateNote(
        note.id,
        title,
        content,
        removeImage: true,
      );
      return;
    }

    await _firestoreService.updateNote(note.id, title, content);
  }

  Future<String> _uploadImage(File imageFile, String noteId) {
    return _storageService.uploadNoteImageWithProgress(imageFile, noteId, (
      progress,
    ) {
      if (mounted) {
        setState(() => _uploadProgress = progress);
      }
    });
  }

  Future<void> _deleteExistingImage(Note note) async {
    try {
      final storagePath = note.storagePath;
      final imageUrl = note.imageUrl;
      if (storagePath != null && storagePath.isNotEmpty) {
        await _storageService.deleteNoteImageByPath(storagePath);
      } else if (imageUrl != null && imageUrl.isNotEmpty) {
        await _storageService.deleteNoteImage(imageUrl);
      }
    } catch (_) {
      _showSnackBar('Photo delete failed, note changes will continue.');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Note' : 'New Note')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  prefixIcon: Icon(Icons.title),
                ),
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'Title is required.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contentController,
                decoration: const InputDecoration(
                  labelText: 'Content',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.notes),
                ),
                minLines: 6,
                maxLines: 12,
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'Content is required.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              _AttachmentSection(
                selectedImage: _selectedImage,
                imageUrl: _removeExistingImage ? null : widget.note?.imageUrl,
                onAddPhoto: _isSaving ? null : _pickImage,
                onRemovePhoto: _isSaving ? null : _removePhoto,
              ),
              if (_uploadProgress != null) ...[
                const SizedBox(height: 16),
                LinearProgressIndicator(value: _uploadProgress),
                const SizedBox(height: 8),
                Text(
                  'Uploading... ${((_uploadProgress ?? 0) * 100).round()}%',
                ),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _isSaving ? null : _saveNote,
                icon: _isSaving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(_isEditing ? 'Save changes' : 'Create note'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttachmentSection extends StatelessWidget {
  const _AttachmentSection({
    required this.selectedImage,
    required this.imageUrl,
    required this.onAddPhoto,
    required this.onRemovePhoto,
  });

  final File? selectedImage;
  final String? imageUrl;
  final VoidCallback? onAddPhoto;
  final VoidCallback? onRemovePhoto;

  bool get _hasPhoto =>
      selectedImage != null || (imageUrl != null && imageUrl!.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Attachment', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            if (_hasPhoto) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: selectedImage != null
                      ? Image.file(selectedImage!, fit: BoxFit.cover)
                      : Image.network(
                          imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const ColoredBox(
                            color: Color(0xFFECEFF1),
                            child: Center(
                              child: Icon(Icons.broken_image_outlined),
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onAddPhoto,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(_hasPhoto ? 'Change Photo' : 'Add Photo'),
                ),
                if (_hasPhoto)
                  OutlinedButton.icon(
                    onPressed: onRemovePhoto,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Remove Photo'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
