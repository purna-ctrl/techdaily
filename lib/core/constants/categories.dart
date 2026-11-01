import 'package:flutter/material.dart';
import '../../models/category.dart';

class AppCategories {
  static const Category aiAndMl = Category(
    id: 'ai-ml',
    name: 'AI & Machine Learning',
    description: 'Frontier models, generative agents, neural compute & ethical AI.',
    icon: Icons.psychology_outlined,
  );

  static const Category software = Category(
    id: 'software',
    name: 'Software',
    description: 'Developer platforms, programming languages, operating systems & open source.',
    icon: Icons.code_rounded,
  );

  static const Category smartphones = Category(
    id: 'smartphones',
    name: 'Smartphones',
    description: 'Mobile operating systems, silicon chips, mobile photography & handheld devices.',
    icon: Icons.smartphone_outlined,
  );

  static const Category hardware = Category(
    id: 'hardware',
    name: 'Hardware',
    description: 'Semiconductors, graphics processing, microarchitecture & PC technology.',
    icon: Icons.memory_outlined,
  );

  static const Category cloud = Category(
    id: 'cloud',
    name: 'Cloud',
    description: 'Distributed infrastructure, hyperscale data centers, serverless & container systems.',
    icon: Icons.cloud_queue_outlined,
  );

  static const Category cybersecurity = Category(
    id: 'cybersecurity',
    name: 'Cybersecurity',
    description: 'Vulnerability disclosures, threat intelligence, privacy protocols & cryptography.',
    icon: Icons.security_outlined,
  );

  static const Category space = Category(
    id: 'space',
    name: 'Space',
    description: 'Commercial aerospace, orbital robotics, satellite constellations & deep space research.',
    icon: Icons.rocket_launch_outlined,
  );

  static const Category companies = Category(
    id: 'companies',
    name: 'Companies',
    description: 'Tech giants, enterprise mergers, executive strategies & financial reports.',
    icon: Icons.business_outlined,
  );

  static const Category startups = Category(
    id: 'startups',
    name: 'Startups',
    description: 'Venture capital investments, early-stage innovation & emerging tech founders.',
    icon: Icons.auto_awesome_outlined,
  );

  static const Category science = Category(
    id: 'science',
    name: 'Science',
    description: 'Quantum computing breakthroughs, fusion energy, biotechnology & physics research.',
    icon: Icons.biotech_outlined,
  );

  static const List<Category> all = [
    aiAndMl,
    software,
    smartphones,
    hardware,
    cloud,
    cybersecurity,
    space,
    companies,
    startups,
    science,
  ];

  static Category getById(String id) {
    return all.firstWhere(
      (cat) => cat.id.toLowerCase() == id.toLowerCase() || cat.name.toLowerCase() == id.toLowerCase(),
      orElse: () => Category(
        id: id,
        name: id,
        description: 'Technology news in $id',
        icon: Icons.article_outlined,
      ),
    );
  }
}
