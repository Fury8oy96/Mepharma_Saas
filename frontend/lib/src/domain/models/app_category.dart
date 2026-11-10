/// Domain representation of a product category.
class AppCategory {
  const AppCategory({
    required this.id,
    required this.name,
    this.description,
  });

  final int id;
  final String name;
  final String? description;
}
