class GoogleUser {
  
  final String? displayName;
  final String? email;
  final String? photoURL;
  final String? uid;

  GoogleUser(this.displayName,this.email,this.photoURL,this.uid);

  toObject(){
    return {
      "displayname":displayName,
      "email":email,
      "photoURL":photoURL,
      "uid":uid
    };
  }
}