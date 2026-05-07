class CategoryModel {
  final String id;
  final String userId;
  final String name;

  CategoryModel({
    required this.id,
    required this.userId,
    required this.name,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
    };
  }

  factory CategoryModel.fromMap(Map<String, dynamic> map, String id) {
    return CategoryModel(
      id: id,
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
    );
  }
}
