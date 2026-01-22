import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:sangeet/constants.dart';
import '../../../models/playlist.dart';
import '../../../models/song.dart';

class PlaylistEditScreen extends StatefulWidget {
  final Playlist playlist;

  const PlaylistEditScreen({super.key, required this.playlist});

  @override
  State<PlaylistEditScreen> createState() => _PlaylistEditScreenState();
}

class _PlaylistEditScreenState extends State<PlaylistEditScreen> {
  late List<Song> _songs;
  late TextEditingController _titleController;

  bool _isSelectionMode = false;
  final Set<String> _selectedSongIds = {};
  bool _hasChanged = false;

  @override
  void initState() {
    super.initState();
    _songs = List.from(widget.playlist.songs);
    _titleController = TextEditingController(text: widget.playlist.title);
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  // --- Logic ---

  void _onReorder(int oldIndex, int newIndex) {
    if (_isSelectionMode) return;
    setState(() {
      if (oldIndex < newIndex) newIndex -= 1;
      final Song item = _songs.removeAt(oldIndex);
      _songs.insert(newIndex, item);
      _hasChanged = true;
    });
  }

  void _toggleSelection(String songId) {
    setState(() {
      if (_selectedSongIds.contains(songId)) {
        _selectedSongIds.remove(songId);
      } else {
        _selectedSongIds.add(songId);
      }
    });
  }

  void _deleteSelectedSongs() {
    setState(() {
      _songs.removeWhere((s) => _selectedSongIds.contains(s.id));
      _selectedSongIds.clear();
      _isSelectionMode = false;
      _hasChanged = true;
    });
  }

  void _saveAndExit() {
    final result = {
      'title': _titleController.text.trim(),
      'songs': _songs,
    };
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final coverUrl = _songs.isNotEmpty ? _songs.first.coverUrl : '';
    return Scaffold(
      backgroundColor: kBackgroundColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
        ),
        leadingWidth: 80,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0, top: 10, bottom: 10),
            child: ElevatedButton(
              onPressed: (_hasChanged ||
                  _titleController.text != widget.playlist.title)
                  ? _saveAndExit
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: kAccentColor,
                foregroundColor: Colors.black,
                disabledBackgroundColor: Colors.grey[800],
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 24),
              ),
              child: const Text("Save",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          if (coverUrl.isNotEmpty)
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                child: Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: NetworkImage(coverUrl),
                      fit: BoxFit.cover,
                      opacity: 0.6, // Dim slightly
                    ),
                  ),
                ),
              ),
            ),
          
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.2), // Top is see-through
                    kBackgroundColor.withValues(alpha: 0.95), // Start darkening
                    kBackgroundColor,                  // Bottom is solid black
                  ],
                  stops: const [0.1, 0.55, 1.0], // Adjust fade point
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header (Image + Title Field)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                  child: Column(
                    children: [
                      // Playlist Image
                      Center(
                        child: Container(
                          width: 220,
                          height: 220,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10))
                            ],
                            image: coverUrl.isNotEmpty
                                ? DecorationImage(
                                image: NetworkImage(coverUrl),
                                fit: BoxFit.cover)
                                : null,
                            color: Colors.grey[850],
                          ),
                          child: coverUrl.isEmpty
                              ? const Icon(Icons.music_note,
                              size: 80, color: Colors.white24)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 25),

                      // Editable Title
                      TextField(
                        controller: _titleController,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800),
                        decoration: InputDecoration(
                          hintText: "Playlist Name",
                          hintStyle: TextStyle(color: Colors.grey[600]),
                          border: InputBorder.none,
                          enabledBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white24),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: kAccentColor),
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  ),
                ),

                // Selection Bar (Visible only in selection mode)
                if (_isSelectionMode)
                  Padding(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () {
                            setState(() {
                              _isSelectionMode = false;
                              _selectedSongIds.clear();
                            });
                          },
                        ),
                        const SizedBox(width: 10),
                        Text(
                          "${_selectedSongIds.length} Selected",
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.white),
                          onPressed: _selectedSongIds.isNotEmpty
                              ? _deleteSelectedSongs
                              : null,
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              if (_selectedSongIds.length == _songs.length) {
                                _selectedSongIds.clear();
                              } else {
                                _selectedSongIds
                                    .addAll(_songs.map((s) => s.id));
                              }
                            });
                          },
                          child: Text(
                            _selectedSongIds.length == _songs.length
                                ? "Deselect all"
                                : "Select all",
                            style: TextStyle(
                                color: kAccentColor,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                // Select Button (Visible only in normal mode)
                  Padding(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _isSelectionMode = true;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[900],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                        ),
                        child: const Text("Select",
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),

                // Song List
                Expanded(
                  child: ReorderableListView.builder(
                    padding: const EdgeInsets.only(bottom: 40),
                    itemCount: _songs.length,
                    onReorder: _onReorder,
                    buildDefaultDragHandles: false,
                    proxyDecorator: (child, index, animation) {
                      return Material(
                        color: Colors.transparent,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              color: const Color(0xFF2C2C2C).withValues(alpha: 0.7),
                              child: child,
                            ),
                          ),
                        ),
                      );
                    },
                    itemBuilder: (context, index) {
                      final song = _songs[index];
                      final isSelected = _selectedSongIds.contains(song.id);

                      return InkWell(
                        key: ValueKey(song.id),
                        onTap: () {
                          if (_isSelectionMode) {
                            _toggleSelection(song.id);
                          }
                        },
                        onLongPress: () {
                          if (!_isSelectionMode) {
                            setState(() {
                              _isSelectionMode = true;
                              _toggleSelection(song.id);
                            });
                          }
                        },
                        child: Container(
                          color: isSelected
                              ? kAccentColor.withValues(alpha: 0.1)
                              : Colors.transparent,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 8),
                            leading: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_isSelectionMode)
                                  Checkbox(
                                    value: isSelected,
                                    onChanged: (value) =>
                                        _toggleSelection(song.id),
                                    activeColor: kAccentColor,
                                    checkColor: Colors.black,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4)),
                                  )
                                else
                                  ReorderableDragStartListener(
                                    index: index,
                                    child: const Padding(
                                      padding: EdgeInsets.only(right: 16.0),
                                      child: Icon(Icons.drag_handle_rounded,
                                          color: Colors.grey),
                                    ),
                                  ),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.network(
                                    song.coverUrl,
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.cover,
                                    errorBuilder: (c, e, s) => Container(
                                        width: 48,
                                        height: 48,
                                        color: Colors.grey[800]),
                                  ),
                                ),
                              ],
                            ),
                            title: Text(
                              song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isSelected ? kAccentColor : Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Text(
                              song.artist,
                              maxLines: 1,
                              style: TextStyle(
                                  color: Colors.grey[400], fontSize: 14),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

