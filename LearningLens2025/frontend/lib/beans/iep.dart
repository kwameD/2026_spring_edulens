class IEP {
  int id;
  int courseId;
  int iepId;
  int userId;

  String gradeLevel;
  String disability;
  String courseName;
  String iepSummary;
  String iep;

  IEP(
    this.id,
    this.courseId,
    this.iepId,
    this.userId,
    this.gradeLevel,
    this.disability,
    this.courseName,
    this.iepSummary,
    this.iep,
  );

  IEP.empty()
      : id = 0,
        courseId = 0,
        iepId = 0,
        userId = 0,
        gradeLevel = '',
        disability = '',
        courseName = '',
        iepSummary = '',
        iep = '';
  // final int overrideId;

  // IEP({required this.overrideId});

  // IEP.empty() : overrideId = 0;

  // @override
  // IEP fromMoodleJson(Map<String, dynamic> json) {
  //   return IEP(
  //     overrideId: json['overrideid'] as int,
  //   );
  // }

  // @override
  // IEP fromGoogleJson(Map<String, dynamic> json) {
  //   throw UnimplementedError();
  // }

  // @override
  // String toString() {
  //   return "QuizOverride(overrideId: $overrideId)";
  // }
}
