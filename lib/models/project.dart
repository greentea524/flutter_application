class Project {
  final String id;
  final String name;

  Project({required this.id, required this.name});

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(id: json['id'] as String, name: json['name'] as String);
  }
}
