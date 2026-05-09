import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../../core/constants/app_constants.dart';

class RemoteLibraryState {
  final bool isApproved;
  final bool isError;
  final List<dynamic> mediaItems;

  RemoteLibraryState({
    this.isApproved = false,
    this.isError = false,
    this.mediaItems = const [],
  });

  RemoteLibraryState copyWith({
    bool? isApproved,
    bool? isError,
    List<dynamic>? mediaItems,
  }) {
    return RemoteLibraryState(
      isApproved: isApproved ?? this.isApproved,
      isError: isError ?? this.isError,
      mediaItems: mediaItems ?? this.mediaItems,
    );
  }
}

final remoteLibraryControllerProvider =
    StateNotifierProvider.family<RemoteLibraryController, RemoteLibraryState, String>(
        (ref, serverIp) {
  return RemoteLibraryController(serverIp);
});

class RemoteLibraryController extends StateNotifier<RemoteLibraryState> {
  final String serverIp;
  Timer? _pollingTimer;

  RemoteLibraryController(this.serverIp) : super(RemoteLibraryState()) {
    fetchMedia();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> fetchMedia() async {
    try {
      final response = await http
          .get(Uri.parse('http://$serverIp:${AppConstants.serverPort}/media'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 403) {
        if (!state.isApproved) {
          _pollingTimer?.cancel();
          _pollingTimer = Timer(
            const Duration(seconds: AppConstants.handshakePollingIntervalSeconds),
            fetchMedia,
          );
        }
      } else if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        state = state.copyWith(
          isApproved: true,
          isError: false,
          mediaItems: data,
        );
      } else {
        state = state.copyWith(isError: true);
      }
    } catch (e) {
      if (!state.isApproved) {
        _pollingTimer?.cancel();
        _pollingTimer = Timer(
          const Duration(seconds: AppConstants.handshakePollingIntervalSeconds),
          fetchMedia,
        );
      }
    }
  }

  void retry() {
    state = state.copyWith(isError: false);
    fetchMedia();
  }
}
