class UserModel {
  final String id;
  final String? displayName;
  final String? email;
  final String? photoUrl;
  final String provider;

  UserModel({
    required this.id,
    required this.provider,
    this.displayName,
    this.email,
    this.photoUrl,
  });
}
