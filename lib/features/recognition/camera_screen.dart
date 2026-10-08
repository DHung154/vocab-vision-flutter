part of '../../main.dart';

// ─── Camera fullscreen ───────────────────────────────────────────────────────
class CameraScreen extends StatefulWidget {
  final AppState? appState;

  const CameraScreen({super.key, this.appState});
  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final _picker = ImagePicker();
  final _inference = const InferenceService();

  File? _pickedImage;
  bool _isSending = false;
  String? _error;
  int _inferenceGeneration = 0;
  final String _selectedModelId = defaultDemoModelId;

  /// Inference itself runs on the native worker, but its result must not
  /// navigate into a screen after the user has left Camera or chosen another
  /// image. Incrementing the generation invalidates that stale result.
  void cancelPendingInference() {
    _inferenceGeneration++;
    if (!mounted || !_isSending) return;
    setState(() => _isSending = false);
  }

  // ─── Chụp ảnh bằng camera ─────────────────────────────────────────────────
  Future<void> _takePhoto() async {
    try {
      final xFile = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (xFile == null) return; // người dùng hủy
      setState(() {
        _pickedImage = File(xFile.path);
        _error = null;
      });
    } catch (e) {
      setState(
        () => _error = 'Không thể mở camera. Hãy kiểm tra quyền truy cập.',
      );
    }
  }

  // ─── Chọn ảnh từ thư viện ─────────────────────────────────────────────────
  Future<void> _pickFromGallery() async {
    try {
      final xFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (xFile == null) return; // người dùng hủy
      setState(() {
        _pickedImage = File(xFile.path);
        _error = null;
      });
    } catch (e) {
      setState(
        () =>
            _error = 'Không thể mở thư viện ảnh. Hãy kiểm tra quyền truy cập.',
      );
    }
  }

  // ─── Gửi ảnh nhận diện ────────────────────────────────────────────────────
  Future<void> _sendForInference() async {
    if (_isSending || _pickedImage == null) return;
    final requestId = ++_inferenceGeneration;
    final image = _pickedImage!;
    setState(() {
      _isSending = true;
      _error = null;
    });
    try {
      final result = await _inference.predict(image, modelId: _selectedModelId);
      if (!mounted ||
          requestId != _inferenceGeneration ||
          image != _pickedImage) {
        return;
      }
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            imageFile: image,
            result: result,
            catalog: widget.appState?.catalog ?? const [],
            isFavorite: widget.appState == null
                ? null
                : (word) => widget.appState!.favoriteWords.contains(word.id),
            onToggleFavorite: widget.appState == null
                ? null
                : (word) => widget.appState!.toggleFavorite(word.id),
            onLearnWord: widget.appState == null
                ? null
                : (word) => _pushCatalogLesson(context, widget.appState!, word),
          ),
        ),
      );
      // Quay lại từ ResultScreen → reset để chụp tiếp
      if (mounted) setState(() => _pickedImage = null);
    } on InferenceException catch (e) {
      if (mounted && requestId == _inferenceGeneration) {
        setState(() => _error = e.message);
      }
    } catch (e) {
      if (mounted && requestId == _inferenceGeneration) {
        setState(() => _error = 'Lỗi không xác định: $e');
      }
    } finally {
      if (mounted && requestId == _inferenceGeneration) {
        setState(() => _isSending = false);
      }
    }
  }

  // ─── Chụp lại ─────────────────────────────────────────────────────────────
  void _retake() => setState(() {
    _inferenceGeneration++;
    _pickedImage = null;
    _error = null;
  });

  Widget _modelSelector({bool compact = false}) {
    final colors = context.vocabColors;
    return Semantics(
      container: true,
      label:
          'Mô hình nhận diện: YOLO26-S — E4, nhóm đề xuất. Chạy trực tiếp trên thiết bị, không cần Wi-Fi.',
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(compact ? 10 : 12),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mô hình nhận diện',
              style: t(11, w: FontWeight.w700, color: colors.textSecondary),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.offline_bolt_rounded,
                  size: 18,
                  color: colors.accentDark,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    demoModelOptions.single.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t(12, w: FontWeight.w800, color: colors.textPrimary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Chạy trực tiếp trên thiết bị • không cần Wi-Fi',
              style: t(10.5, w: FontWeight.w600, color: colors.textSecondary),
            ),
            if (!compact) ...[
              const SizedBox(height: 5),
              InkWell(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ResearchResultsScreen(),
                  ),
                ),
                child: Text(
                  'Xem kết quả thực nghiệm E4 →',
                  style: t(11.5, w: FontWeight.w700, color: colors.accentDark),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext ctx) {
    return Container(
      color: ctx.vocabColors.canvas,
      child: _pickedImage == null ? _buildPicker() : _buildPreview(),
    );
  }

  // ─── Trạng thái ban đầu: chụp / chọn ảnh ─────────────────────────────────
  Widget _buildPicker() => Stack(
    children: [
      Container(color: context.vocabColors.canvas),
      Positioned.fill(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(32, 16, 32, 16),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: math.max(0, constraints.maxHeight - 32),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon camera lớn
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [C.mint, C.mintLight],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: C.mint.withValues(alpha: 0.3),
                          blurRadius: 28,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.camera_alt_rounded,
                      size: 48,
                      color: context.vocabColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Nhận diện đồ dùng học tập',
                    textAlign: TextAlign.center,
                    style: t(20, w: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Chụp ảnh hoặc chọn ảnh từ thư viện\nđể nhận diện vật thể',
                    textAlign: TextAlign.center,
                    style: t(
                      13,
                      w: FontWeight.w500,
                      color: context.vocabColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _modelSelector(),
                  const SizedBox(height: 20),

                  // Nút chụp ảnh
                  PlayfulButton(
                    onPressed: _takePhoto,
                    text: 'Chụp ảnh',
                    icon: Icons.camera_alt_rounded,
                    variant: PlayfulButtonVariant.primary,
                    height: 54,
                  ),
                  const SizedBox(height: 12),

                  // Nút chọn từ thư viện
                  PlayfulButton(
                    onPressed: _pickFromGallery,
                    text: 'Chọn từ thư viện',
                    icon: Icons.photo_library_rounded,
                    variant: PlayfulButtonVariant.sky,
                    height: 52,
                  ),

                  // Lỗi (nếu có)
                  if (_error != null) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.vocabColors.errorSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: context.vocabColors.errorText.withValues(
                            alpha: 0.4,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
                            color: context.vocabColors.errorText,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: t(
                                12,
                                w: FontWeight.w600,
                                color: context.vocabColors.errorText,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  );

  // ─── Xem trước ảnh đã chụp/chọn ──────────────────────────────────────────
  Widget _buildPreview() {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Container(
      color: context.vocabColors.canvas,
      child: Column(
        children: [
          Expanded(
            child: Container(
              color: AppColors.bar,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  TweenAnimationBuilder<double>(
                    key: ValueKey<String>(_pickedImage!.path),
                    tween: Tween<double>(begin: 0.0, end: 1.0),
                    duration: reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    builder: (context, opacity, child) =>
                        Opacity(opacity: opacity, child: child),
                    child: DisplayImage(
                      image: FileImage(_pickedImage!),
                      fit: BoxFit.contain,
                    ),
                  ),
                  if (!reduceMotion)
                    TweenAnimationBuilder<double>(
                      key: ValueKey<String>('${_pickedImage!.path}_flash'),
                      tween: Tween<double>(begin: 0.6, end: 0.0),
                      duration: const Duration(milliseconds: 70),
                      curve: Curves.easeOut,
                      builder: (context, flash, _) {
                        if (flash <= 0.01) return const SizedBox.shrink();
                        return Container(
                          color: Colors.white.withValues(alpha: flash),
                        );
                      },
                    ),
                  Positioned(
                    top: 12,
                    left: 16,
                    right: 16,
                    child: _modelSelector(compact: true),
                  ),
                ],
              ),
            ),
          ),
          Material(
            color: context.vocabColors.surface,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
              child: Column(
                children: [
                  if (_error != null)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.vocabColors.errorSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: context.vocabColors.errorText.withValues(
                            alpha: 0.4,
                          ),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
                            color: context.vocabColors.errorText,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: t(
                                12,
                                w: FontWeight.w600,
                                color: context.vocabColors.errorText,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_isSending) ...[
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: CircularProgressIndicator(
                        color: context.vocabColors.accentDark,
                      ),
                    ),
                    Text(
                      'Đang nhận diện trên thiết bị…',
                      style: t(
                        14,
                        w: FontWeight.w700,
                        color: context.vocabColors.textPrimary,
                      ),
                    ),
                  ] else ...[
                    PlayfulButton(
                      onPressed: _sendForInference,
                      text: 'Sử dụng ảnh này',
                      icon: Icons.check_rounded,
                      variant: PlayfulButtonVariant.primary,
                      height: 54,
                    ),
                    const SizedBox(height: 12),
                    PlayfulButton(
                      onPressed: _retake,
                      text: 'Chụp lại',
                      icon: Icons.refresh_rounded,
                      variant: PlayfulButtonVariant.neutral,
                      height: 50,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
