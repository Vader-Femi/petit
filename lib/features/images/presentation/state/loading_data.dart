/// Progress of an image job. Plain immutable value class.
class LoadingData {
  final int? progressCounter;
  final int? totalSteps;
  final int? completedSteps;
  final bool isLoading;

  /// Time left for the job, once it can be told.
  final Duration? eta;

  const LoadingData({
    this.progressCounter,
    this.totalSteps,
    this.completedSteps,
    required this.isLoading,
    this.eta,
  });

  LoadingData copyWith(
      {int? progressCounter,
      int? totalSteps,
      int? completedSteps,
      bool? isLoading,
      Duration? eta}) {
    return LoadingData(
      progressCounter: progressCounter ?? this.progressCounter,
      totalSteps: totalSteps ?? this.totalSteps,
      completedSteps: completedSteps ?? this.completedSteps,
      isLoading: isLoading ?? this.isLoading,
      eta: eta ?? this.eta,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoadingData &&
          other.progressCounter == progressCounter &&
          other.totalSteps == totalSteps &&
          other.completedSteps == completedSteps &&
          other.isLoading == isLoading &&
          other.eta == eta;

  @override
  int get hashCode =>
      Object.hash(progressCounter, totalSteps, completedSteps, isLoading, eta);
}
