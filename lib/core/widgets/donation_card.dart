import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../models/donation_model.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../utils/image_codec.dart';
import 'status_chip.dart';

/// Listing card: photo (or placeholder), portions left and deadline are the
/// emphasised elements.
class DonationCard extends StatelessWidget {
  const DonationCard({super.key, required this.donation, this.onTap});

  final DonationModel donation;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final d = donation;
    final radius = BorderRadius.circular(16);
    final expired = d.isExpired;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: radius,
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: Stack(
                  children: [
                    DonationImage(url: d.imageUrl, height: 150),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: StatusChip(d.effectiveStatus),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${d.category} · ${d.providerLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.neutral),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.restaurant,
                            size: 16, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          '${d.reservablePortions} portions left',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary),
                        ),
                        const Spacer(),
                        Icon(Icons.schedule,
                            size: 16,
                            color: expired ? AppColors.red : AppColors.amber),
                        const SizedBox(width: 4),
                        Text(
                          timeLeft(d.pickupDeadline),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: expired ? AppColors.red : AppColors.slate,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.place_outlined,
                            size: 16, color: AppColors.neutral),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            d.pickupAddress,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: AppColors.neutral, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Food photo (stored `data:` URI or http URL) with a friendly placeholder.
class DonationImage extends StatefulWidget {
  const DonationImage({super.key, required this.url, this.height = 150});

  final String url;
  final double height;

  @override
  State<DonationImage> createState() => _DonationImageState();
}

class _DonationImageState extends State<DonationImage> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void didUpdateWidget(DonationImage old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) _decode();
  }

  /// Decode once per url, not on every rebuild.
  void _decode() => _bytes = decodeImageDataUri(widget.url);

  @override
  Widget build(BuildContext context) {
    final url = widget.url;
    final height = widget.height;
    final placeholder = Container(
      height: height,
      width: double.infinity,
      color: AppColors.mint,
      child: const Icon(Icons.fastfood, size: 48, color: AppColors.primary),
    );
    if (url.isEmpty) return placeholder;
    if (isDataUri(url)) {
      final bytes = _bytes;
      if (bytes == null) return placeholder;
      return Image.memory(
        bytes,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => placeholder,
      );
    }
    return Image.network(
      url,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => placeholder,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : placeholder,
    );
  }
}
