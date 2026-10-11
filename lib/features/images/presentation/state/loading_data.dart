/// Progress of an image job. Plain immutable value class.
class LoadingData {
  final int? progressCounter;
  final int? totalSteps;
  final int? completedSteps;
  final bool isLoading;

  const LoadingData({
    this.progressCounter,
    this.totalSteps,
    this.completedSteps,
    required this.isLoading,
  });

  LoadingData copyWith(
      {int? progressCounter,
      int? totalSteps,
      int? completedSteps,
      bool? isLoading}) {
    return LoadingData(
      progressCounter: progressCounter ?? this.progressCounter,
      totalSteps: totalSteps ?? this.totalSteps,
      completedSteps: completedSteps ?? this.completedSteps,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoadingData &&
          other.progressCounter == progressCounter &&
          other.totalSteps == totalSteps &&
          other.completedSteps == completedSteps &&
          other.isLoading == isLoading;

  @override
  int get hashCode =>
      Object.hash(progressCounter, totalSteps, completedSteps, isLoading);
}
