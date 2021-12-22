/*
 * SPDX-FileCopyrightText: 2019-2021 Vishesh Handa <me@vhanda.in>
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

import 'package:gitjournal/core/folder/notes_folder.dart';
import 'package:gitjournal/core/folder/notes_folder_notifier.dart';
import 'package:gitjournal/core/note.dart';

typedef NotesFilter = Future<bool> Function(Note note);

class FlattenedNotesFolder with NotesFolderNotifier implements NotesFolder {
  final NotesFolder _parentFolder;
  final String title;

  final _notes = <Note>[];
  final _notesPaths = <String, int>{};
  final _folders = <NotesFolder>[];

  FlattenedNotesFolder(this._parentFolder, {required this.title}) {
    _addFolder(_parentFolder);
  }

  void _addFolder(NotesFolder folder) {
    _folders.add(folder);

    // Add Change notifiers
    folder.addFolderAddedListener(_folderAdded);
    folder.addFolderRemovedListener(_folderRemoved);

    folder.addNoteAddedListener(_noteAdded);
    folder.addNoteRemovedListener(_noteRemoved);
    folder.addNoteModifiedListener(_noteModified);
    folder.addNoteRenameListener(_noteRenamed);

    // Add Individual Notes
    for (var note in folder.notes) {
      _noteAdded(-1, note);
    }

    // Add Sub-Folders
    for (var folder in folder.subFolders) {
      _addFolder(folder);
    }
  }

  @override
  void dispose() {
    for (var folder in _folders) {
      _folderRemoved(-1, folder);
    }

    super.dispose();
  }

  void _folderAdded(int _, NotesFolder folder) {
    _addFolder(folder);
  }

  void _folderRemoved(int _, NotesFolder folder) {
    //
    // FIXME: Wouldn't all the notes from this folder also need to be removed?
    //
    folder.removeFolderAddedListener(_folderAdded);
    folder.removeFolderRemovedListener(_folderRemoved);

    folder.removeNoteAddedListener(_noteAdded);
    folder.removeNoteRemovedListener(_noteRemoved);
    folder.removeNoteModifiedListener(_noteModified);
    folder.removeNoteRenameListener(_noteRenamed);
  }

  void _noteAdded(int _, Note note) {
    if (!_notesPaths.containsKey(note.filePath)) {
      _notes.add(note);
      _notesPaths[note.filePath] = _notes.length - 1;
      notifyNoteAdded(_notes.length - 1, note);
    } else {
      assert(
          false, '_noteAdded called on a note already added ${note.filePath}');
      notifyNoteModified(_notesPaths[note.filePath]!, note);
    }
  }

  void _noteRemoved(int _, Note note) {
    var i = _notesPaths[note.filePath];
    assert(i != null);
    if (i == null) {
      return;
    }

    var removedNote = _notes.removeAt(i);
    assert(removedNote.filePath == note.filePath);
    notifyNoteRemoved(i, note);
  }

  Future<void> _noteModified(int _, Note note) async {
    var i = _notesPaths[note.filePath];
    assert(i != null);
    i ??= -1;

    notifyNoteModified(i, note);
  }

  void _noteRenamed(int _, Note note, String oldPath) {
    var i = _notesPaths[oldPath];
    assert(i != null);
    i ??= -1;

    notifyNoteRenamed(i, note, oldPath);
  }

  @override
  List<Note> get notes => _notes;

  @override
  List<NotesFolder> get subFolders => [];

  @override
  bool get hasNotes => _notes.isNotEmpty;

  @override
  bool get isEmpty => _notes.isEmpty;

  @override
  NotesFolder? get parent => null;

  @override
  NotesFolder? get fsFolder => _parentFolder.fsFolder;

  @override
  String get name => title;

  @override
  String get publicName => title;

  @override
  NotesFolderConfig get config {
    return _parentFolder.config;
  }
}
