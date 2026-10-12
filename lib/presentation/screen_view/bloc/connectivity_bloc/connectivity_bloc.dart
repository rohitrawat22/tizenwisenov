import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:equatable/equatable.dart';

part 'connectivity_event.dart';
part 'connectivity_state.dart';

class ConnectivityBloc extends Bloc<ConnectivityEvent, ConnectivityState> {
  final Connectivity _connectivity = Connectivity();
  late StreamSubscription _subscription;

  ConnectivityBloc() : super(ConnectivityInitial()) {
    on<CheckInterNetConnectionEvent>(_checkInterNetConnectionEvent);
    on<ConnectivityChanged>(_onConnectivityChanged);

    _subscription = _connectivity.onConnectivityChanged.listen((result) {
      add(
        ConnectivityChanged(
          result.contains(ConnectivityResult.none) ? false : true,
        ),
      );
    });
  }

  void _onConnectivityChanged(
    ConnectivityChanged event,
    Emitter<ConnectivityState> emit,
  ) {
    if (event.isConnected) {
      emit(ConnectivityConnect());
    } else {
      emit(ConnectivityDisconnected());
    }
  }

  _checkInterNetConnectionEvent(event, Emitter<ConnectivityState> emit) async {
    final result = await _connectivity.checkConnectivity();
    if (result.contains(ConnectivityResult.none)) {
      emit(ConnectivityDisconnected());
    } else {
      emit(ConnectivityConnect());
    }
  }

  @override
  Future<void> close() {
    _subscription.cancel();
    return super.close();
  }
}
