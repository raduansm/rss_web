import 'package:cloud_firestore/cloud_firestore.dart';

class RSSFEED {
  String? name;
  String? url;
  String? timestamp;
  String? category;
  String? contentType;

  RSSFEED({this.name, this.url, this.timestamp, this.category, this.contentType});

  factory RSSFEED.fromFirestore(DocumentSnapshot snapshot) {
    Map d = snapshot.data() as Map<dynamic, dynamic>;
    return RSSFEED(
      name: d['name'],
      url: d['url'],
      timestamp: d['timestamp'],
      category: d['category'],
      contentType: d['contentType'],
    );
  }
}
