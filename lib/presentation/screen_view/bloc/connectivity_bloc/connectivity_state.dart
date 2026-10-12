part of 'connectivity_bloc.dart';

sealed class ConnectivityState extends Equatable {
  const ConnectivityState();

  @override
  List<Object> get props => [];
}

final class ConnectivityInitial extends ConnectivityState {}

final class ConnectivityConnect extends ConnectivityState {}

final class ConnectivityFailed extends ConnectivityState {}

class ConnectivityDisconnected extends ConnectivityState {}
