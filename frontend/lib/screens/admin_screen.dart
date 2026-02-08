import 'package:flutter/material.dart';
import '../services/profile_service.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profileService = ProfileService();

    return Scaffold(
      appBar: AppBar(title: const Text('Admin Dashboard')),
      body: FutureBuilder(
        future: profileService.fetchAdminDashboard(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final data = snapshot.data as Map<String, dynamic>;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data['message']),
                Text("Total Users: ${data['total_users']}"),
                Text("Total Clothes: ${data['total_clothes']}"),
              ],
            ),
          );
        },
      ),
    );
  }
}
