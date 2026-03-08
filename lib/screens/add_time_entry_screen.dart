import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/time_entry.dart';
import '../models/project.dart';
import '../models/task.dart';
import '../providers/time_entry_provider.dart';

class AddTimeEntryScreen extends StatefulWidget {
  @override
  _AddTimeEntryScreenState createState() => _AddTimeEntryScreenState();
}

class _AddTimeEntryScreenState extends State<AddTimeEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  Project? selectedProject;
  Task? selectedTask;
  double totalTime = 0.0;
  DateTime date = DateTime.now();
  String notes = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Add Time Entry')),
      body: Consumer<TimeEntryProvider>(
        builder: (context, provider, child) => Form(
          key: _formKey,
          child: Column(
            children: <Widget>[
              DropdownButtonFormField<Project>(
                value: selectedProject,
                hint: const Text('Select a project'),
                onChanged: (Project? newValue) {
                  setState(() {
                    selectedProject = newValue;
                  });
                },
                decoration: const InputDecoration(labelText: 'Project'),
                items: provider.projects.map<DropdownMenuItem<Project>>((
                  project,
                ) {
                  return DropdownMenuItem<Project>(
                    value: project,
                    child: Text(project.name),
                  );
                }).toList(),
                validator: (value) {
                  if (value == null) {
                    return 'Please select a project';
                  }
                  return null;
                },
              ),
              DropdownButtonFormField<Task>(
                value: selectedTask,
                hint: const Text('Select a task'),
                onChanged: (Task? newValue) {
                  setState(() {
                    selectedTask = newValue;
                  });
                },
                decoration: const InputDecoration(labelText: 'Task'),
                items: provider.tasks.map<DropdownMenuItem<Task>>((task) {
                  return DropdownMenuItem<Task>(
                    value: task,
                    child: Text(task.name),
                  );
                }).toList(),
                validator: (value) {
                  if (value == null) {
                    return 'Please select a task';
                  }
                  return null;
                },
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'Total Time (hours)'),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter total time';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
                onSaved: (value) => totalTime = double.parse(value!),
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'Notes'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter some notes';
                  }
                  return null;
                },
                onSaved: (value) => notes = value!,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Date: 	${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: date,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null && picked != date) {
                          setState(() {
                            date = picked;
                          });
                        }
                      },
                      child: Text('Select Date'),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    _formKey.currentState!.save();
                    Provider.of<TimeEntryProvider>(
                      context,
                      listen: false,
                    ).addTimeEntry(
                      TimeEntry(
                        id: DateTime.now().toString(), // Simple ID generation
                        projectId: selectedProject!.id,
                        taskId: selectedTask!.id,
                        totalTime: totalTime,
                        date: date,
                        notes: notes,
                      ),
                    );
                    Navigator.pop(context);
                  }
                },
                child: Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
