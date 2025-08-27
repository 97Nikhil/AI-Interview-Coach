import 'package:flutter/material.dart';

class UiHelper{
  static Widget CustomImage({
    required String img,
    double? height,
    double? width,
  }) {
    return Image.asset(
      "assets/images/$img",
      height: height,
      width: width,
      fit: BoxFit.contain, // Optional: makes sure it scales properly
    );
  }

  static CustomText(
      {required String text,
        required Color color,
        required FontWeight fontweight,
        String? fontfamily,
        required double fontsize}) {
    return Text(
      text,
      style: TextStyle(
          fontSize: fontsize,
          fontFamily: fontfamily ?? "regular",
          fontWeight: fontweight,
          color: color),
    );
  }

}