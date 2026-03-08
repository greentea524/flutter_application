import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:localstorage/localstorage.dart';

import '../models/time_entry.dart';
import '../models/task.dart';
import '../models/project.dart';

class TimeEntryProvider with ChangeNotifier {
  // we rely on the package's global singleton rather than constructing our own
  static const String _storageKey = 'time_entries';
  static const String _tasksStorageKey = 'tasks';
  static const String _projectsStorageKey = 'projects';

  List<TimeEntry> _entries = [];
  List<Task> _tasks = [];
  List<Project> _projects = [];

  List<TimeEntry> get entries => _entries;
  List<Task> get tasks => _tasks;
  List<Project> get projects => _projects;

  TimeEntryProvider() {
    _loadEntries();
    _loadTasks();
    _loadProjects();
  }

  Future<void> _loadEntries() async {
    // localStorage.getItem is declared to return String? which prevents
    // type-narrowing to List; treat it as dynamic so we can check its runtime
    // type below.
    final dynamic data = localStorage.getItem(_storageKey);
    List<dynamic>? rawList;

    if (data is List) {
      rawList = data;
    } else if (data is String) {
      // some platforms store JSON as a string
      try {
        rawList = List<dynamic>.from(jsonDecode(data) as List);
      } catch (_) {
        rawList = null;
      }
    }

    if (rawList != null) {
      _entries = rawList
          .map((e) => TimeEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      notifyListeners();
    }
  }

  Future<void> _loadTasks() async {
    final dynamic data = localStorage.getItem(_tasksStorageKey);
    List<dynamic>? rawList;

    if (data is List) {
      rawList = data;
    } else if (data is String) {
      try {
        rawList = List<dynamic>.from(jsonDecode(data) as List);
      } catch (_) {
        rawList = null;
      }
    }

    if (rawList != null) {
      _tasks = rawList
          .map((e) => Task.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      notifyListeners();
    }
  }

  Future<void> _loadProjects() async {
    final dynamic data = localStorage.getItem(_projectsStorageKey);
    List<dynamic>? rawList;

    if (data is List) {
      rawList = data;
    } else if (data is String) {
      try {
        rawList = List<dynamic>.from(jsonDecode(data) as List);
      } catch (_) {
        rawList = null;
      }
    }

    if (rawList != null) {
      _projects = rawList
          .map((e) => Project.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      notifyListeners();
    }
  }

  Future<void> _saveEntries() async {
    final jsonList = _entries.map((e) => e.toJson()).toList();
    // localStorage expects a String value, so encode as JSON
    localStorage.setItem(_storageKey, jsonEncode(jsonList));
  }

  Future<void> _saveTasks() async {
    final jsonList = _tasks.map((e) => e.toJson()).toList();
    localStorage.setItem(_tasksStorageKey, jsonEncode(jsonList));
  }

  Future<void> _saveProjects() async {
    final jsonList = _projects.map((e) => e.toJson()).toList();
    localStorage.setItem(_projectsStorageKey, jsonEncode(jsonList));
  }

  void addTimeEntry(TimeEntry entry) {
    _entries.add(entry);
    _saveEntries();
    notifyListeners();
  }

  void deleteTimeEntry(String id) {
    _entries.removeWhere((entry) => entry.id == id);
    _saveEntries();
    notifyListeners();
  }

  void addTask(Task task) {
    _tasks.add(task);
    _saveTasks();
    notifyListeners();
  }

  void deleteTask(String id) {
    _tasks.removeWhere((task) => task.id == id);
    _saveTasks();
    notifyListeners();
  }

  void addProject(Project project) {
    _projects.add(project);
    _saveProjects();
    notifyListeners();
  }

  void deleteProject(String id) {
    _projects.removeWhere((project) => project.id == id);
    _saveProjects();
    notifyListeners();
  }
}
