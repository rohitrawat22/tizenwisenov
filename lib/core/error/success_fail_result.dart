class ApiResult<T> {
  final T? data;
  final String? error;

  final bool isSuccess;

  ApiResult._({this.data, this.error, required this.isSuccess});

  factory ApiResult.success(T data) {
    return ApiResult._(data: data, error: null, isSuccess: true);
  }

  factory ApiResult.failure(String error, [data = const {}]) {
    return ApiResult._(data: data, error: error, isSuccess: false);
  }
}
