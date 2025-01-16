import 'package:flutter_super/flutter_super.dart';

class LoadingData with SuperModel {
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

  @override
  List<Object?> get props => [progressCounter, totalSteps, completedSteps, isLoading];

}
