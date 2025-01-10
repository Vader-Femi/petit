import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Petit"),
      ),
      body: Padding(
        padding: EdgeInsets.fromLTRB(10, 0, 10, 15),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Spacer(),
            Text(
              "We'll continue from here",
              style: TextStyle(fontSize: 18),
            ),
            Spacer(),
            ElevatedButton(
              onPressed: () {},
              child: const Text('Pick a File'),
            ),
          ],
        ),
      ),
    );
  }
}
