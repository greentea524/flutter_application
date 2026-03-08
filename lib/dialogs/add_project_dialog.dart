import 'package:flutter/material.dart';
import '../models/project.dart';

class AddProjectDialog extends StatefulWidget {
  final void Function(Project) onAddProject;

  const AddProjectDialog({super.key, required this.onAddProject});

  @override
  _AddProjectDialogState createState() => _AddProjectDialogState();
}

class _AddProjectDialogState extends State<AddProjectDialog> {
  final _formKey = GlobalKey<FormState>();
  String name = '';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Project'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          decoration: const InputDecoration(labelText: 'Project Name'),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a project name';
            }
            return null;
          },
          onSaved: (value) => name = value!,
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              _formKey.currentState!.save();
              final project = Project(
                id: DateTime.now().toString(),
                name: name,
              );
              widget.onAddProject(project);
              Navigator.of(context).pop();
            }
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
