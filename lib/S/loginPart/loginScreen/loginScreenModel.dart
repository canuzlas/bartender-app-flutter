class GoogleUser {
  final String? displayName;
  final String? email;
  final String? photoURL;
  final String? uid;

  GoogleUser(this.displayName, this.email, this.photoURL, this.uid);

  factory GoogleUser.fromMap(Map<String, dynamic> map) {
    return GoogleUser(
      map['displayname'],
      map['email'],
      map['photoURL'],
      map['uid'],
    );
  }

  toObject() {
    return {
      "displayname": displayName,
      "email": email,
      "photoURL": photoURL,
      "uid": uid
    };
  }

  @override
  String toString() {
    return 'GoogleUser(displayName: $displayName, email: $email, photoURL: $photoURL, uid: $uid)';
  }
}
