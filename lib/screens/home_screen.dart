import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/time_entry_provider.dart';
import 'add_time_entry_screen.dart';
import 'project_management_screen.dart';
import 'task_management_screen.dart';
import '../models/project.dart';
import '../models/time_entry.dart';

enum TimeEntryViewMode { all, groupedByProject }

class _HomeScreenState extends State<HomeScreen> {
  TimeEntryViewMode _viewMode = TimeEntryViewMode.all;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Time Entries')),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              child: Text('Menu'),
              decoration: BoxDecoration(color: Colors.blue),
            ),
            ListTile(
              title: Text('Projects'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProjectManagementScreen(),
                  ),
                );
              },
            ),
            ListTile(
              title: Text('Tasks'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TaskManagementScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 8.0,
              horizontal: 16.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _viewMode = TimeEntryViewMode.all;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _viewMode == TimeEntryViewMode.all
                        ? Theme.of(context).colorScheme.primary
                        : null,
                    foregroundColor: _viewMode == TimeEntryViewMode.all
                        ? Colors.white
                        : Colors.black,
                  ),
                  child: Text('All Entries'),
                ),
                SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _viewMode = TimeEntryViewMode.groupedByProject;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _viewMode == TimeEntryViewMode.groupedByProject
                        ? Theme.of(context).colorScheme.primary
                        : null,
                    foregroundColor:
                        _viewMode == TimeEntryViewMode.groupedByProject
                        ? Colors.white
                        : Colors.black,
                  ),
                  child: Text('Group by Projects'),
                ),
              ],
            ),
          ),
          Expanded(
            child: Consumer<TimeEntryProvider>(
              builder: (context, provider, child) {
                if (_viewMode == TimeEntryViewMode.groupedByProject) {
                  final Map<String, List<TimeEntry>> grouped = {};
                  for (final entry in provider.entries) {
                    grouped.putIfAbsent(entry.projectId, () => []).add(entry);
                  }
                  return ListView(
                    children: grouped.entries.map((e) {
                      final project = provider.projects.firstWhere(
                        (p) => p.id == e.key,
                        orElse: () => Project(id: e.key, name: e.key),
                      );
                      return ExpansionTile(
                        title: Text(project.name),
                        children: e.value
                            .map(
                              (entry) => ListTile(
                                title: Text('${entry.totalTime} hours'),
                                subtitle: Text(
                                  '${entry.date.toString()} - Notes: ${entry.notes}',
                                ),
                                trailing: IconButton(
                                  icon: Icon(Icons.delete),
                                  onPressed: () {
                                    provider.deleteTimeEntry(entry.id);
                                  },
                                ),
                              ),
                            )
                            .toList(),
                      );
                    }).toList(),
                  );
                } else {
                  return ListView.builder(
                    itemCount: provider.entries.length,
                    itemBuilder: (context, index) {
                      final entry = provider.entries[index];
                      final project = provider.projects.firstWhere(
                        (p) => p.id == entry.projectId,
                        orElse: () =>
                            Project(id: entry.projectId, name: entry.projectId),
                      );
                      return ListTile(
                        title: Text(
                          '${project.name} - ${entry.totalTime} hours',
                        ),
                        subtitle: Text(
                          '${entry.date.toString()} - Notes: ${entry.notes}',
                        ),
                        trailing: IconButton(
                          icon: Icon(Icons.delete),
                          onPressed: () {
                            provider.deleteTimeEntry(entry.id);
                          },
                        ),
                      );
                    },
                  );
                }
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigate to the screen to add a new time entry
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddTimeEntryScreen()),
          );
        },
        child: Icon(Icons.add),
        tooltip: 'Add Time Entry',
      ),
    );
  }
}

// Replace the HomeScreen class definition with a StatefulWidget
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  _HomeScreenState createState() => _HomeScreenState();
}
