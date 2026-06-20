# smilestreats

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

flutter run -d chrome --web-renderer html // to run the app

flutter build web --web-renderer html --release // to generate a production build

# Payment Gateway Testing Reference

This repository contains a collection of test card numbers used for verifying integration with various credit card brands during the reference test phase.

## Test Card Reference Table

Below is a quick-reference list of the card brands and their corresponding test numbers. For a visual layout of this data, please refer to `image_9273ef.png`.

| Test Card Brand                | Number           |
| :----------------------------- | :--------------- |
| **American Express**           | 370000000000002  |
| **China UnionPay**             | 6221499053360818 |
|                                | 6262320002000067 |
|                                | 6284480000000008 |
| **Discover**                   | 6011000000000012 |
| **JCB**                        | 3088000000000017 |
| **Diners Club/ Carte Blanche** | 38000000000006   |
| **Visa**                       | 4007000000027    |
|                                | 4012888818888    |
|                                | 4111111111111111 |
| **Mastercard**                 | 5424000000000015 |
|                                | 2223000010309703 |
|                                | 2223000010309711 |

## Usage

Use these numbers in your staging/sandbox environment to simulate transaction processing across different card issuers. Ensure that you use valid mock values for the expiration date (e.g., any future date) and CVV/CVC (e.g., `123` or `1234` for Amex).
