import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/image_codec.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_dropdown.dart';
import '../../core/widgets/app_snack.dart';
import '../../core/widgets/date_time_field.dart';
import '../../core/widgets/donation_card.dart';
import '../../models/donation_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/donation_provider.dart';

/// Screen 4 - create, edit or publish a food donation.
class AddEditDonationScreen extends StatefulWidget {
  const AddEditDonationScreen({super.key, this.existing});

  /// Null when creating a new listing.
  final DonationModel? existing;

  @override
  State<AddEditDonationScreen> createState() => _AddEditDonationScreenState();
}

class _AddEditDonationScreenState extends State<AddEditDonationScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _portions;
  late final TextEditingController _address;
  late final TextEditingController _storage;
  late String _category;
  DateTime? _preparedAt;
  DateTime? _deadline;
  late final Set<String> _allergens;
  late final Set<String> _tags;
  /// Current photo as a stored `data:` URI (empty = no photo).
  late String _existingImageUrl;
  bool _safetyConfirmed = false;
  bool _busy = false;

  bool get _isEdit => widget.existing != null;
  bool get _isPublishedEdit =>
      widget.existing != null && widget.existing!.status != DonationStatus.draft;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final profile = context.read<AuthProvider>().profile;
    _title = TextEditingController(text: e?.title ?? '');
    _description = TextEditingController(text: e?.description ?? '');
    _portions = TextEditingController(text: e == null ? '' : '${e.totalPortions}');
    _address = TextEditingController(
        text: e?.pickupAddress ?? profile?.defaultPickupArea ?? '');
    _storage = TextEditingController(text: e?.storageInstructions ?? '');
    _category = (e != null && kCategories.contains(e.category))
        ? e.category
        : kCategories.first;
    _preparedAt = e?.preparedAt ?? DateTime.now();
    _deadline = e?.pickupDeadline;
    _allergens = {...?e?.allergens};
    _tags = {...?e?.dietaryTags};
    _existingImageUrl = e?.imageUrl ?? '';
    _safetyConfirmed = e?.safetyConfirmed ?? false;
  }

  @override
  void dispose() {
    for (final c in [_title, _description, _portions, _address, _storage]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        // Small + compressed: the photo is stored inside the Firestore document.
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 60,
      );
      if (picked == null) return;
      final encoded = encodeImageDataUri(await picked.readAsBytes());
      if (mounted) setState(() => _existingImageUrl = encoded);
    } on FormatException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } on ImageTooLargeException catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    } catch (_) {
      if (mounted) showSnack(context, 'Could not open the photo library.', error: true);
    }
  }

  Future<void> _submit({required bool publish}) async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      showSnack(context, 'Please fix the highlighted fields.', error: true);
      return;
    }
    if (publish && !_safetyConfirmed) {
      showSnack(context, 'Please confirm the food safety statement.', error: true);
      return;
    }
    final user = context.read<AuthProvider>().profile;
    if (user == null) return;
    final provider = context.read<DonationProvider>();
    final existing = widget.existing;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final status = publish ? DonationStatus.available : DonationStatus.draft;
    final model = DonationModel(
      id: existing?.id ?? '',
      providerId: user.uid,
      providerName: user.fullName,
      organizationName: user.organizationName,
      title: _title.text.trim(),
      description: _description.text.trim(),
      category: _category,
      totalPortions: int.parse(_portions.text.trim()),
      preparedAt: _preparedAt!,
      pickupDeadline: _deadline!,
      pickupAddress: _address.text.trim(),
      imageUrl: _existingImageUrl,
      allergens: _allergens.toList(),
      dietaryTags: _tags.toList(),
      storageInstructions: _storage.text.trim(),
      safetyConfirmed: _safetyConfirmed,
      status: status,
    );

    setState(() => _busy = true);
    try {
      if (existing == null) {
        await provider.create(model);
      } else {
        await provider.update(
          model,
          newStatus: (existing.status == DonationStatus.draft && publish)
              ? DonationStatus.available
              : null,
        );
      }
      navigator.pop();
      messenger.showSnackBar(SnackBar(
        content: Text(!publish
            ? 'Draft saved.'
            : _isPublishedEdit
                ? 'Listing updated.'
                : 'Donation published. Receivers can now see it.'),
      ));
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit donation' : 'Add food donation'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.mint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Only list food that is safe to eat. Give accurate preparation, '
                  'storage and allergen details. Never list spoiled, contaminated or recalled food.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(height: 16),
              _photoPicker(),
              const SizedBox(height: 16),
              TextFormField(
                controller: _title,
                textCapitalization: TextCapitalization.sentences,
                maxLength: 80,
                decoration: AppTheme.inputDecoration('Food title',
                    icon: Icons.fastfood_outlined),
                validator: Validators.title,
              ),
              const SizedBox(height: 4),
              TextFormField(
                controller: _description,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 3,
                decoration: AppTheme.inputDecoration('Description',
                    hint: 'What is it, how was it prepared?'),
                validator: Validators.description,
              ),
              const SizedBox(height: 16),
              AppDropdown<String>(
                label: 'Category',
                icon: Icons.category_outlined,
                value: _category,
                items: [
                  for (final c in kCategories)
                    DropdownMenuItem(value: c, child: Text(c)),
                ],
                onChanged: (v) => setState(() => _category = v ?? _category),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _portions,
                keyboardType: TextInputType.number,
                decoration: AppTheme.inputDecoration('Quantity (portions)',
                    icon: Icons.restaurant),
                validator: (v) => Validators.positiveInt(v,
                    max: 10000, field: 'Quantity'),
              ),
              const SizedBox(height: 16),
              DateTimeFormField(
                label: 'Prepared on',
                icon: Icons.soup_kitchen_outlined,
                initialValue: _preparedAt,
                lastDate: DateTime.now().add(const Duration(days: 1)),
                onChanged: (v) => _preparedAt = v,
                validator: (v) => Validators.preparedAt(v),
              ),
              const SizedBox(height: 16),
              DateTimeFormField(
                label: 'Safe collection deadline',
                icon: Icons.schedule,
                initialValue: _deadline,
                firstDate: DateTime.now(),
                onChanged: (v) => _deadline = v,
                validator: (v) => Validators.pickupDeadline(v, _preparedAt),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _address,
                textCapitalization: TextCapitalization.words,
                maxLines: 2,
                decoration: AppTheme.inputDecoration('Pickup address',
                    icon: Icons.place_outlined),
                validator: Validators.address,
              ),
              const SizedBox(height: 20),
              const Text('Allergens',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              const Text(
                'Select every allergen present. If you are not sure, choose '
                '"Unknown": do not leave it blank to imply the food is allergen free.',
                style: TextStyle(color: AppColors.neutral, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final a in kAllergens)
                    FilterChip(
                      label: Text(a),
                      selected: _allergens.contains(a),
                      selectedColor: AppColors.mint,
                      onSelected: (on) => setState(
                          () => on ? _allergens.add(a) : _allergens.remove(a)),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              const Text('Dietary tags (optional)',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final t in kDietaryTags)
                    FilterChip(
                      label: Text(t),
                      selected: _tags.contains(t),
                      selectedColor: AppColors.mint,
                      onSelected: (on) =>
                          setState(() => on ? _tags.add(t) : _tags.remove(t)),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _storage,
                maxLines: 2,
                decoration: AppTheme.inputDecoration(
                  'Storage & handling instructions',
                  hint: 'e.g. Keep refrigerated, eat within 3 hours',
                ),
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                value: _safetyConfirmed,
                onChanged: (v) => setState(() => _safetyConfirmed = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'I confirm this food is safe for donation and the information above is accurate.',
                  style: TextStyle(fontSize: 13.5),
                ),
              ),
              const SizedBox(height: 12),
              if (_isPublishedEdit)
                FilledButton(
                  onPressed: _busy ? null : () => _submit(publish: true),
                  child: _busyOr('Save changes'),
                )
              else ...[
                FilledButton(
                  onPressed: _busy ? null : () => _submit(publish: true),
                  child: _busyOr('Publish Donation'),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: _busy ? null : () => _submit(publish: false),
                  child: const Text('Save Draft'),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _busyOr(String label) => _busy
      ? const SizedBox(
          height: 22,
          width: 22,
          child: CircularProgressIndicator(
              strokeWidth: 2.5, color: AppColors.white))
      : Text(label);

  Widget _photoPicker() {
    final hasImage = _existingImageUrl.isNotEmpty;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: _pickImage,
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: hasImage
            ? Stack(
                fit: StackFit.expand,
                children: [
                  DonationImage(url: _existingImageUrl, height: 160),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: CircleAvatar(
                      backgroundColor: AppColors.white,
                      child: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () =>
                            setState(() => _existingImageUrl = ''),
                      ),
                    ),
                  ),
                ],
              )
            : const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_outlined,
                      size: 36, color: AppColors.primary),
                  SizedBox(height: 8),
                  Text('Add a photo (optional)'),
                  Text('JPG or PNG, up to 5 MB',
                      style:
                          TextStyle(color: AppColors.neutral, fontSize: 12)),
                ],
              ),
      ),
    );
  }
}
