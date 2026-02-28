import 'package:learninglens_app/beans/learning_lens_interface.dart';

class IEP implements LearningLensInterface {
  final int overrideId;

  IEP({required this.overrideId});

  IEP.empty() : overrideId = 0;

  @override
  IEP fromMoodleJson(Map<String, dynamic> json) {
    return IEP(
      overrideId: json['overrideid'] as int,
    );
  }

  @override
  IEP fromGoogleJson(Map<String, dynamic> json) {
    throw UnimplementedError();
  }

  @override
  String toString() {
    return "QuizOverride(overrideId: $overrideId)";
  }
}
