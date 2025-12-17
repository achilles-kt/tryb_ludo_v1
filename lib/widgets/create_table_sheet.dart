import 'package:flutter/material.dart';
import '../constants.dart';

class CreateTableOptionsSheet extends StatelessWidget {
  final Function(String mode) onSelect;

  const CreateTableOptionsSheet({Key? key, required this.onSelect})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                  )),
              SizedBox(
                width: 8,
              ),
              Text('Create Table',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _optCard(
                  icon: Icons.person,
                  title: 'Two Players',
                  sub: '1v1 Match',
                  color: AppColors.neonBlue,
                  onTap: () => onSelect('create_2p'),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _optCard(
                  icon: Icons.group,
                  title: 'Team Up',
                  sub: 'Squad 2v2',
                  color: AppColors.neonPurple,
                  onTap: () {
                    // Placeholder or Implement later
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text("Coming Soon!")));
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _optCard({
    required IconData icon,
    required String title,
    required String sub,
    required Color color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: color.withOpacity(0.5)),
              ),
              child: Icon(icon, color: color),
            ),
            SizedBox(height: 8),
            Text(title, style: TextStyle(fontWeight: FontWeight.w700)),
            SizedBox(height: 4),
            Text(sub, style: TextStyle(color: Colors.grey[400], fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
