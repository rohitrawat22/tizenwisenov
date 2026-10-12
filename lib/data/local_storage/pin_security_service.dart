import 'dart:convert';
import 'dart:developer';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Manages the device-level security PIN.
///
/// - Stores a SHA-256 hash locally (FlutterSecureStorage) for fast/offline
///   verification.
/// - Syncs the plain PIN to the backend via [onSyncToServer] /
///   [onRemoveFromServer] callbacks so the public playlist API is also gated.
/// - Default PIN is "0000" — a device without an explicit PIN set is
///   considered to have the default.
class PinSecurityService {
  final _storage = const FlutterSecureStorage();
  static const _pinKey = 'security_pin_hash';
  static const defaultPin = '0000';

  // ---------------------------------------------------------------------------
  // Hashing
  // ---------------------------------------------------------------------------

  /// SHA-256 hash to avoid storing the PIN in plain text.
  String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    return sha256.convert(bytes).toString();
  }

  // ---------------------------------------------------------------------------
  // Query
  // ---------------------------------------------------------------------------

  /// Returns `true` if the user has explicitly set a PIN (not the default).
  Future<bool> isPinCreated() async {
    final hash = await _storage.read(key: _pinKey);
    return hash != null;
  }

  // ---------------------------------------------------------------------------
  // Set / Change
  // ---------------------------------------------------------------------------

  /// Sets (or replaces) the device PIN.
  ///
  /// Stores the hash locally. Call [syncPinToServer] separately to push
  /// the PIN to the backend.
  Future<void> setPin(String newPin) async {
    final hash = _hashPin(newPin);
    await _storage.write(key: _pinKey, value: hash);
    if (kDebugMode) log('🔐 [PinSecurityService] PIN set locally');
  }

  // ---------------------------------------------------------------------------
  // Verify
  // ---------------------------------------------------------------------------

  /// Verifies the entered PIN against the stored hash.
  ///
  /// If no PIN has been set locally yet, verifies against the default
  /// PIN ("0000").
  Future<bool> verifyPin(String pin) async {
    final storedHash = await _storage.read(key: _pinKey);
    if (storedHash == null) {
      // No custom PIN set — accept the default.
      return pin == defaultPin;
    }
    return storedHash == _hashPin(pin);
  }

  /// Convenience: verifies [oldPin] before allowing a change to [newPin].
  ///
  /// Returns `true` if the old PIN was correct and the new PIN was saved.
  Future<bool> changePin({
    required String oldPin,
    required String newPin,
  }) async {
    final oldValid = await verifyPin(oldPin);
    if (!oldValid) return false;
    await setPin(newPin);
    return true;
  }

  // ---------------------------------------------------------------------------
  // Remove (Device PIN)
  // ---------------------------------------------------------------------------

  /// Removes the local device PIN, effectively reverting to the default "0000".
  Future<void> removePin() async {
    await _storage.delete(key: _pinKey);
    if (kDebugMode) log('🔓 [PinSecurityService] Device PIN removed locally');
  }

  // ===========================================================================
  // PLAYLIST PIN (Per-Playlist Security)
  // ===========================================================================

  String _getPlaylistKey(String playlistId) => 'playlist_pin_hash_$playlistId';

  /// Returns `true` if this specific playlist has a PIN set locally.
  Future<bool> isPlaylistPinCreated(String playlistId) async {
    final hash = await _storage.read(key: _getPlaylistKey(playlistId));
    return hash != null;
  }

  /// Sets the local PIN for a specific playlist.
  Future<void> setPlaylistPin({required String playlistId, required String pin}) async {
    final hash = _hashPin(pin);
    await _storage.write(key: _getPlaylistKey(playlistId), value: hash);
    if (kDebugMode) log('🔐 [PinSecurityService] Playlist PIN set for $playlistId');
  }

  /// Verifies the entered PIN against the stored hash for this playlist.
  Future<bool> verifyPlaylistPin({required String playlistId, required String pin}) async {
    final storedHash = await _storage.read(key: _getPlaylistKey(playlistId));
    if (storedHash == null) {
      // If no playlist PIN is set but it's locked, perhaps fallback to something or deny?
      // Since a PIN is required to lock it in the UI flow, this shouldn't happen.
      return false;
    }
    return storedHash == _hashPin(pin);
  }

  Future<bool> changePlaylistPin({
    required String playlistId,
    required String oldPin,
    required String newPin,
  }) async {
    final oldValid = await verifyPlaylistPin(playlistId: playlistId, pin: oldPin);
    if (!oldValid) return false;
    await setPlaylistPin(playlistId: playlistId, pin: newPin);
    return true;
  }

  Future<void> removePlaylistPin(String playlistId) async {
    await _storage.delete(key: _getPlaylistKey(playlistId));
    if (kDebugMode) log('🔓 [PinSecurityService] Playlist PIN removed for $playlistId');
  }
}
