import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../model/product_item.dart';
import '../model/product_metrics.dart';
import '../provider/product_provider.dart';
import '../utils/style.dart';

class NewProductScreen extends StatefulWidget {
  static const routeName = '/new-product';
  const NewProductScreen({super.key});

  @override
  State<NewProductScreen> createState() => _NewProductScreenState();
}

class _NewProductScreenState extends State<NewProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _categoryController = TextEditingController(text: 'General');
  final _retailPriceController = TextEditingController();
  final _wholesalePriceController = TextEditingController();
  final _wholesaleMinQtyController = TextEditingController(text: '6');
  final _stockController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _allowNegotiation = false;
  bool _availableForRetail = true;
  bool _availableForWholesale = false;

  final ImagePicker _picker = ImagePicker();
  final List<String> _imagePaths = [];
  int _coverIndex = 0;
  bool _autoPrompted = false;
  bool _isPicking = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _promptInitialPicker());
  }

  void _promptInitialPicker() {
    if (_autoPrompted) return;
    _autoPrompted = true;
    _pickImages();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _categoryController.dispose();
    _retailPriceController.dispose();
    _wholesalePriceController.dispose();
    _wholesaleMinQtyController.dispose();
    _stockController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    if (_isPicking) return;
    _isPicking = true;
    try {
      List<XFile> selections = await _picker.pickMultiImage(imageQuality: 85);

      if (selections.isEmpty) {
        final fallback = await _picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
        );
        if (fallback != null) {
          selections = [fallback];
        }
      }

      if (!mounted || selections.isEmpty) return;

      setState(() {
        _imagePaths.addAll(selections.map((file) => file.path));
        if (_imagePaths.isNotEmpty) {
          _coverIndex = 0;
        }
      });
    } on PlatformException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.message ?? 'Could not open gallery. Please try again.',
          ),
        ),
      );
    } finally {
      _isPicking = false;
    }
  }

  void _setCover(int index) {
    setState(() {
      _coverIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Product'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildPhotoSelector(),
            const SizedBox(height: 16),
            _InstagramPreview(
              images: _imagePaths,
              coverIndex: _coverIndex,
              title: _titleController.text,
              pricingLabel: _previewPricingLabel(),
              modeLabel: _previewModeLabel(),
              category: _categoryController.text,
              description: _descriptionController.text,
              allowNegotiation: _allowNegotiation,
              onAddPhoto: _pickImages,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _titleController,
              label: 'Caption / Product name',
              validator: (value) =>
                  value == null || value.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _categoryController,
              label: 'Category / Collection',
            ),
            const SizedBox(height: 12),
            const Text(
              'Selling mode',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Available for retail'),
              subtitle: const Text('Buyers can order single units'),
              value: _availableForRetail,
              onChanged: (value) => setState(() => _availableForRetail = value),
            ),
            if (_availableForRetail) ...[
              const SizedBox(height: 8),
              _buildTextField(
                controller: _retailPriceController,
                label: 'Retail price (TZS)',
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (!_availableForRetail) return null;
                  return value == null || value.isEmpty ? 'Required' : null;
                },
              ),
            ],
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Available for wholesale'),
              subtitle: const Text('Buyers can order in bulk'),
              value: _availableForWholesale,
              onChanged: (value) =>
                  setState(() => _availableForWholesale = value),
            ),
            if (_availableForWholesale) ...[
              const SizedBox(height: 8),
              _buildTextField(
                controller: _wholesalePriceController,
                label: 'Wholesale price per unit (TZS)',
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (!_availableForWholesale) return null;
                  return value == null || value.isEmpty ? 'Required' : null;
                },
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _wholesaleMinQtyController,
                label: 'Minimum wholesale quantity',
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (!_availableForWholesale) return null;
                  if (value == null || value.isEmpty) return 'Required';
                  final qty = int.tryParse(value) ?? 0;
                  if (qty < 2) return 'Use 2 or more';
                  return null;
                },
              ),
            ],
            const SizedBox(height: 12),
            _buildTextField(
              controller: _stockController,
              label: 'Stock quantity',
              keyboardType: TextInputType.number,
              validator: (value) =>
                  value == null || value.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _descriptionController,
              label: 'Story / Description',
              minLines: 3,
              maxLines: 5,
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF6F8F8),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: sellerGreen.withValues(alpha: 0.14)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.verified_outlined,
                    color: sellerGreen,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Marketplace review required',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Every new product is submitted for moderation before it appears to buyers.',
                          style: TextStyle(
                            color: sellerGray,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Allow negotiation'),
              subtitle: const Text('Buyers can DM counter offers'),
              value: _allowNegotiation,
              onChanged: (value) => setState(() => _allowNegotiation = value),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving ? null : _previewProduct,
                    child: const Text('Preview'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveProduct,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: sellerRed,
                      foregroundColor: Colors.white,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Submit for Review'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoSelector() {
    if (_imagePaths.isEmpty) {
      return GestureDetector(
        onTap: _pickImages,
        child: Container(
          height: 220,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_photo_alternate_outlined,
                  size: 48, color: sellerGreen),
              SizedBox(height: 12),
              Text(
                'Tap to select product photos',
                style: TextStyle(color: sellerGray),
              ),
            ],
          ),
        ),
      );
    }

    final coverPath = _imagePaths[_coverIndex];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 4 / 5,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: _ProductImage(source: coverPath),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Selected photos',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            TextButton.icon(
              onPressed: _pickImages,
              icon: const Icon(Icons.add),
              label: const Text('Add more'),
            ),
          ],
        ),
        SizedBox(
          height: 72,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _imagePaths.length,
            itemBuilder: (_, index) {
              final path = _imagePaths[index];
              final isCover = index == _coverIndex;
              return GestureDetector(
                onTap: () => _setCover(index),
                child: Container(
                  width: 64,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isCover ? sellerRed : Colors.transparent,
                      width: isCover ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _ProductImage(source: path),
                        if (isCover)
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              color: Colors.black54,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              child: const Text(
                                'Cover',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  TextFormField _buildTextField({
    required TextEditingController controller,
    required String label,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int? minLines,
    int? maxLines,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      validator: validator,
      keyboardType: keyboardType,
      minLines: minLines,
      maxLines: maxLines,
      onChanged: (_) => setState(() {}),
    );
  }

  void _previewProduct() {
    if (!_formKey.currentState!.validate()) return;
    final pricingError = _validatePricing();
    if (pricingError != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(pricingError)));
      return;
    }
    final product = _buildProduct();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Preview'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              product.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(product.description),
            const SizedBox(height: 8),
            Text('Pricing: ${_previewPricingLabel()}'),
            Text('Mode: ${_previewModeLabel()}'),
            Text('Stock: ${product.stock}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveProduct() async {
    if (_imagePaths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one product photo.')),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    final pricingError = _validatePricing();
    if (pricingError != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(pricingError)));
      return;
    }
    final product = _buildProduct();
    setState(() => _isSaving = true);
    try {
      await context.read<ProductProvider>().addProduct(product);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
      setState(() => _isSaving = false);
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Product submitted for marketplace review.')),
    );
    Navigator.of(context).pop();
  }

  ProductItem _buildProduct() {
    final retailPrice = double.tryParse(_retailPriceController.text) ?? 0;
    final wholesalePrice =
        double.tryParse(_wholesalePriceController.text) ?? 0;
    final wholesaleMinQty =
        int.tryParse(_wholesaleMinQtyController.text) ?? 1;
    final purchaseMode = _availableForWholesale && !_availableForRetail
        ? 'wholesale'
        : 'retail';
    final unitPrice = _availableForRetail
        ? retailPrice
        : (_availableForWholesale ? wholesalePrice : 0.0);
    return ProductItem(
      id: '',
      sku: '',
      title: _titleController.text,
      category: _categoryController.text,
      description: _descriptionController.text,
      price: unitPrice,
      purchaseMode: purchaseMode,
      unitPrice: unitPrice,
      availableForRetail: _availableForRetail,
      availableForWholesale: _availableForWholesale,
      retailPrice: retailPrice,
      wholesalePrice: wholesalePrice,
      wholesaleMinQty: wholesaleMinQty,
      stock: int.tryParse(_stockController.text) ?? 0,
      media: List<String>.from(_imagePaths),
      allowNegotiation: _allowNegotiation,
      status: ProductStatus.pending,
      metrics: const ProductMetrics(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  String? _validatePricing() {
    if (!_availableForRetail && !_availableForWholesale) {
      return 'Enable retail or wholesale before submitting.';
    }

    if (_availableForRetail &&
        (double.tryParse(_retailPriceController.text) ?? 0) <= 0) {
      return 'Enter a valid retail price.';
    }

    if (_availableForWholesale &&
        (double.tryParse(_wholesalePriceController.text) ?? 0) <= 0) {
      return 'Enter a valid wholesale price.';
    }

    if (_availableForWholesale &&
        (int.tryParse(_wholesaleMinQtyController.text) ?? 0) < 2) {
      return 'Wholesale minimum quantity must be 2 or more.';
    }

    return null;
  }

  String _previewPricingLabel() {
    final retailPrice = double.tryParse(_retailPriceController.text) ?? 0;
    final wholesalePrice =
        double.tryParse(_wholesalePriceController.text) ?? 0;

    if (_availableForRetail &&
        _availableForWholesale &&
        retailPrice > 0 &&
        wholesalePrice > 0) {
      return 'Retail TZS ${retailPrice.toStringAsFixed(0)} • Wholesale TZS ${wholesalePrice.toStringAsFixed(0)}';
    }
    if (_availableForRetail && retailPrice > 0) {
      return 'Retail TZS ${retailPrice.toStringAsFixed(0)}';
    }
    if (_availableForWholesale && wholesalePrice > 0) {
      return 'Wholesale TZS ${wholesalePrice.toStringAsFixed(0)}';
    }
    return 'Set selling price';
  }

  String _previewModeLabel() {
    if (_availableForRetail && _availableForWholesale) {
      final qty = int.tryParse(_wholesaleMinQtyController.text) ?? 1;
      return 'Retail + Wholesale from $qty units';
    }
    if (_availableForWholesale) {
      final qty = int.tryParse(_wholesaleMinQtyController.text) ?? 1;
      return 'Wholesale only from $qty units';
    }
    return 'Retail only';
  }
}

class _InstagramPreview extends StatelessWidget {
  const _InstagramPreview({
    required this.images,
    required this.coverIndex,
    required this.title,
    required this.pricingLabel,
    required this.modeLabel,
    required this.category,
    required this.description,
    required this.allowNegotiation,
    required this.onAddPhoto,
  });

  final List<String> images;
  final int coverIndex;
  final String title;
  final String pricingLabel;
  final String modeLabel;
  final String category;
  final String description;
  final bool allowNegotiation;
  final VoidCallback onAddPhoto;

  @override
  Widget build(BuildContext context) {
    final resolvedTitle = title.isEmpty ? 'Fresh Kariakoo drop' : title.trim();
    final resolvedPrice = pricingLabel.trim().isEmpty ? 'Set price' : pricingLabel;
    final resolvedCategory =
        category.isEmpty ? 'Category' : '#${category.replaceAll(' ', '')}';
    final hasImage = images.isNotEmpty;
    final cover = hasImage ? images[coverIndex] : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Instagram style preview',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            TextButton(
              onPressed: onAddPhoto,
              child: const Text('Change photos'),
            ),
          ],
        ),
        AspectRatio(
          aspectRatio: 4 / 5,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Stack(
              fit: StackFit.expand,
              children: [
                hasImage
                    ? _ProductImage(source: cover!, fit: BoxFit.cover)
                    : Container(color: Colors.grey.shade200),
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: Colors.white,
                        child: Text(
                          'KO',
                          style: TextStyle(color: sellerRed),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Kariakoo Seller',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            resolvedCategory,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Story',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black87,
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          resolvedPrice,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          resolvedTitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          description.isEmpty
                              ? 'Describe your product or tell a story...'
                              : description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white12,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            modeLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white12,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.favorite_border,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Tap to like',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                    ),
                                  )
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (allowNegotiation)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: sellerGreen,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Text(
                                  'DM Offers Open',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({
    required this.source,
    this.fit = BoxFit.cover,
  });

  final String source;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (source.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: source,
        fit: fit,
      );
    }
    return Image.file(
      File(source),
      fit: fit,
    );
  }
}
