class ColorPreset {
  final String id;
  final String name;
  final int argb;
  const ColorPreset({required this.id, required this.name, required this.argb});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'argb': argb};

  factory ColorPreset.fromJson(Map<String, dynamic> j) => ColorPreset(
        id: j['id'] as String,
        name: j['name'] as String,
        argb: j['argb'] as int,
      );

  @override
  bool operator ==(Object other) =>
      other is ColorPreset &&
      other.id == id &&
      other.name == name &&
      other.argb == argb;

  @override
  int get hashCode => Object.hash(id, name, argb);
}
