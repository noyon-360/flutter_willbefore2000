import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final shippingFlatRateProvider = FutureProvider<double>((ref) async {
  final doc = await FirebaseFirestore.instance
      .collection('settings')
      .doc('shipping')
      .get();
  if (!doc.exists) return 0.0;
  return (doc.data()?['flatRate'] as num?)?.toDouble() ?? 0.0;
});
