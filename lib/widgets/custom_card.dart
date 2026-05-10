import 'package:flutter/material.dart';

class CustomCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String status;

  const CustomCard({
    required this.title,
    required this.subtitle,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final isDone = status == "Dikembalikan";

    return Container(
      margin: EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDone
              ? [Colors.green, Colors.teal]
              : [Colors.orange, Colors.deepOrange],
        ),
        borderRadius: BorderRadius.circular(15),
      ),
      child: ListTile(
        leading: Icon(Icons.book, color: Colors.white),
        title: Text(title, style: TextStyle(color: Colors.white)),
        subtitle: Text(subtitle, style: TextStyle(color: Colors.white70)),
        trailing: Text(status, style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
