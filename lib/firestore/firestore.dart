import "package:cloud_firestore/cloud_firestore.dart";
import "package:flutter/material.dart";


class Fbfs {

  FirebaseFirestore fbs = FirebaseFirestore.instance;

  // get data by document ıd
  Future<Map<String, dynamic>?> getDataByDocumentId(col,doc)async{

    var result = await fbs.collection(col).doc(doc).get();
    
    return result.data();
  }

  //set data with spesific document id
  setDataWithDocumentId(col,doc,data)async{
    try {

       await fbs.collection(col).doc(doc).set(data);
       return true;

    } catch (e) {
      
      print(e);
      return false;

    }
  }
}

