import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/time_entry_provider.dart';
import '../dialogs/add_task_dialog.dart';
import '../models/task.dart';

class TaskManagementScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Manage Tasks')),
      body: Consumer<TimeEntryProvider>(
        builder: (context, provider, child) {
          final tasks = provider?.tasks ?? [];
          return ListView.builder(
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
              return ListTile(
                title: Text(task.name),
                trailing: IconButton(
                  icon: Icon(Icons.delete),
                  onPressed: () {
                    provider?.deleteTask(task.id);
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
            builder: (context) => AddTaskDialog(
              onAddTask: (task) {
                Provider.of<TimeEntryProvider>(
                  context,
                  listen: false,
                ).addTask(task);
              },
            ),
          );
        },
        child: Icon(Icons.add),
        tooltip: 'Add Task',
      ),
    );
  }
}
