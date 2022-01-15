import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:line_icons/line_icons.dart';
import 'package:news_admin/blocs/admin_bloc.dart';
import 'package:news_admin/models/rss_feed.dart';
import 'package:news_admin/utils/dialog.dart';
import 'package:news_admin/utils/empty.dart';
import 'package:news_admin/utils/styles.dart';
import 'package:news_admin/utils/toast.dart';
import 'package:provider/provider.dart';

class RSSFEEDS extends StatefulWidget {
  const RSSFEEDS({Key? key}) : super(key: key);

  @override
  _RSSFEEDSState createState() => _RSSFEEDSState();
}

class _RSSFEEDSState extends State<RSSFEEDS> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  ScrollController? controller;
  DocumentSnapshot? _lastVisible;
  late bool _isLoading;
  List<DocumentSnapshot> _snap = [];
  List<RSSFEED> _data = [];
  final scaffoldKey = GlobalKey<ScaffoldState>();
  final String collectionName = 'rss_feeds';
  bool? _hasData;

  @override
  void initState() {
    controller = new ScrollController()..addListener(_scrollListener);
    super.initState();
    _isLoading = true;
    _getData();
  }

  Future<Null> _getData() async {
    QuerySnapshot data;
    if (_lastVisible == null)
      data = await firestore.collection(collectionName).orderBy('timestamp', descending: true).limit(10).get();
    else
      data = await firestore.collection(collectionName).orderBy('timestamp', descending: true).startAfter([_lastVisible!['timestamp']]).limit(10).get();

    if (data.docs.length > 0) {
      _lastVisible = data.docs[data.docs.length - 1];
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasData = true;
          _snap.addAll(data.docs);
          _data = _snap.map((e) => RSSFEED.fromFirestore(e)).toList();
        });
      }
    } else {
      if (_lastVisible == null) {
        setState(() {
          _isLoading = false;
          _hasData = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _hasData = true;
        });
        openToast(context, 'No more content available');
      }
    }
    return null;
  }

  @override
  void dispose() {
    controller!.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (!_isLoading) {
      if (controller!.position.pixels == controller!.position.maxScrollExtent) {
        setState(() => _isLoading = true);
        _getData();
      }
    }
  }

  refreshData() async {
    setState(() {
      _data.clear();
      _snap.clear();
      _lastVisible = null;
    });
    await _getData();
  }

  handleDelete(timestamp1) {
    final AdminBloc ab = Provider.of<AdminBloc>(context, listen: false);
    showDialog(
        context: context,
        builder: (BuildContext context) {
          return SimpleDialog(
            contentPadding: EdgeInsets.all(50),
            elevation: 0,
            children: <Widget>[
              Text('Delete?', style: TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.w900)),
              SizedBox(
                height: 10,
              ),
              Text('Want to delete this item from the database?', style: TextStyle(color: Colors.grey[900], fontSize: 16, fontWeight: FontWeight.w700)),
              SizedBox(
                height: 30,
              ),
              Center(
                  child: Row(
                children: <Widget>[
                  TextButton(
                    style: buttonStyle(Colors.redAccent),
                    child: Text(
                      'Yes',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    onPressed: () async {
                      if (ab.userType == 'tester') {
                        Navigator.pop(context);
                        openDialog(context, 'You are a Tester', 'Only admin can delete contents');
                      } else {
                        await ab.deleteContent(timestamp1, collectionName).then((value) => ab.getRSSFEEDS()).then((value) => openToast(context, 'Deleted Successfully'));
                        refreshData();
                        Navigator.pop(context);
                      }
                    },
                  ),
                  SizedBox(width: 10),
                  TextButton(
                    style: buttonStyle(Colors.deepPurpleAccent),
                    child: Text(
                      'No',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ))
            ],
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.05,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'RSS FEEDS',
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
            ),
            Container(
              width: 300,
              height: 40,
              padding: EdgeInsets.only(left: 15, right: 15),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(30),
              ),
              child: TextButton.icon(
                  onPressed: () {
                    openAddDialog();
                  },
                  icon: Icon(LineIcons.list),
                  label: Text('Add RSS FEED')),
            ),
          ],
        ),
        Container(
          margin: EdgeInsets.only(top: 5, bottom: 10),
          height: 3,
          width: 50,
          decoration: BoxDecoration(color: Colors.indigoAccent, borderRadius: BorderRadius.circular(15)),
        ),
        SizedBox(
          height: 30,
        ),
        Expanded(
          child: _hasData == false
              ? emptyPage(Icons.content_paste, 'No RSS FEED found.\nUpload RSS FEED first!')
              : RefreshIndicator(
                  child: ListView.separated(
                    padding: EdgeInsets.only(top: 30, bottom: 20),
                    controller: controller,
                    physics: AlwaysScrollableScrollPhysics(),
                    itemCount: _data.length + 1,
                    separatorBuilder: (BuildContext context, int index) => SizedBox(
                      height: 10,
                    ),
                    itemBuilder: (_, int index) {
                      if (index < _data.length) {
                        return dataList(_data[index]);
                      }
                      return Center(
                        child: new Opacity(
                          opacity: _isLoading ? 1.0 : 0.0,
                          child: new SizedBox(width: 32.0, height: 32.0, child: new CircularProgressIndicator()),
                        ),
                      );
                    },
                  ),
                  onRefresh: () async {
                    await refreshData();
                  },
                ),
        ),
      ],
    );
  }

  Widget dataList(RSSFEED d) {
    return Container(
      height: 130,
      padding: EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 10),
      decoration: BoxDecoration(
        // color: Colors.grey[200],
        color: Colors.primaries[Random().nextInt(Colors.primaries.length)],
        borderRadius: BorderRadius.circular(10),
        // image: DecorationImage(
        //   image: CachedNetworkImageProvider(d.url!),
        //   fit: BoxFit.cover,
        // ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Spacer(),
          Text(
            d.name!,
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: Colors.white),
          ),
          Spacer(),
          InkWell(
            child: Container(height: 35, width: 35, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(10)), child: Icon(Icons.edit, size: 16, color: Colors.grey[800])),
            onTap: () => openEditDialog(d.name!, d.url!, d.timestamp!, d.category!, d.contentType!),
          ),
          SizedBox(
            width: 10,
          ),
          InkWell(
              child: Container(height: 35, width: 35, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(10)), child: Icon(Icons.delete, size: 16, color: Colors.grey[800])),
              onTap: () {
                handleDelete(d.timestamp);
              }),
        ],
      ),
    );
  }

  // add/upload Category

  var formKey = GlobalKey<FormState>();
  var nameCtrl = TextEditingController();
  var urlCtrl = TextEditingController();
  var categoryCtrl = TextEditingController();
  var typeCtrl = TextEditingController();
  String? timestamp;

  Future addRSSFEED() async {
    final DocumentReference ref = firestore.collection(collectionName).doc(timestamp);
    await ref.set({
      'name': nameCtrl.text,
      'url': urlCtrl.text,
      'timestamp': timestamp,
      'category': categoryCtrl.text,
      'contentType': typeCtrl.text,
    });
  }

  handleAddRSSFEED() async {
    final AdminBloc ab = Provider.of<AdminBloc>(context, listen: false);
    if (formKey.currentState!.validate()) {
      formKey.currentState!.save();
      if (ab.userType == 'tester') {
        Navigator.pop(context);
        openDialog(context, 'You are a Tester', 'Only admin can add contents');
      } else {
        await getTimestamp().then((value) => addRSSFEED()).then((value) => openToast(context, 'Added Successfully')).then((value) => ab.getRSSFEEDS());
        refreshData();
        Navigator.pop(context);
      }
    }
  }

  clearTextfields() {
    nameCtrl.clear();
    urlCtrl.clear();
  }

  Future getTimestamp() async {
    DateTime now = DateTime.now();
    String _timestamp = DateFormat('yyyyMMddHHmmss').format(now);
    setState(() {
      timestamp = _timestamp;
    });
  }

  openAddDialog() {
    showDialog(
        context: context,
        builder: (context) {
          return SimpleDialog(
            contentPadding: EdgeInsets.all(100),
            children: <Widget>[
              Text(
                'Add RSS FEED to Database',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
              ),
              SizedBox(
                height: 50,
              ),
              Form(
                  key: formKey,
                  child: Column(
                    children: <Widget>[
                      TextFormField(
                        decoration: inputDecoration('Enter RSS FEED Name', 'RSS FEED Name', nameCtrl),
                        controller: nameCtrl,
                        validator: (value) {
                          if (value!.isEmpty) return 'RSS FEED Name is empty';
                          return null;
                        },
                      ),
                      SizedBox(
                        height: 20,
                      ),
                      TextFormField(
                        decoration: inputDecoration('Enter RSS FEED Url', 'RSS FEED Url', urlCtrl),
                        controller: urlCtrl,
                        validator: (value) {
                          if (value!.isEmpty) return 'RSS FEED url is empty';
                          return null;
                        },
                      ),
                      SizedBox(
                        height: 20,
                      ),
                      TextFormField(
                        decoration: inputDecoration('Enter Category', 'RSS FEED Category', categoryCtrl),
                        controller: categoryCtrl,
                        validator: (value) {
                          if (value!.isEmpty) return 'RSS FEED category is empty';
                          return null;
                        },
                      ),
                      SizedBox(
                        height: 20,
                      ),
                      TextFormField(
                        decoration: inputDecoration('Enter RSS FEED Content type', 'RSS FEED Content type(image/video)', typeCtrl),
                        controller: typeCtrl,
                        validator: (value) {
                          if (value!.isEmpty) return 'RSS FEED Content type is empty';
                          return null;
                        },
                      ),
                      SizedBox(
                        height: 50,
                      ),
                      Center(
                          child: Row(
                        children: <Widget>[
                          TextButton(
                            style: buttonStyle(Colors.purpleAccent),
                            child: Text(
                              'Add RSS FEED',
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            onPressed: () async {
                              await handleAddRSSFEED();
                              clearTextfields();
                            },
                          ),
                          SizedBox(width: 10),
                          TextButton(
                            style: buttonStyle(Colors.redAccent),
                            child: Text(
                              'Cancel',
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ))
                    ],
                  ))
            ],
          );
        });
  }

  //update/edit category

  var nameCtrl1 = TextEditingController();
  var urlCtrl1 = TextEditingController();
  var categoryCtrl1 = TextEditingController();
  var typeCtrl1 = TextEditingController();
  var formKey1 = GlobalKey<FormState>();

  Future _updateRSSFEED(String categoryTimestamp) async {
    final DocumentReference ref = firestore.collection(collectionName).doc(categoryTimestamp);
    await ref.update({
      'name': nameCtrl1.text,
      'url': urlCtrl1.text,
      'category': categoryCtrl1.text,
      'contentType': typeCtrl1.text,
    });
  }

  Future _handleUpdateRSSFEED(String rssfeedTimestamp) async {
    final AdminBloc ab = Provider.of<AdminBloc>(context, listen: false);
    if (formKey1.currentState!.validate()) {
      formKey1.currentState!.save();
      if (ab.userType == 'tester') {
        Navigator.pop(context);
        openDialog(context, 'You are a Tester', 'Only admin can add contents');
      } else {
        await _updateRSSFEED(rssfeedTimestamp).then((value) => openToast(context, 'Updated Successfully')).then((value) => ab.getRSSFEEDS());
        refreshData();
        Navigator.pop(context);
      }
    }
  }

  void openEditDialog(String oldName, String oldUrl, String rssfeedTimestamp, String oldCategory, String oldtype) {
    showDialog(
        context: context,
        builder: (context) {
          nameCtrl1.text = oldName;
          urlCtrl1.text = oldUrl;
          categoryCtrl1.text = oldCategory;
          typeCtrl1.text = oldtype;

          return SimpleDialog(
            contentPadding: EdgeInsets.all(100),
            children: <Widget>[
              Text(
                'Edit/Update Category to Database',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
              ),
              SizedBox(
                height: 50,
              ),
              Form(
                  key: formKey1,
                  child: Column(
                    children: <Widget>[
                      TextFormField(
                        decoration: inputDecoration('Enter RSS FEED Name', 'RSS FEED Name', nameCtrl1),
                        controller: nameCtrl1,
                        validator: (value) {
                          if (value!.isEmpty) return 'RSS FEED Name is empty';
                          return null;
                        },
                      ),
                      SizedBox(
                        height: 20,
                      ),
                      TextFormField(
                        decoration: inputDecoration('Enter RSS FEED Url', 'Url', urlCtrl1),
                        controller: urlCtrl1,
                        validator: (value) {
                          if (value!.isEmpty) return 'RSS FEED url is empty';
                          return null;
                        },
                      ),
                      SizedBox(
                        height: 20,
                      ),
                      TextFormField(
                        decoration: inputDecoration('Enter Category', 'RSS FEED Category', categoryCtrl1),
                        controller: categoryCtrl1,
                        validator: (value) {
                          if (value!.isEmpty) return 'RSS FEED category is empty';
                          return null;
                        },
                      ),
                      SizedBox(
                        height: 20,
                      ),
                      TextFormField(
                        decoration: inputDecoration('Enter RSS FEED Content type', 'RSS FEED Content type(image/video)', typeCtrl1),
                        controller: typeCtrl1,
                        validator: (value) {
                          if (value!.isEmpty) return 'RSS FEED Content type is empty';
                          return null;
                        },
                      ),
                      SizedBox(
                        height: 50,
                      ),
                      Center(
                          child: Row(
                        children: <Widget>[
                          TextButton(
                            style: buttonStyle(Colors.purpleAccent),
                            child: Text(
                              'Update RSS FEED',
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            onPressed: () async {
                              _handleUpdateRSSFEED(rssfeedTimestamp);
                            },
                          ),
                          SizedBox(width: 10),
                          TextButton(
                            style: buttonStyle(Colors.redAccent),
                            child: Text(
                              'Cancel',
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ))
                    ],
                  ))
            ],
          );
        });
  }
}
