import 'package:flutter/material.dart';
import '../constants.dart';

class PayModal extends StatelessWidget {
  final String entryText;
  final VoidCallback onJoin;
  PayModal({required this.entryText, required this.onJoin});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Color(0xFF14161b),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: EdgeInsets.all(20),
        width: 300,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.monetization_on, size: 36, color: Colors.amber),
          SizedBox(height: 8),
          Text('Pay Entry Fee',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          SizedBox(height: 8),
          Text(entryText, style: TextStyle(color: Colors.grey[400])),
          SizedBox(height: 16),
          ElevatedButton(
              onPressed: onJoin,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.neonPurple,
                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14))),
              child: SizedBox(
                  width: double.infinity,
                  child: Center(child: Text('PAY & JOIN'))))
        ]),
      ),
    );
  }
}
