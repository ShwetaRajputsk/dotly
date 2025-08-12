import 'package:flutter/material.dart';
import 'home_page.dart';
import 'account.dart';

class CustomBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  CustomBottomNavigationBar({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Floating Purple + Button
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Color(0xFF8D1CDF), // Purple color
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0xFF8D1CDF).withOpacity(0.4),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(32),
                onTap: () => onTap(2), // Add/Plus functionality
                child: Icon(
                  Icons.add,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}