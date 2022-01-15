import 'package:cloud_firestore/cloud_firestore.dart';

class RSSFEED {
  String? name;
  String? thumbnailUrl;
  String? timestamp;

  RSSFEED({this.name, this.thumbnailUrl, this.timestamp});

  factory RSSFEED.fromFirestore(DocumentSnapshot snapshot) {
    Map d = snapshot.data() as Map<dynamic, dynamic>;
    return RSSFEED(
      name: d['name'],
      thumbnailUrl: d['thumbnail'],
      timestamp: d['timestamp'],
    );
  }
}
