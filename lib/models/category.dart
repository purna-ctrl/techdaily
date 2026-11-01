import 'package:flutter/material.dart';

class Category {
  final String id;
  final String name;
  final String description;
  final IconData icon;

  const Category({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
    };
  }

  factory Category.fromMap(Map<String, dynamic> map, {IconData icon = Icons.newspaper}) {
    return Category(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      icon: icon,
    );
  }
}
