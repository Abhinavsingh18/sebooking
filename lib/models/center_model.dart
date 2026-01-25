class CenterModel {
  final int id;
  final String name;
  final String address;
  final List<dynamic> timings;

  CenterModel({
    required this.id,
    required this.name,
    required this.address,
    required this.price,
    this.timings = const [],
  });

  factory CenterModel.fromJson(Map<String, dynamic> json) {
    return CenterModel(
      id: int.parse(json['id'].toString()),
      name: json['center_name'],
      address: json['address'],
      price: double.parse(json['price'].toString()),
      timings: json['timings'] ?? [],
    );
  }
}
