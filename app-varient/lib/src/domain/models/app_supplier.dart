/// Domain representation of a supplier.
class AppSupplier {
  const AppSupplier({
    required this.id,
    required this.name,
    this.contactPerson,
    this.phone,
    this.email,
    this.address,
  });

  final int id;
  final String name;
  final String? contactPerson;
  final String? phone;
  final String? email;
  final String? address;
}
