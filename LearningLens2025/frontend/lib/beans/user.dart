class User {
  int id;
  String firstname;
  String lastname;
  String email;
  String gradeLevel;
  String disability;

  User({
    required this.id,
    required this.firstname,
    required this.lastname,
    required this.email,
    required this.gradeLevel,
    required this.disability,
  });

  // empty constructor
  User.empty()
      : id = 0,
        firstname = '',
        lastname = '',
        email = '',
        gradeLevel = '',
        disability = '';

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
        id: json['id'],
        firstname: json['firstname'],
        lastname: json['lastname'],
        email: json['email'],
        gradeLevel: json['gradeLevel'],
        disability: json['disability']);
  }
}
