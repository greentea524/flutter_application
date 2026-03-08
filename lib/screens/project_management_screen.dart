import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/time_entry_provider.dart';
import '../dialogs/add_project_dialog.dart';
import '../models/project.dart';

class ProjectManagementScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Manage Projects')),
      body: Consumer<TimeEntryProvider>(
        builder: (context, provider, child) {
          final projects = provider?.projects ?? [];
          return ListView.builder(
            itemCount: projects.length,
            itemBuilder: (context, index) {
              final project = projects[index];
              return ListTile(
                title: Text(project.name),
                trailing: IconButton(
                  icon: Icon(Icons.delete),
                  onPressed: () {
                    provider?.deleteProject(project.id);
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => AddProjectDialog(
              onAddProject: (project) {
                Provider.of<TimeEntryProvider>(
                  context,
                  listen: false,
                ).addProject(project);
              },
            ),
          );
        },
        child: Icon(Icons.add),
        tooltip: 'Add Project',
      ),
    );
  }
}
