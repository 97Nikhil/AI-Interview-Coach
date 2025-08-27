import 'package:flutter/material.dart';

import '../../widgets/uihelper.dart';
import '../home/homescreen.dart';
import '../interview/interviewConfigScreen.dart';
import '../resume/resumeScreen.dart';
import '../user/userScreen.dart';

class BottomNavScreen extends StatefulWidget {
  @override
  State<BottomNavScreen> createState() => _BottomNavScreenState();
}

class _BottomNavScreenState extends State<BottomNavScreen> {
  int currentIndex = 0;
  List<Widget> pages = [
    HomeScreen(),
    InterviewScreen(),
    ResumeScreen(),
    UserScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: pages,
      ),
      bottomNavigationBar: Container(
        height: 60, // Increased height to accommodate labels
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconSize: 26, // Slightly reduced icon size to make room for labels
          selectedFontSize: 12,
          unselectedFontSize: 11,
          selectedItemColor: Colors.blue, // Color for selected item
          unselectedItemColor: Colors.black, // Color for unselected items
          items: [
            BottomNavigationBarItem(
              icon: Image.asset("assets/images/home2.png", height: 26),
              label: "Home",
            ),
            BottomNavigationBarItem(
              icon: UiHelper.CustomImage(img: "job2.png", height: 26),
              label: "Interview",
            ),
            BottomNavigationBarItem(
              icon: UiHelper.CustomImage(img: "resume2.png", height: 26),
              label: "Resume",
            ),
            BottomNavigationBarItem(
              icon: UiHelper.CustomImage(img: "user2.png", height: 26),
              label: "User",
            ),
          ],
          type: BottomNavigationBarType.fixed,
          currentIndex: currentIndex,
          onTap: (index) {
            setState(() {
              currentIndex = index;
            });
          },
        ),
      ),
    );
  }
}