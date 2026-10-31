import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/media_url.dart';
import '../../../core/utils/theme_context.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/photo_placeholder.dart';
import '../../../core/widgets/skeleton_layouts.dart';
import '../../../data/models/profile_photo.dart';
import '../../../data/repositories/repository_providers.dart';
import '../providers/photo_providers.dart';

class ProfilePhotosScreen extends ConsumerStatefulWidget {
  const ProfilePhotosScreen({super.key});

  @override
  ConsumerState<ProfilePhotosScreen> createState() =>
      _ProfilePhotosScreenState();
}

class _ProfilePhotosScreenState extends ConsumerState<ProfilePhotosScreen> {
  bool _busy = false;

  Future<void> _add() async {
    if (_busy) return;
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final bytes = await picked.readAsBytes();
      await ref
          .read(photoRepositoryProvider)
          .upload(
            bytes: bytes,
            filename: picked.name,
            contentType: picked.mimeType,
          );
      ref.read(photoRevisionProvider.notifier).bump();
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        AppFailure.from(error).message,
        type: AppSnackType.error,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(ProfilePhoto photo) async {
    if (_busy) return;
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Remove this photo?',
      message: 'It will no longer appear on your profile.',
      confirmLabel: 'Remove',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(photoRepositoryProvider).delete(photo.id);
      ref.read(photoRevisionProvider.notifier).bump();
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        AppFailure.from(error).message,
        type: AppSnackType.error,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reorder(
    List<ProfilePhoto> items,
    int oldIndex,
    int newIndex,
  ) async {
    if (_busy) return;
    var to = newIndex;
    if (to > oldIndex) to -= 1;
    final next = [...items];
    final moved = next.removeAt(oldIndex);
    next.insert(to, moved);
    setState(() => _busy = true);
    try {
      await ref.read(photoRepositoryProvider).reorder([
        for (final item in next) item.id,
      ]);
      ref.read(photoRevisionProvider.notifier).bump();
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        AppFailure.from(error).message,
        type: AppSnackType.error,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final photos = ref.watch(myPhotosProvider);

    return AppPage(
      appBar: const AppTopBar(title: 'Photos'),
      body: AsyncValueView<List<ProfilePhoto>>(
        value: photos,
        loading: const SkeletonList(),
        onRetry: () => ref.invalidate(myPhotosProvider),
        keepDataWhileReloading: true,
        isEmpty: (list) => list.isEmpty,
        empty: EmptyState(
          icon: AppIcons.camera,
          title: 'Add your photos',
          message: 'Up to six photos. JPEG, PNG or WebP, under 5 MB each.',
          actionLabel: 'Add a photo',
          onAction: _busy ? null : _add,
        ),
        data: (list) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageGutter,
                AppSpacing.md,
                AppSpacing.pageGutter,
                AppSpacing.sm,
              ),
              child: Text(
                'The first photo is your main picture. Drag to reorder.',
                style: context.text.bodyMedium?.copyWith(
                  color: context.palette.textMuted,
                ),
              ),
            ),
            Expanded(
              child: ReorderableListView.builder(
                padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                itemCount: list.length,
                onReorder: (oldIndex, newIndex) =>
                    _reorder(list, oldIndex, newIndex),
                itemBuilder: (context, index) {
                  final photo = list[index];
                  return _PhotoRow(
                    key: ValueKey(photo.id),
                    photo: photo,
                    index: index,
                    onDelete: _busy ? null : () => _delete(photo),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomBar: photos.maybeWhen(
        data: (list) => list.isEmpty || list.length >= 6
            ? null
            : Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pageGutter,
                  AppSpacing.sm,
                  AppSpacing.pageGutter,
                  AppSpacing.lg,
                ),
                child: AppButton(
                  label: 'Add a photo',
                  icon: AppIcons.add,
                  isLoading: _busy,
                  onPressed: _busy ? null : _add,
                ),
              ),
        orElse: () => null,
      ),
    );
  }
}

class _PhotoRow extends StatelessWidget {
  const _PhotoRow({
    super.key,
    required this.photo,
    required this.index,
    required this.onDelete,
  });

  final ProfilePhoto photo;
  final int index;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final image = profileImageProvider(photo.source);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pageGutter,
        vertical: AppSpacing.sm,
      ),
      leading: ClipRRect(
        borderRadius: AppRadii.borderMd,
        child: SizedBox.square(
          dimension: 72,
          child: image == null
              ? PhotoPlaceholder(seed: index)
              : Image(
                  image: image,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => PhotoPlaceholder(seed: index),
                ),
        ),
      ),
      title: Text(index == 0 ? 'Main photo' : 'Photo ${index + 1}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Remove photo',
            onPressed: onDelete,
            icon: const Icon(AppIcons.delete),
          ),
          ReorderableDragStartListener(
            index: index,
            child: const Icon(AppIcons.dragHandle, size: AppSizes.iconLg),
          ),
        ],
      ),
    );
  }
}
