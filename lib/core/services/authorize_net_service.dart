import 'package:flutx_core/flutx_core.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../constants/authorize_net_keys.dart';

class AuthorizeNetService {
  static const String _sandboxUrl =
      'https://apitest.authorize.net/xml/v1/request.api';
  static const String _liveUrl =
      'https://api.authorize.net/xml/v1/request.api';

  // Set to false when going live
  static const bool _isSandbox = false;

  static String get _baseUrl => _isSandbox ? _sandboxUrl : _liveUrl;

  static Future<Map<String, dynamic>> processPayment({
    required double amount,
    required String cardNumber,
    required String expirationDate, // format: YYYY-MM
    required String cardCode,
    String? customerEmail,
    Map<String, String>? metadata,
  }) async {
    try {
      final body = {
        "createTransactionRequest": {
          "merchantAuthentication": {
            "name": authorizeNetApiLoginId,
            "transactionKey": authorizeNetTransactionKey,
          },
          "transactionRequest": {
            "transactionType": "authCaptureTransaction",
            "amount": amount.toStringAsFixed(2),
            "payment": {
              "creditCard": {
                "cardNumber": cardNumber,
                "expirationDate": expirationDate,
                "cardCode": cardCode,
              }
            },
            if (customerEmail != null)
              "customer": {
                "email": customerEmail,
              },
            if (metadata != null && metadata.isNotEmpty)
              "userFields": {
                "userField": metadata.entries
                    .map((e) => {"name": e.key, "value": e.value})
                    .toList(),
              },
          }
        }
      };

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        // Authorize.net API responses include a UTF-8 BOM — strip it before parsing
        final rawBody = response.body.replaceFirst('﻿', '');
        final data = json.decode(rawBody);

        final transactionResponse = data['transactionResponse'];
        final messages = data['messages'];

        if (messages['resultCode'] == 'Ok' &&
            transactionResponse != null &&
            transactionResponse['responseCode'] == '1') {
          DPrint.log(
              "Authorize.net payment successful. TransactionId: ${transactionResponse['transId']}");
          return {
            'success': true,
            'transactionId': transactionResponse['transId'],
            'authCode': transactionResponse['authCode'],
          };
        } else {
          final errorText = transactionResponse?['errors']?[0]?['errorText'] ??
              messages['message']?[0]?['text'] ??
              'Payment failed';
          DPrint.error('Authorize.net payment declined: $errorText');
          return {'success': false, 'error': errorText};
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      DPrint.error('Authorize.net payment error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> refundTransaction({
    required String transactionId,
    required double amount,
    required String cardLastFour,
    required String expirationDate,
  }) async {
    try {
      final body = {
        "createTransactionRequest": {
          "merchantAuthentication": {
            "name": authorizeNetApiLoginId,
            "transactionKey": authorizeNetTransactionKey,
          },
          "transactionRequest": {
            "transactionType": "refundTransaction",
            "amount": amount.toStringAsFixed(2),
            "payment": {
              "creditCard": {
                "cardNumber": cardLastFour,
                "expirationDate": expirationDate,
              }
            },
            "refTransId": transactionId,
          }
        }
      };

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final rawBody = response.body.replaceFirst('﻿', '');
        final data = json.decode(rawBody);
        final messages = data['messages'];

        if (messages['resultCode'] == 'Ok') {
          DPrint.log("Authorize.net refund successful for transaction: $transactionId");
          return {'success': true, 'transactionId': transactionId};
        } else {
          final errorText = messages['message']?[0]?['text'] ?? 'Refund failed';
          DPrint.error('Authorize.net refund failed: $errorText');
          return {'success': false, 'error': errorText};
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      DPrint.error('Authorize.net refund error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getTransactionDetails(
      String transactionId) async {
    try {
      final body = {
        "getTransactionDetailsRequest": {
          "merchantAuthentication": {
            "name": authorizeNetApiLoginId,
            "transactionKey": authorizeNetTransactionKey,
          },
          "transId": transactionId,
        }
      };

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final rawBody = response.body.replaceFirst('﻿', '');
        final data = json.decode(rawBody);
        final messages = data['messages'];

        if (messages['resultCode'] == 'Ok') {
          DPrint.log("Transaction details fetched: $transactionId");
          return {'success': true, 'transaction': data['transaction']};
        } else {
          final errorText =
              messages['message']?[0]?['text'] ?? 'Failed to fetch transaction';
          return {'success': false, 'error': errorText};
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      DPrint.error('Authorize.net getTransactionDetails error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
}
