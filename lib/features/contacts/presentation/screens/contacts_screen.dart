import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacts'),
        actions: [
          IconButton(icon: const Icon(Icons.person_add), onPressed: () {}),
        ],
      ),
      body: ListView.builder(
        itemCount: 0,
        itemBuilder: (context, index) => const SizedBox.shrink(),
      ),
    );
  }
}
