import 'dart:convert';
import 'package:flutx_core/flutx_core.dart';
import 'package:http/http.dart' as http;
import 'package:smilestreatsapp/core/constants/shippo_key.dart';
import 'package:smilestreatsapp/feature/cart/domain/entities/cart_item.dart';

class ShippoService {
  static const String baseUrl = 'https://api.goshippo.com';
  static const String apiToken = shippoLiveKey;

  Future<Map<String, dynamic>?> createAddress({
    required String name,
    String? company,
    required String street1,
    String? street2,
    required String city,
    required String state,
    required String zip,
    required String country,
    String? phone,
    String? email,
    bool? isResidential,
    String? metadata,
  }) async {
    final url = Uri.parse('$baseUrl/addresses/');
    final headers = {
      'Authorization': 'ShippoToken $apiToken',
      'Content-Type': 'application/json',
    };

    final body = jsonEncode({
      'name': name,
      if (company != null) 'company': company,
      'street1': street1,
      if (street2 != null) 'street2': street2,
      'city': city,
      'state': state,
      'zip': zip,
      'country': country, // ISO2 code, e.g., 'US'
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
      if (isResidential != null) 'is_residential': isResidential,
      if (metadata != null) 'metadata': metadata,
      'validate': true,
    });

    try {
      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 201 || response.statusCode == 400) {
        // Success for POST or Validation Error
        return jsonDecode(response.body);
      } else {
        DPrint.error('Error: ${response.statusCode} - ${response.body}');
        return {
          'status': 'error',
          'statusCode': response.statusCode,
          'message': response.body,
        };
      }
    } catch (e) {
      DPrint.error('Exception: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> createShippoOrder({
    required String orderNumber,
    required String toAddressId,
    required List<CartItem> items,
    required double subtotal,
    required double total,
    String? shippingCost,
    String? shippingMethod,
  }) async {
    final url = Uri.parse('$baseUrl/orders/');
    final headers = {
      'Authorization': 'ShippoToken $apiToken',
      'Content-Type': 'application/json',
    };

    final lineItems = items
        .map((item) => {
              'title': item.product.title,
              'quantity': item.quantity,
              'total_price': item.totalPrice.toStringAsFixed(2),
              'currency': 'USD',
              'weight': '0.5',
              'weight_unit': 'lb',
              if (item.selectedSize != null || item.selectedColor != null)
                'variant_title': [
                  if (item.selectedSize != null) item.selectedSize,
                  if (item.selectedColor != null) item.selectedColor,
                ].join(' / '),
            })
        .toList();

    final body = jsonEncode({
      'order_number': orderNumber,
      'order_status': 'PAID',
      'placed_at': DateTime.now().toUtc().toIso8601String(),
      'to_address': toAddressId,
      'line_items': lineItems,
      if (shippingCost != null) 'shipping_cost': shippingCost,
      if (shippingCost != null) 'shipping_cost_currency': 'USD',
      if (shippingMethod != null) 'shipping_method': shippingMethod,
      'subtotal_price': subtotal.toStringAsFixed(2),
      'total_tax': '0.00',
      'total_price': total.toStringAsFixed(2),
      'currency': 'USD',
    });

    try {
      final response = await http.post(url, headers: headers, body: body);
      if (response.statusCode == 201) {
        final result = jsonDecode(response.body);
        DPrint.log('Shippo order created: ${result['object_id']}');
        return result;
      } else {
        DPrint.error(
          'Shippo order error: ${response.statusCode} - ${response.body}',
        );
        return null;
      }
    } catch (e) {
      DPrint.error('Exception creating Shippo order: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> createShipment({
    required String addressToId,
    double weight = 1.0, // in pounds
    String massUnit = 'lb',
    double length = 5,
    double width = 5,
    double height = 5,
    String distanceUnit = 'in',
  }) async {
    final url = Uri.parse('$baseUrl/shipments/');
    final headers = {
      'Authorization': 'ShippoToken $apiToken',
      'Content-Type': 'application/json',
    };

    final body = jsonEncode({
      'address_from': {
        'name': 'Smile Treats',
        'street1': '852 S Carson St',
        'city': 'Carson',
        'state': 'CA',
        'zip': '90745',
        'country': 'US',
      },
      'address_to': addressToId,
      'parcels': [
        {
          'length': length.toString(),
          'width': width.toString(),
          'height': height.toString(),
          'distance_unit': distanceUnit,
          'weight': weight.toString(),
          'mass_unit': massUnit,
        },
      ],
      'async': false,
    });

    try {
      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        DPrint.error(
          'Error creating shipment: ${response.statusCode} - ${response.body}',
        );
        return {
          'status': 'error',
          'statusCode': response.statusCode,
          'message': response.body,
        };
      }
    } catch (e) {
      DPrint.error('Exception creating shipment: $e');
      return null;
    }
  }
}
