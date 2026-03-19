import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';

/// Lightweight wrapper around `livekit_client` (mirrors Web `useLiveKit`).
///
/// Manages a single LiveKit [Room] connection for voice/video calls.
class LiveKitService {
  Room? _room;
  EventsListener<RoomEvent>? _listener;

  final ValueNotifier<ConnectionState> connectionState =
      ValueNotifier(ConnectionState.disconnected);

  LocalParticipant? get localParticipant => _room?.localParticipant;

  /// The first remote participant (1-to-1 calls only).
  RemoteParticipant? get remoteParticipant {
    final participants = _room?.remoteParticipants.values;
    if (participants != null && participants.isNotEmpty) {
      return participants.first;
    }
    return null;
  }

  /// Notifies listeners when a remote participant joins or their tracks change.
  final StreamController<RemoteParticipant?> _remoteParticipantController =
      StreamController<RemoteParticipant?>.broadcast();
  Stream<RemoteParticipant?> get remoteParticipantStream =>
      _remoteParticipantController.stream;

  /// Connect to a LiveKit room.
  Future<void> connect(String serverUrl, String token) async {
    // Disconnect any existing room.
    await disconnect();

    debugPrint('[LiveKit] Connecting to: $serverUrl');

    final room = Room(
      roomOptions: const RoomOptions(
        adaptiveStream: true,
        dynacast: true,
        defaultAudioPublishOptions: AudioPublishOptions(
          dtx: true,
        ),
        defaultVideoPublishOptions: VideoPublishOptions(
          simulcast: true,
        ),
      ),
    );

    _listener = room.createListener();

    _listener!
      ..on<RoomConnectedEvent>((event) {
        debugPrint('[LiveKit] Connected');
        connectionState.value = ConnectionState.connected;
      })
      ..on<RoomDisconnectedEvent>((event) {
        debugPrint('[LiveKit] Disconnected');
        connectionState.value = ConnectionState.disconnected;
        _remoteParticipantController.add(null);
      })
      ..on<RoomReconnectingEvent>((event) {
        connectionState.value = ConnectionState.reconnecting;
      })
      ..on<RoomReconnectedEvent>((event) {
        connectionState.value = ConnectionState.connected;
      })
      ..on<ParticipantConnectedEvent>((event) {
        debugPrint('[LiveKit] Participant connected: ${event.participant.identity}');
        _remoteParticipantController.add(event.participant);
      })
      ..on<ParticipantDisconnectedEvent>((event) {
        debugPrint('[LiveKit] Participant disconnected: ${event.participant.identity}');
        _remoteParticipantController.add(null);
      })
      ..on<TrackSubscribedEvent>((event) {
        _remoteParticipantController.add(event.participant);
      })
      ..on<TrackUnsubscribedEvent>((event) {
        _remoteParticipantController.add(event.participant);
      });

    await room.connect(serverUrl, token);

    _room = room;
    connectionState.value = ConnectionState.connected;
    debugPrint('[LiveKit] Connected! Local: ${room.localParticipant?.identity}');

    // Sync any already-present remote participants.
    if (room.remoteParticipants.isNotEmpty) {
      _remoteParticipantController
          .add(room.remoteParticipants.values.first);
    }
  }

  /// Disconnect from the LiveKit room.
  Future<void> disconnect() async {
    _listener?.dispose();
    _listener = null;
    if (_room != null) {
      await _room!.disconnect();
      await _room!.dispose();
      _room = null;
    }
    connectionState.value = ConnectionState.disconnected;
  }

  /// Enable/disable the microphone.
  Future<void> setMicrophoneEnabled(bool enabled) async {
    if (_room == null) return;
    await _room!.localParticipant?.setMicrophoneEnabled(enabled);
  }

  /// Enable/disable the camera.
  Future<void> setCameraEnabled(bool enabled) async {
    if (_room == null) return;
    await _room!.localParticipant?.setCameraEnabled(enabled);
  }

  /// Switch between front and back camera (mobile-only).
  Future<void> switchCamera() async {
    // LocalVideoTrack camera switching not supported directly in this LiveKit flutter version.
    // Can be implemented using flutter_webrtc's Helper directly if needed.
  }

  /// Toggle speaker output (iOS/Android).
  Future<void> setSpeakerphoneOn(bool on) async {
    await Hardware.instance.setSpeakerphoneOn(on);
  }

  void dispose() {
    disconnect();
    _remoteParticipantController.close();
    connectionState.dispose();
  }
}
