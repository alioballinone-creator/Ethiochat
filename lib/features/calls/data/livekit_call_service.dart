import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/env.dart';
import '../domain/call_models.dart';

/// Thin, reviewable wrapper around the LiveKit client.
///
/// Media credentials are requested from an authenticated Edge Function for
/// every call. No LiveKit API key or secret is compiled into the app.
class LiveKitCallService {
  LiveKitCallService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;
  Room? _room;
  CallJoinInfo? _join;

  Room? get room => _room;
  CallJoinInfo? get joinInfo => _join;
  bool get hasRemoteParticipants =>
      _room?.remoteParticipants.isNotEmpty ?? false;
  int get remoteParticipantCount => _room?.remoteParticipants.length ?? 0;

  List<Participant> get participants => [
        if (_room?.localParticipant != null) _room!.localParticipant!,
        ...?_room?.remoteParticipants.values,
      ];

  LocalVideoTrack? get localVideoTrack {
    final track =
        _room?.localParticipant?.videoTrackPublications.firstOrNull?.track;
    return track is LocalVideoTrack ? track : null;
  }

  List<VideoTrack> get remoteVideoTracks {
    final tracks = <VideoTrack>[];
    for (final participant
        in _room?.remoteParticipants.values ?? const <RemoteParticipant>[]) {
      for (final publication in participant.videoTrackPublications) {
        final track = publication.track;
        if (track != null) tracks.add(track);
      }
    }
    return tracks;
  }

  Future<CallJoinInfo> startOutgoing({
    required String conversationId,
    required bool video,
  }) async {
    final data = await _invokeFunction(Env.livekitTokenFunction, {
      'action': 'start',
      'conversationId': conversationId,
      'type': video ? 'video' : 'voice',
      'video': video,
    });
    return _parseJoin(data);
  }

  Future<CallJoinInfo> joinCall(String callId) async {
    final data = await _invokeFunction(Env.livekitTokenFunction, {
      'action': 'join',
      'callId': callId,
    });
    return _parseJoin(data);
  }

  Future<void> connect(CallJoinInfo info, {required bool video}) async {
    await _ensureMediaPermissions(video: video);
    final room = Room(
      roomOptions: const RoomOptions(
        adaptiveStream: true,
        dynacast: true,
      ),
    );
    _room = room;
    _join = info;
    await room.connect(info.url, info.token);
    await room.localParticipant?.setMicrophoneEnabled(true);
    if (video) {
      await room.localParticipant?.setCameraEnabled(true);
      await room.setSpeakerOn(true);
    } else {
      await room.setSpeakerOn(false);
    }
    await room.startAudio();
  }

  Future<void> setMicrophoneEnabled(bool enabled) async {
    final participant = _room?.localParticipant;
    if (participant == null)
      throw const CallException('Call is not connected.');
    await participant.setMicrophoneEnabled(enabled);
  }

  Future<void> setCameraEnabled(bool enabled) async {
    final participant = _room?.localParticipant;
    if (participant == null)
      throw const CallException('Call is not connected.');
    await participant.setCameraEnabled(enabled);
  }

  Future<void> setSpeakerEnabled(bool enabled) async {
    final room = _room;
    if (room == null) throw const CallException('Call is not connected.');
    await room.setSpeakerOn(enabled);
  }

  Future<bool> switchCamera() async {
    final track = localVideoTrack;
    if (track == null) return false;
    final devices = await Hardware.instance.videoInputs();
    if (devices.length < 2) return false;
    final current = Hardware.instance.selectedVideoInput;
    final next = devices.firstWhereOrNull(
          (device) => device.deviceId != current?.deviceId,
        ) ??
        devices.first;
    await track.switchCamera(next.deviceId);
    Hardware.instance.selectedVideoInput = next;
    return true;
  }

  Future<void> endCall({String? callId, bool rejected = false}) async {
    final id = callId ?? _join?.callId;
    Object? controlError;
    if (id != null && id.isNotEmpty) {
      try {
        await _invokeFunction('call-control', {
          'callId': id,
          'action': rejected ? 'reject' : 'end',
        });
      } catch (error) {
        controlError = error;
      }
    }
    await disconnect();
    if (controlError != null) {
      throw CallException(
        controlError is CallException
            ? controlError.message
            : 'The call ended locally, but the server could not be updated.',
      );
    }
  }

  Future<void> disconnect() async {
    final room = _room;
    _room = null;
    _join = null;
    if (room == null) return;
    try {
      await room.disconnect();
    } catch (error) {
      debugPrint('LiveKit disconnect failed: $error');
    }
    try {
      await room.dispose();
    } catch (error) {
      debugPrint('LiveKit room disposal failed: $error');
    }
  }

  Future<void> _ensureMediaPermissions({required bool video}) async {
    final microphone = await Permission.microphone.request();
    if (!microphone.isGranted) {
      throw const CallException(
        'Microphone permission is required for calls. Enable it in system settings.',
      );
    }
    if (!video) return;
    final camera = await Permission.camera.request();
    if (!camera.isGranted) {
      throw const CallException(
        'Camera permission is required for video calls. Enable it in system settings.',
      );
    }
  }

  Future<Map<String, dynamic>> _invokeFunction(
    String name,
    Map<String, dynamic> body,
  ) async {
    if (!Env.hasSupabase || !Env.hasLiveKit) {
      throw const CallException(
        'Voice and video calls are not configured for this build. '
        'Supabase and LIVEKIT_URL are required.',
      );
    }
    final client =
        _client ?? (Env.hasSupabase ? Supabase.instance.client : null);
    if (client == null) {
      throw const CallException('Supabase is not available.');
    }
    if (client.auth.currentSession == null) {
      throw const CallException('Sign in again to start a call.');
    }

    try {
      final response = await client.functions.invoke(name, body: body);
      final data = response.data;
      if (data is Map) {
        final result = Map<String, dynamic>.from(data);
        final error = result['error'];
        if (error is Map) {
          throw CallException(
            (error['message'] as String?) ?? 'Call request failed.',
          );
        }
        if (error is String) throw CallException(error);
        return result;
      }
      throw const CallException(
          'The call server returned an invalid response.');
    } on CallException {
      rethrow;
    } on FunctionException catch (error) {
      throw CallException(
        _functionError(error.details) ??
            'Call request failed (${error.status}).',
      );
    } catch (error) {
      throw CallException('Could not reach the call server: $error');
    }
  }

  String? _functionError(Object? details) {
    if (details is Map) {
      final error = details['error'];
      if (error is Map && error['message'] is String) {
        return error['message'] as String;
      }
    }
    return null;
  }

  CallJoinInfo _parseJoin(Map<String, dynamic> data) {
    final url = data['url'] as String?;
    final token = data['token'] as String?;
    final roomName = data['room'] as String?;
    final callId = data['callId'] as String?;
    final identity = data['identity'] as String?;
    if (url == null ||
        token == null ||
        roomName == null ||
        callId == null ||
        identity == null) {
      throw const CallException('The call server returned incomplete details.');
    }
    return CallJoinInfo(
      url: url,
      token: token,
      roomName: roomName,
      callId: callId,
      identity: identity,
    );
  }
}
