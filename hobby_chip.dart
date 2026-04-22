import 'package:flutter/material.dart';

class HobbyChip extends StatelessWidget {
  final String hobby;
  final VoidCallback? onTap;
  final bool isSelected;
  
  const HobbyChip({
    super.key,
    required this.hobby,
    this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Colors.orange, Colors.deepOrange],
                )
              : null,
          color: isSelected ? null : Colors.orange.shade50,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? Colors.orange : Colors.orange.shade200,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          hobby,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.orange.shade800,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}