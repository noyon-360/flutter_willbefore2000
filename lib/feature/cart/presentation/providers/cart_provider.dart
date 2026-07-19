import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:collection/collection.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../product/domain/entrity/product.dart';
import '../../domain/entities/cart_item.dart';
import '../../data/repositories/cart_repository_impl.dart';
import '../../domain/repositories/cart_repository.dart';

class CartState {
  final List<CartItem> items;
  final bool isLoading;
  final String? errorMessage;
  final String? appliedPromoCode;
  final double promoDiscount;
  final bool isValidatingPromo;
  final String? promoError;

  const CartState({
    this.items = const [],
    this.isLoading = false,
    this.errorMessage,
    this.appliedPromoCode,
    this.promoDiscount = 0.0,
    this.isValidatingPromo = false,
    this.promoError,
  });

  CartState copyWith({
    List<CartItem>? items,
    bool? isLoading,
    String? errorMessage,
    String? appliedPromoCode,
    double? promoDiscount,
    bool? isValidatingPromo,
    String? promoError,
    bool clearPromo = false,
    bool clearPromoError = false,
    bool clearError = false,
  }) {
    return CartState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      appliedPromoCode: clearPromo ? null : (appliedPromoCode ?? this.appliedPromoCode),
      promoDiscount: clearPromo ? 0.0 : (promoDiscount ?? this.promoDiscount),
      isValidatingPromo: isValidatingPromo ?? this.isValidatingPromo,
      promoError: clearPromoError || clearPromo ? null : (promoError ?? this.promoError),
    );
  }

  double get subtotal {
    return items.fold(0.0, (sum, item) => sum + item.totalPrice);
  }

  double get tax {
    return 0.0;
  }

  double get total {
    final discounted = subtotal - promoDiscount;
    return (discounted < 0 ? 0.0 : discounted) + tax;
  }

  int get totalItems {
    return items.fold(0, (sum, item) => sum + item.quantity);
  }
}

class CartNotifier extends StateNotifier<CartState> {
  final CartRepository _repository;
  StreamSubscription<List<CartItem>>? _cartStreamSubscription;
  StreamSubscription? _authSubscription;

  CartNotifier(this._repository) : super(const CartState()) {
    _initializeCart();
    _listenToAuthChanges();
  }

  void _initializeCart() async {
    if (FirebaseAuth.instance.currentUser != null) {
      await loadCartItems();
      _listenToCartChanges();
    }
  }

  void _listenToAuthChanges() {
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null && user.emailVerified) {
        _cartStreamSubscription?.cancel();
        _listenToCartChanges();
        loadCartItems();
      } else if (user == null) {
        _cartStreamSubscription?.cancel();
        state = const CartState();
      }
    });
  }

  void _listenToCartChanges() {
    _cartStreamSubscription = _repository.getCartItemsStream().listen(
      (items) {
        state = state.copyWith(items: items, isLoading: false);
      },
      onError: (error) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: error.toString(),
        );
      },
    );
  }

  @override
  void dispose() {
    _cartStreamSubscription?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> loadCartItems() async {
    try {
      state = state.copyWith(isLoading: true, errorMessage: null);
      final items = await _repository.getCartItems();
      state = state.copyWith(items: items, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> addToCart(
    Product product,
    int quantity,
    String? size,
    String? color,
  ) async {
    try {
      state = state.copyWith(isLoading: true, errorMessage: null);

      final existingItem = await _repository.findExistingItem(
        product.id,
        size,
        color,
      );

      if (existingItem != null) {
        await _repository.updateCartItem(
          existingItem.id,
          existingItem.quantity + quantity,
        );
      } else {
        final newItem = CartItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          product: product,
          quantity: quantity,
          selectedSize: size,
          selectedColor: color,
        );
        await _repository.addCartItem(newItem);
      }

      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<CartItem> buyNow(
    Product product,
    int quantity,
    String? size,
    String? color,
  ) async {
    try {
      state = state.copyWith(isLoading: true, errorMessage: null);

      // Create a temporary CartItem for the "Buy Now" purchase
      final buyNowItem = CartItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        product: product,
        quantity: quantity,
        selectedSize: size,
        selectedColor: color,
      );

      state = state.copyWith(isLoading: false);
      return buyNowItem; // Return the item for checkout processing
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      rethrow; // Rethrow the error for the caller to handle
    }
  }

  CartItem? getExistingCartItem(String productId, String? size, String? color) {
    try {
      return state.items.firstWhere(
        (item) =>
            item.product.id == productId &&
            item.selectedSize == size &&
            item.selectedColor == color,
      );
    } catch (e) {
      return null;
    }
  }

  bool hasProductInCart(String productId) {
    return state.items.any((item) => item.product.id == productId);
  }

  List<CartItem> getProductVariantsInCart(String productId) {
    return state.items.where((item) => item.product.id == productId).toList();
  }

  Future<void> updateQuantity(String itemId, int newQuantity) async {
    try {
      if (newQuantity <= 0) {
        await removeFromCart(itemId);
        return;
      }

      await _repository.updateCartItem(itemId, newQuantity);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> removeFromCart(String itemId) async {
    try {
      await _repository.removeCartItem(itemId);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> clearCart() async {
    try {
      state = state.copyWith(isLoading: true);
      await _repository.clearCart();
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> updateCartItemVariant(
    String productId,
    String? oldSize,
    String? oldColor,
    String? newSize,
    String? newColor,
    int newQuantity,
  ) async {
    try {
      state = state.copyWith(isLoading: true, errorMessage: null);
      // Find the existing item
      final existingItem = state.items.firstWhereOrNull(
        (item) =>
            item.product.id == productId &&
            item.selectedSize == oldSize &&
            item.selectedColor == oldColor,
      );

      if (existingItem != null) {
        // Check if new variant already exists
        final newVariantExists = state.items.any(
          (item) =>
              item.product.id == productId &&
              item.selectedSize == newSize &&
              item.selectedColor == newColor &&
              item.id != existingItem.id,
        );

        if (newVariantExists) {
          // Merge with existing variant
          final targetItem = state.items.firstWhere(
            (item) =>
                item.product.id == productId &&
                item.selectedSize == newSize &&
                item.selectedColor == newColor,
          );

          await _repository.updateCartItem(
            targetItem.id,
            targetItem.quantity + newQuantity,
          );
          await _repository.removeCartItem(existingItem.id);
        } else {
          // Update existing item with new variants
          final updatedItem = CartItem(
            id: existingItem.id,
            product: existingItem.product,
            quantity: newQuantity,
            selectedSize: newSize,
            selectedColor: newColor,
          );
          await _repository.updateCartItemVariant(updatedItem);
        }
      }

      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> applyPromoCode(String code) async {
    if (code.trim().isEmpty) return;
    state = state.copyWith(isValidatingPromo: true, clearPromoError: true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('promos')
          .where('code', isEqualTo: code.trim().toUpperCase())
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        state = state.copyWith(
          isValidatingPromo: false,
          promoError: 'Invalid promo code.',
        );
        return;
      }

      final data = snapshot.docs.first.data();
      final bool isActive = data['isActive'] ?? false;
      final int endDate = data['endDate'] ?? 0;
      final int startDate = data['startDate'] ?? 0;
      final int usageLimit = data['usageLimit'] ?? 0;
      final int usedCount = data['usedCount'] ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;

      if (!isActive || now < startDate || now > endDate) {
        state = state.copyWith(
          isValidatingPromo: false,
          promoError: 'This promo code has expired or is inactive.',
        );
        return;
      }

      if (usageLimit > 0 && usedCount >= usageLimit) {
        state = state.copyWith(
          isValidatingPromo: false,
          promoError: 'This promo code has reached its usage limit.',
        );
        return;
      }

      final double? minimumOrderAmount =
          (data['minimumOrderAmount'] as num?)?.toDouble();
      if (minimumOrderAmount != null && state.subtotal < minimumOrderAmount) {
        state = state.copyWith(
          isValidatingPromo: false,
          promoError:
              'Minimum order of \$${minimumOrderAmount.toStringAsFixed(2)} required.',
        );
        return;
      }

      double discount = 0.0;
      final double pct = (data['discountPercentage'] as num?)?.toDouble() ?? 0.0;
      final double? fixedAmount = (data['discountAmount'] as num?)?.toDouble();

      if (fixedAmount != null && fixedAmount > 0) {
        discount = fixedAmount;
      } else if (pct > 0) {
        discount = state.subtotal * pct / 100;
      }

      if (discount > state.subtotal) discount = state.subtotal;

      state = state.copyWith(
        isValidatingPromo: false,
        appliedPromoCode: code.trim().toUpperCase(),
        promoDiscount: discount,
        clearPromoError: true,
      );
    } catch (e) {
      state = state.copyWith(
        isValidatingPromo: false,
        promoError: 'Failed to validate promo code.',
      );
    }
  }

  void removePromoCode() {
    state = state.copyWith(clearPromo: true);
  }
}

final cartProvider = StateNotifierProvider<CartNotifier, CartState>((ref) {
  final repository = ref.watch(cartRepositoryProvider);
  return CartNotifier(repository);
});
