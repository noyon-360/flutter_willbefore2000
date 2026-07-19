import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutx_core/flutx_core.dart';
import 'package:go_router/go_router.dart';
import 'package:smilestreatsapp/core/constants/app_colors.dart';
import 'package:smilestreatsapp/core/routes/route_endpoint.dart';
import 'package:smilestreatsapp/core/utils/extensions/button_extensions.dart';
import 'package:smilestreatsapp/feature/auth/presentation/providers/auth_provider.dart';
import '../../../../core/services/shipo_service.dart';
import '../../../../core/services/authorize_net_service.dart';
import '../../../auth/domain/models/user_model.dart';
import '../../../cart/presentation/providers/cart_provider.dart';
import '../../../order/domain/entities/order_entities.dart';
import '../../../order/presentation/providers/order_provider.dart';
import '../../../cart/domain/entities/cart_item.dart';
import '../providers/checkout_form_proivder.dart';
import '../../../../core/services/geo_service.dart';
import '../../../../core/utils/state_code_helper.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  final CartItem? buyNowItem;
  const CheckoutScreen({super.key, this.buyNowItem});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _zipCodeController = TextEditingController();
  final TextEditingController _countryController = TextEditingController();
  bool _isLoading = false;
  String _selectedPaymentMethod = 'authorize_net';

  final GeoService _geoService = GeoService();
  final List<String> _states = GeoService.usStates;
  List<String> _cities = [];
  List<String> _zipCodes = [];
  bool _isLoadingZips = false;

  String? _shippoAddressId;
  List<Map<String, dynamic>> _shippingRates = [];
  Map<String, dynamic>? _selectedRate;
  bool _isFetchingRates = false;
  String? _rateError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prefillFormWithUserData();
    });
  }

  void _prefillFormWithUserData() {
    final user = ref.read(authProvider).user;
    if (user != null) {
      if (user.displayName != null && user.displayName!.isNotEmpty) {
        final nameParts = user.displayName!.split(' ');
        if (nameParts.length >= 2) {
          _firstNameController.text = nameParts[0];
          _lastNameController.text = nameParts.sublist(1).join(' ');
        } else {
          _firstNameController.text = user.displayName!;
        }
      }
      if (user.email != null && user.email!.isNotEmpty) {
        _emailController.text = user.email!;
      }
      if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) {
        _phoneNumberController.text = user.phoneNumber!;
      }
      if (user.streetAddress != null && user.streetAddress!.isNotEmpty) {
        _addressController.text = user.streetAddress!;
      }
      if (user.city != null && user.city!.isNotEmpty) {
        _cityController.text = user.city!;
      }
      if (user.state != null && user.state!.isNotEmpty) {
        _stateController.text = user.state!;
      }
      if (user.zipCode != null && user.zipCode!.isNotEmpty) {
        _zipCodeController.text = user.zipCode!;
      }
      _countryController.text = 'United States';

      final formNotifier = ref.read(checkoutFormProvider.notifier);
      formNotifier.updateField('firstName', _firstNameController.text);
      formNotifier.updateField('lastName', _lastNameController.text);
      formNotifier.updateField('email', _emailController.text);
      formNotifier.updateField('phoneNumber', _phoneNumberController.text);
      formNotifier.updateField('address', _addressController.text);
      formNotifier.updateField('city', _cityController.text);
      formNotifier.updateField('state', _stateController.text);
      formNotifier.updateField('zipCode', _zipCodeController.text);
      formNotifier.updateField('country', _countryController.text);
    }
  }

  void _loadCitiesForState(String stateName) {
    setState(() {
      _cities = _geoService.getCitiesForState(stateName);
      _zipCodes = [];
      _cityController.clear();
      _zipCodeController.clear();
    });
    _updateFormField('city', '');
    _updateFormField('zipCode', '');
  }

  Future<void> _fetchZipsForCity(String city, String stateCode) async {
    setState(() {
      _isLoadingZips = true;
      _zipCodes = [];
      _zipCodeController.clear();
    });
    _updateFormField('zipCode', '');
    final zips = await _geoService.getZipsForCity(city, stateCode);
    if (mounted) setState(() { _zipCodes = zips; _isLoadingZips = false; });
  }

  void _showStatePicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return _buildSearchableList(
          title: 'Select State',
          items: _states,
          onSelect: (state) {
            setState(() { _stateController.text = state; });
            _updateFormField('state', state);
            Navigator.pop(context);
            _loadCitiesForState(state);
          },
        );
      },
    );
  }

  void _showCityPicker() {
    if (_stateController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a state first')),
      );
      return;
    }
    if (_cities.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No cities found for this state')),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return _buildSearchableList(
          title: 'Select City',
          items: _cities,
          onSelect: (city) {
            setState(() { _cityController.text = city; });
            _updateFormField('city', city);
            Navigator.pop(context);
            final stateCode = getStateCode(_stateController.text, 'US');
            _fetchZipsForCity(city, stateCode);
          },
        );
      },
    );
  }

  void _showZipPicker() {
    if (_cityController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a city first')),
      );
      return;
    }
    if (_isLoadingZips) return;
    if (_zipCodes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No ZIP codes found for this city')),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return _buildSearchableList(
          title: 'Select ZIP Code',
          items: _zipCodes,
          onSelect: (zip) {
            setState(() { _zipCodeController.text = zip; });
            _updateFormField('zipCode', zip);
            Navigator.pop(context);
          },
        );
      },
    );
  }

  Widget _buildSearchableList({
    required String title,
    required List<String> items,
    required Function(String) onSelect,
  }) {
    List<String> filteredItems = List.from(items);
    return StatefulBuilder(
      builder: (context, setModalState) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                title,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onChanged: (value) {
                  setModalState(() {
                    filteredItems = items
                        .where((item) =>
                            item.toLowerCase().contains(value.toLowerCase()))
                        .toList();
                  });
                },
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: filteredItems.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(filteredItems[index]),
                      onTap: () => onSelect(filteredItems[index]),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneNumberController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipCodeController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  void _updateFormField(String field, String value) {
    ref.read(checkoutFormProvider.notifier).updateField(field, value);
  }

  Future<void> _fetchShippingRates(CheckoutFormState formState) async {
    if (formState.address.isEmpty ||
        formState.city.isEmpty ||
        formState.state.isEmpty ||
        formState.zipCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in your full address first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isFetchingRates = true;
      _shippingRates = [];
      _selectedRate = null;
      _rateError = null;
    });

    try {
      final shippoService = ShippoService();
      String phoneInput = formState.phoneNumber.trim();
      String formattedPhone =
          phoneInput.startsWith('+') ? phoneInput : '+1$phoneInput';
      formattedPhone = formattedPhone.replaceAll(RegExp(r'[^0-9+]'), '');

      final addressResult = await shippoService.createAddress(
        name: '${formState.firstName} ${formState.lastName}',
        street1: formState.address,
        city: formState.city,
        state: getStateCode(formState.state, 'US'),
        zip: formState.zipCode,
        country: 'US',
        phone: formattedPhone.isNotEmpty ? formattedPhone : null,
        email: formState.email.isNotEmpty ? formState.email : null,
        isResidential: true,
      );

      if (addressResult == null || addressResult['object_id'] == null) {
        setState(() {
          _rateError = 'Could not validate address. Please check your details.';
          _isFetchingRates = false;
        });
        return;
      }

      _shippoAddressId = addressResult['object_id'];

      final shipmentResult = await shippoService.createShipment(
        addressToId: _shippoAddressId!,
      );

      if (shipmentResult == null || shipmentResult['status'] == 'error') {
        setState(() {
          _rateError = 'Could not fetch shipping rates. Please try again.';
          _isFetchingRates = false;
        });
        return;
      }

      final rates = (shipmentResult['rates'] as List?)
          ?.cast<Map<String, dynamic>>()
          .where((r) =>
              r['amount'] != null &&
              double.tryParse(r['amount'].toString()) != null)
          .toList() ?? [];

      rates.sort((a, b) =>
          double.parse(a['amount'].toString())
              .compareTo(double.parse(b['amount'].toString())));

      setState(() {
        _shippingRates = rates;
        _isFetchingRates = false;
        if (rates.isEmpty) {
          _rateError = 'No shipping rates available for this address.';
        }
      });
    } catch (e) {
      setState(() {
        _rateError = 'Error fetching rates: ${e.toString()}';
        _isFetchingRates = false;
      });
    }
  }

  Widget _buildShippingRatesSection(CheckoutFormState formState) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Shipping Options',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryLaurel,
            ),
          ),
          const SizedBox(height: 12),
          if (_isFetchingRates)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 8),
                    Text('Fetching shipping rates...', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            )
          else if (_rateError != null)
            Column(
              children: [
                Text(_rateError!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => _fetchShippingRates(formState),
                    child: const Text('Retry'),
                  ),
                ),
              ],
            )
          else if (_shippingRates.isEmpty)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _fetchShippingRates(formState),
                icon: const Icon(Icons.local_shipping_outlined, color: Colors.white),
                label: const Text('Get Shipping Rates', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryLaurel,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            )
          else
            Column(
              children: [
                ..._shippingRates.map((rate) {
                  final isSelected = _selectedRate?['object_id'] == rate['object_id'];
                  final amount = double.tryParse(rate['amount'].toString()) ?? 0.0;
                  final provider = rate['provider'] ?? '';
                  final serviceName = rate['servicelevel']?['name'] ?? '';
                  final estDays = rate['estimated_days'];

                  return GestureDetector(
                    onTap: () => setState(() => _selectedRate = rate),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isSelected ? AppColors.primaryLaurel : Colors.grey[300]!,
                          width: isSelected ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        color: isSelected
                            ? AppColors.primaryLaurel.withValues(alpha: 0.05)
                            : Colors.white,
                      ),
                      child: Row(
                        children: [
                          Radio<String>(
                            value: rate['object_id'],
                            groupValue: _selectedRate?['object_id'],
                            onChanged: (_) => setState(() => _selectedRate = rate),
                            activeColor: AppColors.primaryLaurel,
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$provider — $serviceName',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                if (estDays != null)
                                  Text(
                                    'Est. $estDays day${estDays == 1 ? '' : 's'}',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            '\$${amount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                TextButton(
                  onPressed: () => _fetchShippingRates(formState),
                  child: const Text('Refresh rates'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartProvider);
    final formState = ref.watch(checkoutFormProvider);
    final user = ref.watch(authProvider).user;

    final checkoutItems = widget.buyNowItem != null
        ? [widget.buyNowItem!]
        : cartState.items;

    final double itemsTotal = widget.buyNowItem != null
        ? widget.buyNowItem!.totalPrice
        : cartState.total;

    final double shippingCost = _selectedRate != null
        ? (double.tryParse(_selectedRate!['amount'].toString()) ?? 0.0)
        : 0.0;
    final double grandTotal = itemsTotal + shippingCost;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: cartState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : cartState.errorMessage != null
              ? Center(child: Text('Error: ${cartState.errorMessage}'))
              : checkoutItems.isEmpty
                  ? const Center(child: Text('Your cart is empty'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (user != null) _buildUserInfoBanner(user),
                          _buildShippingSection(ref, formState, context),
                          const SizedBox(height: 24),
                          _buildShippingRatesSection(formState),
                          const SizedBox(height: 24),
                          _buildOrderSummary(
                            itemsTotal: itemsTotal,
                            shippingCost: shippingCost,
                            grandTotal: grandTotal,
                            promoDiscount: cartState.promoDiscount,
                          ),
                          const SizedBox(height: 24),
                          _buildPaymentSection(),
                          const SizedBox(height: 32),
                          _buildPayButton(
                            ref,
                            checkoutItems,
                            grandTotal,
                            formState,
                            shippingCost,
                          ),
                          if (_isLoading) ...[
                            const SizedBox(height: 12),
                            Text(
                              _loadingMessage,
                              style: const TextStyle(
                                color: AppColors.primaryLaurel,
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ],
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildUserInfoBanner(UserModel user) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.primaryLaurel.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: AppColors.primaryLaurel.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.person_outline, color: AppColors.primaryLaurel, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Shipping to your account',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryLaurel,
                  ),
                ),
                if (user.displayName != null && user.displayName!.isNotEmpty)
                  Text(
                    user.displayName!,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSummary({
    required double itemsTotal,
    required double shippingCost,
    required double grandTotal,
    required double promoDiscount,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Summary',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryLaurel,
            ),
          ),
          const SizedBox(height: 12),
          _summaryRow('Subtotal', '\$${itemsTotal.toStringAsFixed(2)}'),
          if (promoDiscount > 0)
            _summaryRow(
              'Promo Discount',
              '-\$${promoDiscount.toStringAsFixed(2)}',
              valueColor: Colors.green,
            ),
          const SizedBox(height: 8),
          _summaryRow(
            'Shipping',
            _selectedRate == null
                ? 'Select a shipping option'
                : '\$${shippingCost.toStringAsFixed(2)}',
            valueColor: _selectedRate == null ? Colors.grey : null,
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              Text(
                '\$${grandTotal.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryLaurel,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 14, color: Colors.grey)),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: valueColor ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShippingSection(
    WidgetRef ref,
    CheckoutFormState formState,
    BuildContext context,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Shipping Information',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryLaurel,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _firstNameController,
                  field: 'firstName',
                  label: 'First Name',
                  isRequired: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                  controller: _lastNameController,
                  field: 'lastName',
                  label: 'Last Name',
                  isRequired: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _emailController,
            field: 'email',
            label: 'Email',
            keyboardType: TextInputType.emailAddress,
            isRequired: true,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _phoneNumberController,
            field: 'phoneNumber',
            label: 'Phone Number',
            keyboardType: TextInputType.phone,
            isRequired: true,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _addressController,
            field: 'address',
            label: 'Address',
            isRequired: true,
          ),
          const SizedBox(height: 16),
          _buildCascadingPicker(
            label: 'State',
            controller: _stateController,
            onTap: _showStatePicker,
            isLoading: false,
            enabled: true,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _buildCascadingPicker(
                  label: 'City',
                  controller: _cityController,
                  onTap: _showCityPicker,
                  isLoading: false,
                  enabled: _stateController.text.isNotEmpty,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _buildCascadingPicker(
                  label: 'ZIP Code',
                  controller: _zipCodeController,
                  onTap: _showZipPicker,
                  isLoading: _isLoadingZips,
                  enabled: _cityController.text.isNotEmpty,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Payment Method',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () =>
                setState(() => _selectedPaymentMethod = 'authorize_net'),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: _selectedPaymentMethod == 'authorize_net'
                      ? Colors.orange[300]!
                      : Colors.grey[300]!,
                  width: _selectedPaymentMethod == 'authorize_net' ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Radio<String>(
                    value: 'authorize_net',
                    groupValue: _selectedPaymentMethod,
                    onChanged: (value) =>
                        setState(() => _selectedPaymentMethod = value!),
                    activeColor: Colors.orange,
                  ),
                  const Text(
                    'Pay With Authorize.net',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w400),
                  ),
                  const Spacer(),
                  const Icon(Icons.credit_card,
                      color: Colors.orange, size: 28),
                  Gap.w8,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCascadingPicker({
    required String label,
    required TextEditingController controller,
    required VoidCallback onTap,
    bool isLoading = false,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppColors.iconDeselectedColor,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: enabled ? onTap : null,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.iconDeselectedColor),
              borderRadius: BorderRadius.circular(4),
              color: enabled ? Colors.white : Colors.grey[100],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    controller.text.isEmpty
                        ? 'Select $label'
                        : controller.text,
                    style: TextStyle(
                      color: controller.text.isEmpty
                          ? Colors.grey
                          : Colors.black,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isLoading)
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(Icons.arrow_drop_down,
                      color: Colors.grey[600], size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String field,
    required String label,
    TextInputType? keyboardType,
    bool isRequired = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: AppColors.iconDeselectedColor,
              ),
            ),
            if (isRequired)
              const Text(
                ' *',
                style: TextStyle(fontSize: 14, color: Colors.red),
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          onChanged: (value) => _updateFormField(field, value),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide:
                  BorderSide(color: AppColors.iconDeselectedColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide:
                  BorderSide(color: AppColors.iconDeselectedColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(
                color: AppColors.iconDeselectedColor,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPayButton(
    WidgetRef ref,
    List<CartItem> cartItems,
    double total,
    CheckoutFormState formState,
    double shippingCost,
  ) {
    return SizedBox(
      width: 250,
      child: ref.context.primaryButton(
        isLoading: _isLoading,
        onPressed: () {
          if (!formState.isValid) {
            ScaffoldMessenger.of(ref.context).showSnackBar(
              const SnackBar(
                content: Text('Please fill all required fields'),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }
          _showCardInputSheet(ref, cartItems, total, formState, shippingCost);
        },
        text: 'Pay \$${total.toStringAsFixed(2)} & Place Order',
      ),
    );
  }

  String _loadingMessage = 'Processing...';

  Future<void> _createShippoAddressAsync(CheckoutFormState formState) async {
    try {
      final shippoService = ShippoService();
      String phoneInput = formState.phoneNumber.trim();
      String formattedPhone =
          phoneInput.startsWith('+') ? phoneInput : '+1$phoneInput';
      formattedPhone = formattedPhone.replaceAll(RegExp(r'[^0-9+]'), '');

      final addressResult = await shippoService.createAddress(
        name: '${formState.firstName} ${formState.lastName}',
        street1: formState.address,
        city: formState.city,
        state: getStateCode(formState.state, 'US'),
        zip: formState.zipCode,
        country: 'US',
        phone: formattedPhone,
        email: formState.email,
        isResidential: true,
        metadata: 'Customer Order',
      );
      if (addressResult != null && addressResult['object_id'] != null) {
        _shippoAddressId = addressResult['object_id'];
      }
    } catch (_) {
      // Non-blocking: Shippo address is best-effort for tracking only
    }
  }

  void _showCardInputSheet(
    WidgetRef ref,
    List<CartItem> cartItems,
    double total,
    CheckoutFormState formState,
    double shippingCost,
  ) {
    final cardNumberController = TextEditingController();
    final expiryController = TextEditingController();
    final cvvController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter Card Details',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: cardNumberController,
                keyboardType: TextInputType.number,
                maxLength: 16,
                decoration: const InputDecoration(
                  labelText: 'Card Number',
                  hintText: '1234567890123456',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.credit_card),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: expiryController,
                      keyboardType: TextInputType.number,
                      maxLength: 5,
                      decoration: const InputDecoration(
                        labelText: 'Expiry (MM/YY)',
                        hintText: 'MM/YY',
                        border: OutlineInputBorder(),
                        counterText: '',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: cvvController,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'CVV',
                        hintText: '123',
                        border: OutlineInputBorder(),
                        counterText: '',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    final parts = expiryController.text.trim().split('/');
                    if (parts.length != 2 ||
                        parts[0].isEmpty ||
                        parts[1].isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                          content:
                              Text('Invalid expiry. Use MM/YY format'),
                        ),
                      );
                      return;
                    }
                    final expirationDate =
                        '20${parts[1]}-${parts[0].padLeft(2, '0')}';
                    Navigator.pop(ctx);
                    _proceedToAuthorizeNetPayment(
                      ref,
                      cartItems,
                      total,
                      formState,
                      cardNumberController.text.trim(),
                      expirationDate,
                      cvvController.text.trim(),
                      shippingCost,
                    );
                  },
                  child: const Text(
                    'Pay Now',
                    style:
                        TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Future<void> _proceedToAuthorizeNetPayment(
    WidgetRef ref,
    List<CartItem> cartItems,
    double total,
    CheckoutFormState formState,
    String cardNumber,
    String expirationDate,
    String cardCode,
    double shippingCost,
  ) async {
    setState(() {
      _isLoading = true;
      _loadingMessage = 'Processing Payment...';
    });

    try {
      await _createShippoAddressAsync(formState);

      final paymentResult = await AuthorizeNetService.processPayment(
        amount: total,
        cardNumber: cardNumber,
        expirationDate: expirationDate,
        cardCode: cardCode,
        customerEmail: formState.email,
        metadata: {
          'order_items': cartItems.length.toString(),
          'shippo_address_id': _shippoAddressId ?? '',
        },
      );

      if (!paymentResult['success']) {
        throw Exception(paymentResult['error'] ?? 'Payment failed');
      }

      final String transactionId = paymentResult['transactionId'];
      setState(() => _loadingMessage = 'Finalizing Order...');

      String phoneInput = formState.phoneNumber.trim();
      String formattedPhone =
          phoneInput.startsWith('+') ? phoneInput : '+1$phoneInput';
      formattedPhone = formattedPhone.replaceAll(RegExp(r'[^0-9+]'), '');

      final shippingAddress = ShippingAddress(
        firstName: formState.firstName,
        lastName: formState.lastName,
        email: formState.email,
        phoneNumber: formattedPhone,
        address: formState.address,
        city: formState.city,
        state: formState.state,
        zipCode: formState.zipCode,
        country: formState.country,
      );

      final order = await ref.read(orderProvider.notifier).createOrder(
            items: cartItems,
            shippingAddress: shippingAddress,
            paymentIntentId: 'authnet_$transactionId',
            metadata: {
              'shippo_address_id': _shippoAddressId,
              'shipping_cost': shippingCost.toStringAsFixed(2),
              'shipping_type': 'flat_rate',
              'payment_gateway': 'authorize_net',
              'authorize_transaction_id': transactionId,
            },
          );

      if (_shippoAddressId != null) {
        setState(() => _loadingMessage = 'Syncing with Shippo...');
        await ShippoService().createShippoOrder(
          orderNumber: order.orderNumber ?? order.id,
          toAddressId: _shippoAddressId!,
          items: cartItems,
          subtotal: order.subtotal,
          total: order.total,
          shippingCost: shippingCost.toStringAsFixed(2),
          shippingMethod: 'Flat Rate',
        );
      }

      if (widget.buyNowItem == null) {
        await ref.read(cartProvider.notifier).clearCart();
      }

      ref.read(checkoutFormProvider.notifier).reset();

      if (ref.context.mounted) {
        GoRouter.of(ref.context).go(RoutePaths.orderConfirm, extra: order);
      }
    } catch (e) {
      DPrint.error('Authorize.net Payment Error: $e');
      if (ref.context.mounted) {
        showDialog(
          context: ref.context,
          builder: (context) => AlertDialog(
            title: const Text('Payment Error'),
            content: Text(e.toString().replaceAll('Exception: ', '')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadingMessage = 'Processing...';
        });
      }
    }
  }
}
