import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

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
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _allowNegotiation = false;

  final ImagePicker _picker = ImagePicker();
  final List<String> _imagePaths = [];
  int _coverIndex = 0;
  bool _autoPrompted = false;
  bool _isPicking = false;

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
    _priceController.dispose();
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
              price: _priceController.text,
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
            _buildTextField(
              controller: _priceController,
              label: 'Price (TZS)',
              keyboardType: TextInputType.number,
              validator: (value) =>
                  value == null || value.isEmpty ? 'Required' : null,
            ),
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
                    onPressed: _previewProduct,
                    child: const Text('Preview'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saveProduct,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: sellerRed,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Share Product'),
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
            Text('Price: ${product.price.toStringAsFixed(0)} TZS'),
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
    final product = _buildProduct();
    await context.read<ProductProvider>().addProduct(product);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  ProductItem _buildProduct() {
    return ProductItem(
      id: const Uuid().v4(),
      title: _titleController.text,
      category: _categoryController.text,
      description: _descriptionController.text,
      price: double.tryParse(_priceController.text) ?? 0,
      stock: int.tryParse(_stockController.text) ?? 0,
      media: List<String>.from(_imagePaths),
      allowNegotiation: _allowNegotiation,
      status: ProductStatus.published,
      metrics: const ProductMetrics(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}

class _InstagramPreview extends StatelessWidget {
  const _InstagramPreview({
    required this.images,
    required this.coverIndex,
    required this.title,
    required this.price,
    required this.category,
    required this.description,
    required this.allowNegotiation,
    required this.onAddPhoto,
  });

  final List<String> images;
  final int coverIndex;
  final String title;
  final String price;
  final String category;
  final String description;
  final bool allowNegotiation;
  final VoidCallback onAddPhoto;

  @override
  Widget build(BuildContext context) {
    final resolvedTitle = title.isEmpty ? 'Fresh Kariakoo drop' : title.trim();
    final resolvedPrice = price.isEmpty ? 'Set price' : 'TZS $price';
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
