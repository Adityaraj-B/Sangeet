import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Firestore-backed playlist service.
/// All operations are scoped to the currently logged-in user.
class PlaylistService {
  PlaylistService._();
  static final PlaylistService instance = PlaylistService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Returns the current user's UID or throws if not logged in.
  String get _uid {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('User must be logged in to access playlists');
    }
    return user.uid;
  }

  /// Reference to the user's playlists subcollection.
  CollectionReference<Map<String, dynamic>> get _playlistsRef =>
      _firestore.collection('users').doc(_uid).collection('playlists');

  /// Creates a new playlist with the given name.
  /// Returns the created playlist's document ID.
  Future<String> createPlaylist(String name) async {
    final docRef = await _playlistsRef.add({
      'name': name,
      'createdAt': FieldValue.serverTimestamp(),
      'songIds': <String>[],
      'songs': <Map<String, dynamic>>[],
    });
    return docRef.id;
  }

  /// Returns a real-time stream of the user's playlists,
  /// ordered by creation date (newest first).
  Stream<QuerySnapshot<Map<String, dynamic>>> playlistsStream() {
    return _playlistsRef
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Adds a song ID to the specified playlist.
  /// Uses arrayUnion to avoid duplicates.
  Future<void> addSongToPlaylist(String playlistId, String songId, Map<String, dynamic> songData) async {
    await _playlistsRef.doc(playlistId).update({
      'songIds': FieldValue.arrayUnion([songId]),
      'songs': FieldValue.arrayUnion([songData]),
    });
  }

  /// Removes a song ID from the specified playlist.
  Future<void> removeSongFromPlaylist(String playlistId, String songId, Map<String, dynamic> songData) async {
    await _playlistsRef.doc(playlistId).update({
      'songIds': FieldValue.arrayRemove([songId]),
      'songs': FieldValue.arrayRemove([songData]),
    });
  }

  /// Deletes a playlist by its document ID.
  Future<void> deletePlaylist(String playlistId) async {
    await _playlistsRef.doc(playlistId).delete();
  }

  /// Renames a playlist.
  Future<void> renamePlaylist(String playlistId, String newName) async {
    await _playlistsRef.doc(playlistId).update({
      'name': newName,
    });
  }

  /// Updates the entire songs array for a playlist.
  /// This is used when reordering or bulk removing songs.
  Future<void> updatePlaylistSongs(String playlistId, List<String> songIds, List<Map<String, dynamic>> songs) async {
    await _playlistsRef.doc(playlistId).update({
      'songIds': songIds,
      'songs': songs,
    });
  }

  /// Gets a single playlist by ID (one-time fetch).
  Future<DocumentSnapshot<Map<String, dynamic>>> getPlaylist(String playlistId) {
    return _playlistsRef.doc(playlistId).get();
  }
}
