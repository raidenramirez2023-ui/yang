import 'package:flutter/material.dart';

class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Admin Registration")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(decoration: InputDecoration(labelText: "Full Name")),
            TextField(decoration: InputDecoration(labelText: "Email")),
            TextField(
              decoration: InputDecoration(labelText: "Password"),
              obscureText: true,
            ),

            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("Register Admin"),
            )
          ],
        ),
      ),
    );
  }
}
