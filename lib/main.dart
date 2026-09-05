// ─────────────────────────────────────────────────────────────────────────────
// Vietnamese kids vocabulary app — Flutter port
//
// pubspec.yaml dependencies:
//   flutter: sdk: flutter
//
// Copy this file to lib/main.dart and run.
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'inference_service.dart';
import 'result_screen.dart';

void main() => runApp(const VocabApp());

// ─── Design tokens ───────────────────────────────────────────────────────────
class C {
  static const navy = Color(0xFF1A1A2E);
  static const mint = Color(0xFF66FFCC);
  static const mintLight = Color(0xFFAAFDE2);
  static const mintPale = Color(0xFFD6FFF4);
  static const indigo = Color(0xFF5B56F0);
  static const indigoMid = Color(0xFF8E8BFF);
  static const indigoSoft = Color(0xFFECEBFF);
  static const coral = Color(0xFFFF6B6B);
  static const coralSoft = Color(0xFFFFEEEE);
  static const amber = Color(0xFFFFBE38);
  static const amberSoft = Color(0xFFFFF7E0);
  static const orange = Color(0xFFFF9550);
  static const orangeSoft = Color(0xFFFFF2E8);
  static const lavender = Color(0xFFAB9EFF);
  static const purple = Color(0xFF7A4FBF);
  static const muted = Color(0xFF7C7C8E);
}

TextStyle t(
  double size, {
  FontWeight w = FontWeight.w700,
  Color color = C.navy,
  double? h,
}) => TextStyle(fontSize: size, fontWeight: w, color: color, height: h);

// ─── App root ────────────────────────────────────────────────────────────────
class VocabApp extends StatelessWidget {
  const VocabApp({super.key});
  @override
  Widget build(BuildContext c) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(scaffoldBackgroundColor: const Color(0xFFDDFCF5)),
    home: const Shell(),
  );
}

// ─── Shell (tab state + overlays) ────────────────────────────────────────────
class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int activeTab = 0;
  bool showMap = false;
  bool showSettings = false;

  bool get isCamera => activeTab == 2;
  bool get isProfile => activeTab == 4;
  bool get isHome => activeTab == 0;
  bool get isOverlay => showMap || showSettings;

  Widget _screen() {
    switch (activeTab) {
      case 0:
        return HomeScreen(onOpenMap: () => setState(() => showMap = true));
      case 1:
        return const VocabularyScreen();
      case 2:
        return const CameraScreen();
      case 3:
        return const AchievementsScreen();
      case 4:
        return ProfileScreen(
          onOpenSettings: () => setState(() => showSettings = true),
        );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext c) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final frameWidth = math.min(480.0, constraints.maxWidth);
            return Center(
              child: SizedBox(
                width: frameWidth,
                height: constraints.maxHeight,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(44),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [C.mint, C.mintLight, C.mintPale],
                      stops: [0.0, 0.55, 1.0],
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x2A000000),
                        offset: Offset(0, 32),
                        blurRadius: 80,
                      ),
                      BoxShadow(
                        color: Color(0x18000000),
                        offset: Offset(0, 4),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      Expanded(
                        child: Stack(
                          children: [
                            // Icon trang trí mờ ở nền (ẩn khi ở camera)
                            if (!isCamera)
                              const Positioned.fill(child: _BgDecor()),
                            // Header + main content
                            if (!isCamera && !isOverlay)
                              Padding(
                                padding: EdgeInsets.only(
                                  top: isProfile ? 0 : 56,
                                ),
                                child: _screen(),
                              ),
                            // Camera overlay
                            if (isCamera) const CameraScreen(),
                            // Map overlay
                            if (showMap)
                              LearningMapScreen(
                                onClose: () => setState(() => showMap = false),
                              ),
                            // Settings overlay
                            if (showSettings)
                              SettingsScreen(
                                onClose: () =>
                                    setState(() => showSettings = false),
                              ),
                            // Header (hide on camera/profile/overlay)
                            if (!isCamera && !isProfile && !isOverlay)
                              Positioned(
                                top: 44,
                                left: 16,
                                right: 16,
                                child: _header(),
                              ),
                          ],
                        ),
                      ),
                      // Navigation occupies its own layout space, so it cannot
                      // cover the last row of scrollable content.
                      if (!isOverlay)
                        BottomCutoutNav(
                          activeTab: activeTab,
                          onTabChange: (i) => setState(() => activeTab = i),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _header() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.62),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Colors.white.withValues(alpha: 0.62)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x14000000),
          offset: Offset(0, 4),
          blurRadius: 20,
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: [C.orange, C.coral]),
            boxShadow: [
              BoxShadow(
                color: Color(0x4DFF6B6B),
                offset: Offset(0, 4),
                blurRadius: 12,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            'B',
            style: t(20, w: FontWeight.w900, color: Colors.white),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Bo', style: t(18, w: FontWeight.w800)),
              Text(
                '5 ngày liên tiếp',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t(12, w: FontWeight.w600, color: C.muted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [C.mint, C.mintLight]),
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                color: Color(0x59A0FFDD),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('⭐', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Text('320', style: t(15, w: FontWeight.w800)),
            ],
          ),
        ),
      ],
    ),
  );
}

// ─── Home screen ─────────────────────────────────────────────────────────────
class HomeScreen extends StatelessWidget {
  final VoidCallback onOpenMap;
  const HomeScreen({super.key, required this.onOpenMap});

  static const _features = [
    ('📖', 'Từ vựng', C.amberSoft),
    ('🎮', 'Ôn tập', C.indigoSoft),
    ('🏆', 'Thành tích', C.coralSoft),
  ];

  @override
  Widget build(BuildContext c) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 68, 16, 24),
      children: [
        Row(
          children: _features.map((f) {
            final isMap = f.$2 == 'Ôn tập';
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: f == _features.last ? 0 : 10),
                child: GestureDetector(
                  onTap: isMap ? onOpenMap : null,
                  child: _glassPill(f.$1, f.$2, f.$3),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 14),
        _progressCard(),
        const SizedBox(height: 14),
        _wordsCard(),
        const SizedBox(height: 18),
        Text('Chọn chế độ học 🎯', style: t(16, w: FontWeight.w800)),
        const SizedBox(height: 12),
        _modesGrid(),
      ],
    );
  }

  // 4 ô trò chơi (chế độ học)
  static const _modes = [
    ('🃏', 'Flashcard', 'lật thẻ', [C.orange, C.coral]),
    ('🧩', 'Ghép hình', 'kéo thả', [C.indigoMid, C.indigo]),
    ('✏️', 'Điền từ', 'còn thiếu', [C.coral, Color(0xFFF15A4B)]),
    ('🎧', 'Nghe & chọn', 'chọn hình', [C.mint, Color(0xFF1FB9AA)]),
  ];

  Widget _modesGrid() => Column(
    children: [
      for (int i = 0; i < _modes.length; i += 2)
        Padding(
          padding: EdgeInsets.only(bottom: i + 2 < _modes.length ? 12 : 0),
          child: Row(
            children: [
              Expanded(child: _modeCard(_modes[i])),
              const SizedBox(width: 12),
              Expanded(child: _modeCard(_modes[i + 1])),
            ],
          ),
        ),
    ],
  );

  Widget _modeCard((String, String, String, List<Color>) m) => Container(
    height: 190,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(22),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: m.$4,
      ),
      boxShadow: [
        BoxShadow(
          color: m.$4.last.withValues(alpha: 0.35),
          offset: const Offset(0, 6),
          blurRadius: 16,
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(m.$1, style: const TextStyle(fontSize: 20)),
            ),
            const Text('⭐', style: TextStyle(fontSize: 16)),
          ],
        ),
        const Spacer(),
        Text(
          m.$2,
          style: t(16, w: FontWeight.w800, color: Colors.white),
        ),
        Text(
          m.$3,
          style: t(
            11,
            w: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            'Bắt đầu học',
            style: t(10.5, w: FontWeight.w700, color: Colors.white),
          ),
        ),
      ],
    ),
  );

  Widget _glassPill(String icon, String label, Color bg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: Colors.white.withValues(alpha: 0.62)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text(icon, style: const TextStyle(fontSize: 15)),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t(11.5, w: FontWeight.w800),
          ),
        ),
      ],
    ),
  );

  Widget _progressCard() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      gradient: const LinearGradient(colors: [C.indigo, C.indigoMid]),
      boxShadow: const [
        BoxShadow(
          color: Color(0x475B56F0),
          offset: Offset(0, 4),
          blurRadius: 20,
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Tiến độ hôm nay',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t(14, w: FontWeight.w800, color: Colors.white),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '7/10 từ',
              style: t(
                13,
                w: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 10,
            color: Colors.white.withValues(alpha: 0.22),
            child: FractionallySizedBox(
              widthFactor: 0.7,
              alignment: Alignment.centerLeft,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [C.amber, C.orange]),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _wordsCard() {
    const words = [
      ('🍎', 'Táo', 'Apple'),
      ('🐶', 'Chó', 'Dog'),
      ('📚', 'Sách', 'Book'),
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            offset: Offset(0, 4),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ôn hôm nay 📝', style: t(15, w: FontWeight.w800)),
          const SizedBox(height: 10),
          Row(
            children: words
                .map(
                  (w) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 4,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: C.mint.withValues(alpha: 0.35),
                            width: 1.5,
                          ),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFF5FFFC), Color(0xFFEAFFF6)],
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(w.$1, style: const TextStyle(fontSize: 24)),
                            const SizedBox(height: 4),
                            Text(w.$2, style: t(13, w: FontWeight.w800)),
                            Text(
                              w.$3,
                              style: t(10, w: FontWeight.w600, color: C.muted),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

// ─── Vocabulary ──────────────────────────────────────────────────────────────
class VocabularyScreen extends StatelessWidget {
  const VocabularyScreen({super.key});

  static const words = [
    ('🧮', 'Abacus', 'Bàn tính'),
    ('🎒', 'Backpack', 'Ba lô'),
    ('▱', 'Chalk', 'Phấn'),
    ('🟩', 'Chalkboard', 'Bảng phấn'),
    ('🖍️', 'Crayon', 'Bút sáp màu'),
    ('🥤', 'Cup', 'Cốc'),
    ('🧽', 'Eraser', 'Cục tẩy'),
    ('🧴', 'Glue stick', 'Hồ khô'),
    ('🪑', 'Kids chair', 'Ghế trẻ em'),
    ('📓', 'Notebook', 'Vở'),
    ('🖌️', 'Paintbrush', 'Cọ vẽ'),
    ('✏️', 'Pencil', 'Bút chì'),
    ('🔺', 'Pencil sharpener', 'Gọt bút chì'),
    ('📏', 'Ruler', 'Thước kẻ'),
    ('✂️', 'Scissors', 'Kéo'),
  ];

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 68, 16, 120),
    children: [
      Text('15 đồ dùng học tập', style: t(22, w: FontWeight.w900)),
      Text(
        'Tên tiếng Anh và nghĩa tiếng Việt',
        style: t(13, w: FontWeight.w600, color: C.muted),
      ),
      const SizedBox(height: 14),
      for (final word in words)
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.76),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white),
          ),
          child: Row(
            children: [
              Text(word.$1, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(word.$2, style: t(15, w: FontWeight.w800)),
                  Text(
                    word.$3,
                    style: t(12, w: FontWeight.w600, color: C.muted),
                  ),
                ],
              ),
            ],
          ),
        ),
    ],
  );
}

// ─── Camera fullscreen ───────────────────────────────────────────────────────
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});
  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final _picker = ImagePicker();
  final _inference = const InferenceService();

  File? _pickedImage;
  bool _isSending = false;
  String? _error;

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
    setState(() {
      _isSending = true;
      _error = null;
    });
    try {
      final result = await _inference.predict(_pickedImage!);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ResultScreen(imageFile: _pickedImage!, result: result),
        ),
      );
      // Quay lại từ ResultScreen → reset để chụp tiếp
      if (mounted) setState(() => _pickedImage = null);
    } on InferenceException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Lỗi không xác định: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  // ─── Chụp lại ─────────────────────────────────────────────────────────────
  void _retake() => setState(() {
    _pickedImage = null;
    _error = null;
  });

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext ctx) {
    return Container(
      color: const Color(0xFF0E0E1C),
      child: _pickedImage == null ? _buildPicker() : _buildPreview(),
    );
  }

  // ─── Trạng thái ban đầu: chụp / chọn ảnh ─────────────────────────────────
  Widget _buildPicker() => Stack(
    children: [
      // Nền gradient
      Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0E0E1C), Color(0xFF1A1A2E)],
          ),
        ),
      ),
      Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon camera lớn
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: [C.mint, C.mintLight]),
                  boxShadow: [
                    BoxShadow(
                      color: C.mint.withValues(alpha: 0.3),
                      blurRadius: 28,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.camera_alt_rounded,
                  size: 48,
                  color: C.navy,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Nhận diện đồ dùng học tập',
                textAlign: TextAlign.center,
                style: t(20, w: FontWeight.w800, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                'Chụp ảnh hoặc chọn ảnh từ thư viện\nđể nhận diện vật thể',
                textAlign: TextAlign.center,
                style: t(13, w: FontWeight.w500, color: Colors.white54),
              ),
              const SizedBox(height: 32),

              // Nút chụp ảnh
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _takePhoto,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: C.mint,
                    foregroundColor: C.navy,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.camera_alt_rounded, size: 22),
                  label: Text('Chụp ảnh', style: t(15, w: FontWeight.w800)),
                ),
              ),
              const SizedBox(height: 12),

              // Nút chọn từ thư viện
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: _pickFromGallery,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.photo_library_rounded, size: 22),
                  label: Text(
                    'Chọn từ thư viện',
                    style: t(15, w: FontWeight.w700, color: Colors.white),
                  ),
                ),
              ),

              // Lỗi (nếu có)
              if (_error != null) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: C.coral.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: C.coral.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: C.coral,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: t(12, w: FontWeight.w600, color: C.coral),
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
    ],
  );

  // ─── Xem trước ảnh đã chụp/chọn ──────────────────────────────────────────
  Widget _buildPreview() => Stack(
    children: [
      // Ảnh preview
      Positioned.fill(child: Image.file(_pickedImage!, fit: BoxFit.contain)),
      // Gradient overlay phía dưới
      Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        child: Container(
          height: 220,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Color(0xE60E0E1C)],
            ),
          ),
        ),
      ),
      // Các nút hành động
      Positioned(
        left: 24,
        right: 24,
        bottom: 100,
        child: Column(
          children: [
            // Lỗi (nếu có)
            if (_error != null) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: C.coral.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: C.coral.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: C.coral,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: t(12, w: FontWeight.w600, color: C.coral),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Loading hoặc nút
            if (_isSending) ...[
              const CircularProgressIndicator(color: C.mint),
              const SizedBox(height: 12),
              Text(
                'Đang nhận diện...',
                style: t(14, w: FontWeight.w700, color: Colors.white),
              ),
            ] else ...[
              // Nút "Sử dụng ảnh này"
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _sendForInference,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: C.mint,
                    foregroundColor: C.navy,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.check_rounded, size: 22),
                  label: Text(
                    'Sử dụng ảnh này',
                    style: t(15, w: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Nút "Chụp lại"
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: _retake,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 22),
                  label: Text(
                    'Chụp lại',
                    style: t(15, w: FontWeight.w700, color: Colors.white),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ],
  );
}

// ─── Profile screen ──────────────────────────────────────────────────────────
class ProfileScreen extends StatelessWidget {
  final VoidCallback? onOpenSettings;
  const ProfileScreen({super.key, this.onOpenSettings});
  static const _stats = [
    ('🔥', '5', 'Ngày streak', C.orange, C.orangeSoft),
    ('🏆', '12', 'Thành tích', C.indigo, C.indigoSoft),
    ('📚', '48', 'Màn đã học', C.mint, C.mintPale),
  ];
  static const _ach = [
    (
      '🌟',
      'Học liên tiếp 5 ngày',
      'Không nghỉ ngày nào!',
      C.amber,
      C.amberSoft,
    ),
    ('🐣', 'Từ vựng đầu tiên', 'Học được 10 từ mới', C.mint, C.mintPale),
    (
      '🚀',
      'Tốc độ siêu nhanh',
      'Hoàn thành trong 1 phút',
      C.indigo,
      C.indigoSoft,
    ),
    ('💯', 'Điểm tuyệt đối', 'Trả lời đúng 100% một màn', C.coral, C.coralSoft),
    ('📚', 'Mọt sách nhí', 'Học đủ 100 từ vựng', C.mint, C.mintPale),
    ('🦉', 'Cú đêm chăm chỉ', 'Học bài sau 22:00', C.purple, C.indigoSoft),
    ('🎯', 'Xạ thủ từ vựng', 'Đúng 50 từ không sai', C.orange, C.orangeSoft),
    ('👑', 'Nhà vô địch tuần', 'Đứng top bảng xếp hạng', C.amber, C.amberSoft),
  ];
  @override
  Widget build(BuildContext ctx) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 56, 16, 120),
    children: [
      Align(
        alignment: Alignment.centerRight,
        child: GestureDetector(
          onTap: onOpenSettings,
          child: Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0x1A000000),
                  blurRadius: 12,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.settings, size: 20, color: C.navy),
          ),
        ),
      ),
      const SizedBox(height: 8),
      // avatar
      Center(
        child: Column(
          children: [
            Container(
              width: 100,
              height: 100,
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [C.mint, C.orange]),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x6666FFCC),
                    offset: Offset(0, 6),
                    blurRadius: 28,
                  ),
                ],
              ),
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [C.orange, C.coral]),
                ),
                alignment: Alignment.center,
                child: Text(
                  'B',
                  style: t(40, w: FontWeight.w900, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text('Bo', style: t(22, w: FontWeight.w900)),
            Text(
              'Người học chăm chỉ 🌟',
              style: t(13, w: FontWeight.w600, color: C.muted),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      // stats
      Row(
        children: _stats
            .map(
              (s) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(color: Color(0x0A000000), blurRadius: 20),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: s.$5,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            s.$1,
                            style: const TextStyle(fontSize: 22),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(s.$2, style: t(22, w: FontWeight.w900)),
                        Text(
                          s.$3,
                          style: t(11, w: FontWeight.w700, color: C.muted),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
      const SizedBox(height: 20),
      Text('Thành tích gần đây 🏅', style: t(15, w: FontWeight.w800)),
      const SizedBox(height: 12),
      ..._ach.map(
        (a) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(color: Color(0x0F000000), blurRadius: 14),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: a.$5,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Text(a.$1, style: const TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.$2, style: t(13, w: FontWeight.w800)),
                      Text(
                        a.$3,
                        style: t(11, w: FontWeight.w600, color: C.muted),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: a.$4, size: 20),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}

// ─── Bottom Nav (cutout notch) ───────────────────────────────────────────────
class BottomCutoutNav extends StatelessWidget {
  final int activeTab;
  final ValueChanged<int> onTabChange;
  const BottomCutoutNav({
    super.key,
    required this.activeTab,
    required this.onTabChange,
  });

  static const _labels = [
    'Trang chủ',
    'Từ vựng',
    'Camera',
    'Thành tích',
    'Hồ sơ',
  ];
  static const _icons = [
    Icons.home_rounded,
    Icons.menu_book_rounded,
    Icons.camera_alt_rounded,
    Icons.emoji_events_rounded,
    Icons.person_rounded,
  ];

  @override
  Widget build(BuildContext c) {
    const barH = 68.0;
    return SizedBox(
      height: barH + 12,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // bar with notch
          Positioned.fill(child: CustomPaint(painter: _NavBarPainter())),
          // labels + icons
          Positioned(
            top: 8,
            left: 0,
            right: 0,
            bottom: 0,
            child: Row(
              children: List.generate(5, (i) {
                final active = i == activeTab;
                final isCam = i == 2;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => onTabChange(i),
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (!isCam)
                          Icon(
                            _icons[i],
                            size: 22,
                            color: active
                                ? C.navy
                                : C.navy.withValues(alpha: 0.42),
                          ),
                        if (!isCam) const SizedBox(height: 3),
                        Text(
                          _labels[i],
                          style: t(
                            active ? 11 : 10,
                            w: active ? FontWeight.w800 : FontWeight.w700,
                            color: isCam
                                ? C.navy
                                : (active
                                      ? C.navy
                                      : C.navy.withValues(alpha: 0.55)),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
          // camera bubble (fixed at center)
          Positioned(
            top: 0,
            left: 375 / 2 - 29,
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(colors: [C.mint, C.mintLight]),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.72),
                  width: 1.5,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x8C66FFCC),
                    offset: Offset(0, 6),
                    blurRadius: 22,
                  ),
                  BoxShadow(
                    color: Color(0x1A000000),
                    offset: Offset(0, 2),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: GestureDetector(
                onTap: () => onTabChange(2),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  color: C.navy,
                  size: 30,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavBarPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    const notchCx = 375 / 2;
    const depth = 38.0, spread = 44.0;
    final barTop = s.height - 68;
    final path = Path()
      ..moveTo(0, barTop)
      ..lineTo(notchCx - spread, barTop)
      ..cubicTo(
        notchCx - spread + 18,
        barTop,
        notchCx - 16,
        barTop + depth,
        notchCx,
        barTop + depth,
      )
      ..cubicTo(
        notchCx + 16,
        barTop + depth,
        notchCx + spread - 18,
        barTop,
        notchCx + spread,
        barTop,
      )
      ..lineTo(s.width, barTop)
      ..lineTo(s.width, s.height)
      ..lineTo(0, s.height)
      ..close();
    // shadow
    c.drawShadow(path, Colors.black.withValues(alpha: 0.12), 12, false);
    // fill
    c.drawPath(path, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ─── Learning Map (3D isometric) ─────────────────────────────────────────────
class LMNode {
  final int id;
  final String theme, emoji, state;
  final double x, y;
  final Color g1, g2, s1, s2;
  const LMNode(
    this.id,
    this.theme,
    this.emoji,
    this.state,
    this.x,
    this.y,
    this.g1,
    this.g2,
    this.s1,
    this.s2,
  );
}

const List<LMNode> _nodes = [
  LMNode(
    1,
    'Làm quen',
    '👋',
    'done',
    248,
    1730,
    Color(0xFFFF9550),
    Color(0xFFFFBE38),
    Color(0xFFC85500),
    Color(0xFFC8800A),
  ),
  LMNode(
    2,
    'Bàn học',
    '✏️',
    'done',
    110,
    1510,
    Color(0xFFFF6B6B),
    Color(0xFFFF9550),
    Color(0xFFC83030),
    Color(0xFFC85500),
  ),
  LMNode(
    3,
    'Sách và vở',
    '📚',
    'done',
    262,
    1300,
    Color(0xFF6C63FF),
    Color(0xFF9C8FFF),
    Color(0xFF3A34C0),
    Color(0xFF5A54D0),
  ),
  LMNode(
    4,
    '15 đồ dùng học tập',
    '🎒',
    'active',
    110,
    1070,
    Color(0xFF66FFCC),
    Color(0xFF00E5AA),
    Color(0xFF00A070),
    Color(0xFF00C090),
  ),
  LMNode(
    5,
    'Luyện nghe',
    '🎧',
    'locked',
    262,
    840,
    Color(0xFFB0BEC5),
    Color(0xFF90A4AE),
    Color(0xFF708090),
    Color(0xFF808898),
  ),
  LMNode(
    6,
    'Ghép từ',
    '🧩',
    'locked',
    110,
    605,
    Color(0xFFB0BEC5),
    Color(0xFF90A4AE),
    Color(0xFF708090),
    Color(0xFF808898),
  ),
  LMNode(
    7,
    'Nhận diện bằng ảnh',
    '📷',
    'locked',
    262,
    400,
    Color(0xFFB0BEC5),
    Color(0xFF90A4AE),
    Color(0xFF708090),
    Color(0xFF808898),
  ),
  LMNode(
    8,
    'Kiểm tra cuối',
    '🏆',
    'locked',
    188,
    205,
    Color(0xFFB0BEC5),
    Color(0xFF90A4AE),
    Color(0xFF708090),
    Color(0xFF808898),
  ),
];

class LearningMapScreen extends StatelessWidget {
  final VoidCallback onClose;
  const LearningMapScreen({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFF4FFFB), Color(0xFFE8F4FF)],
      ),
    ),
    child: Column(
      children: [
        Container(
          height: 70,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            boxShadow: const [
              BoxShadow(
                color: Color(0x17000000),
                offset: Offset(0, 2),
                blurRadius: 16,
              ),
            ],
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: onClose,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: C.navy.withValues(alpha: 0.07),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.chevron_left,
                    size: 22,
                    color: C.navy,
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text('Lộ trình học', style: t(18, w: FontWeight.w900)),
                ),
              ),
              _pill('⭐', '320', const Color(0xFFFFF7E0), C.navy),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              _progressSummary(),
              const SizedBox(height: 18),
              Text('Các chặng học', style: t(16, w: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(
                'Hoàn thành từng chặng để mở khóa bài tiếp theo.',
                style: t(12, w: FontWeight.w600, color: C.muted),
              ),
              const SizedBox(height: 14),
              for (var i = 0; i < _nodes.length; i++) ...[
                _lessonTile(context, _nodes[i]),
                if (i < _nodes.length - 1)
                  Container(
                    width: 3,
                    height: 12,
                    margin: const EdgeInsets.only(left: 31),
                    color: _nodes[i].state == 'done'
                        ? C.mint
                        : const Color(0xFFD8DCE5),
                  ),
              ],
            ],
          ),
        ),
      ],
    ),
  );

  Widget _progressSummary() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(22),
      gradient: const LinearGradient(colors: [C.indigo, C.indigoMid]),
      boxShadow: const [
        BoxShadow(
          color: Color(0x335B56F0),
          offset: Offset(0, 8),
          blurRadius: 22,
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Bạn đã hoàn thành 3/8 chặng',
                style: t(14, w: FontWeight.w800, color: Colors.white),
              ),
            ),
            Text(
              '38%',
              style: t(14, w: FontWeight.w900, color: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: 3 / 8,
            minHeight: 9,
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation(C.amber),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Chặng tiếp theo: 15 đồ dùng học tập',
          style: t(12, w: FontWeight.w600, color: Colors.white70),
        ),
      ],
    ),
  );

  Widget _lessonTile(BuildContext context, LMNode node) {
    final done = node.state == 'done';
    final active = node.state == 'active';
    final color = active ? C.indigo : (done ? C.mint : const Color(0xFFB8BEC9));
    final subtitle = done
        ? 'Đã hoàn thành'
        : active
        ? 'Đang học • 8/15 từ'
        : 'Hoàn thành chặng trước để mở khóa';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: active
            ? () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Mở bài học 15 đồ dùng học tập')),
              )
            : null,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: active ? C.indigoSoft : Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: active ? C.indigo.withValues(alpha: 0.35) : Colors.white,
              width: active ? 2 : 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x10000000),
                offset: Offset(0, 4),
                blurRadius: 14,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: done || active ? 0.18 : 0.12),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  node.state == 'locked' ? '🔒' : node.emoji,
                  style: const TextStyle(fontSize: 23),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Chặng ${node.id} • ${node.theme}',
                      style: t(14, w: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: t(11.5, w: FontWeight.w600, color: C.muted),
                    ),
                  ],
                ),
              ),
              if (done)
                const Icon(Icons.check_circle_rounded, color: Color(0xFF16A37A))
              else if (active)
                const Icon(Icons.arrow_forward_rounded, color: C.indigo),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill(String e, String v, Color bg, Color col) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(e, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 4),
        Text(
          v,
          style: t(13, w: FontWeight.w800, color: col),
        ),
      ],
    ),
  );
  Widget _resPill(String e, String v, Color bg) => Container(
    width: 68,
    height: 30,
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(15),
      boxShadow: [
        BoxShadow(
          color: bg.withValues(alpha: 0.4),
          offset: const Offset(0, 3),
          blurRadius: 10,
        ),
      ],
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(e, style: const TextStyle(fontSize: 13)),
        const SizedBox(width: 5),
        Text(
          v,
          style: t(12, w: FontWeight.w700, color: Colors.white),
        ),
      ],
    ),
  );

  Widget _activeCard(LMNode n) => Container(
    width: 224,
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.97),
      borderRadius: BorderRadius.circular(22),
      boxShadow: const [
        BoxShadow(
          color: Color(0x2E000000),
          offset: Offset(0, 10),
          blurRadius: 36,
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('${n.emoji} ${n.theme}', style: t(14, w: FontWeight.w800)),
        const SizedBox(height: 3),
        Text(
          '12 từ vựng · ⭐ +50 điểm',
          style: t(11, w: FontWeight.w600, color: C.muted),
        ),
        const SizedBox(height: 12),
        Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(colors: [C.coral, C.orange]),
            boxShadow: const [
              BoxShadow(
                color: Color(0x80FF6B6B),
                offset: Offset(0, 5),
                blurRadius: 16,
              ),
            ],
          ),
          child: Text(
            'BẮT ĐẦU HỌC! →',
            style: t(13, w: FontWeight.w900, color: Colors.white),
          ),
        ),
      ],
    ),
  );

  List<Widget> _rewards() {
    const rewards = [
      ('⭐', 190, 1620, -15.0),
      ('💎', 192, 1405, 12.0),
      ('🎁', 193, 1185, -8.0),
      ('⭐', 188, 955, 20.0),
      ('💎', 188, 718, -10.0),
      ('🎁', 186, 502, 15.0),
      ('⭐', 220, 298, -12.0),
    ];
    return rewards
        .map(
          (r) => Positioned(
            left: r.$2 - 13,
            top: r.$3 - 13,
            child: Transform.rotate(
              angle: r.$4 * math.pi / 180,
              child: Text(r.$1, style: const TextStyle(fontSize: 22)),
            ),
          ),
        )
        .toList();
  }
}

class _ZLabel extends StatelessWidget {
  final String label;
  final Color color;
  const _ZLabel(this.label, this.color);
  @override
  Widget build(BuildContext c) => Text(
    label,
    style: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w800,
      color: color,
      shadows: const [
        Shadow(color: Color(0x4D000000), offset: Offset(0, 1), blurRadius: 3),
      ],
    ),
  );
}

// ─── Hex node widget with 3D pillar ──────────────────────────────────────────
class _HexNodeWidget extends StatelessWidget {
  final LMNode node;
  final double pulse;
  const _HexNodeWidget({required this.node, required this.pulse});
  @override
  Widget build(BuildContext c) {
    final isActive = node.state == 'active';
    final isDone = node.state == 'done';
    final isLocked = node.state == 'locked';
    return SizedBox(
      width: 90,
      height: 110,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // pulse rings
          if (isActive) ...[
            Positioned(
              top: -6,
              left: -6,
              child: Opacity(
                opacity: 1 - (pulse * 0.5),
                child: Transform.scale(
                  scale: 1 + pulse * 0.15,
                  child: Container(
                    width: 102,
                    height: 102,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: C.mint.withValues(alpha: 0.65),
                        width: 2.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: -14,
              left: -14,
              child: Opacity(
                opacity: 1 - (((pulse + 0.14) % 1) * 0.5),
                child: Container(
                  width: 118,
                  height: 118,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: C.mint.withValues(alpha: 0.42),
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
            // bounce arrow
            Positioned(
              top: -34 + math.sin(pulse * math.pi * 2) * 5,
              left: 30,
              child: const Text('👆', style: TextStyle(fontSize: 18)),
            ),
          ],
          // hex pillar
          Positioned.fill(child: CustomPaint(painter: _HexPainter(node))),
          // emoji
          Positioned(
            top: 22,
            left: 0,
            right: 12,
            child: Text(
              isLocked ? '🔒' : node.emoji,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24),
            ),
          ),
          // gold star badge for done
          if (isDone)
            Positioned(
              top: -2,
              right: 6,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFE44D), Color(0xFFFF9800)],
                  ),
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x99FF9600),
                      offset: Offset(0, 2),
                      blurRadius: 8,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const Text('⭐', style: TextStyle(fontSize: 12)),
              ),
            ),
        ],
      ),
    );
  }
}

class _HexPainter extends CustomPainter {
  final LMNode node;
  _HexPainter(this.node);
  static const double r = 32, isoSx = 12, isoSy = 20;

  List<Offset> _hex(
    double cx,
    double cy,
    double R, {
    double ox = 0,
    double oy = 0,
  }) => List.generate(6, (i) {
    final a = math.pi / 3 * i - math.pi / 2;
    return Offset(cx + ox + R * math.cos(a), cy + oy + R * math.sin(a));
  });

  Path _poly(List<Offset> v) {
    final p = Path()..moveTo(v[0].dx, v[0].dy);
    for (var i = 1; i < v.length; i++) p.lineTo(v[i].dx, v[i].dy);
    p.close();
    return p;
  }

  @override
  void paint(Canvas c, Size s) {
    final cx = s.width / 2 - 6, cy = s.height / 2 - 5;
    final top = _hex(cx, cy, r);
    final bot = _hex(cx, cy, r, ox: isoSx, oy: isoSy);
    final isLocked = node.state == 'locked';

    // drop shadow
    c.drawPath(
      _poly(bot.map((p) => Offset(p.dx + 2, p.dy + 4)).toList()),
      Paint()
        ..color = Colors.black26
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Side faces — for pairs (1,2)(2,3)(3,4)(4,5)
    final sideColor = isLocked ? const Color(0xFF708090) : node.s1;
    final sideColor2 = isLocked ? const Color(0xFF808898) : node.s2;
    final faceIdx = [
      [1, 2, 0.65],
      [2, 3, 0.50],
      [3, 4, 0.40],
      [4, 5, 0.55],
    ];
    for (final f in faceIdx) {
      final i = f[0] as int, j = f[1] as int;
      final quad = [top[i], top[j], bot[j], bot[i]];
      final col = Color.lerp(sideColor, sideColor2, (f[2] as double))!;
      c.drawPath(_poly(quad), Paint()..color = col);
    }

    // Top face
    final topPaint = Paint()
      ..shader = LinearGradient(
        colors: isLocked
            ? const [Color(0xFFB0BEC5), Color(0xFF90A4AE)]
            : [node.g1, node.g2],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));
    c.drawPath(_poly(top), topPaint);

    // Top face border
    c.drawPath(
      _poly(top),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = node.state == 'active'
            ? Colors.white.withValues(alpha: 0.95)
            : (isLocked
                  ? Colors.white24
                  : Colors.white.withValues(alpha: 0.75)),
    );

    // Shine overlay
    if (!isLocked) {
      c.drawPath(
        _poly(top),
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x73FFFFFF), Color(0x0DFFFFFF), Color(0x1A000000)],
            stops: [0.0, 0.55, 1.0],
          ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r)),
      );
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ─── Main map background painter (zones + iso tiles + path + cliffs) ────────
class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    _drawZone(c, 0, 500, const [
      Color(0xFF4A8FD4),
      Color(0xFF6EB4E8),
      Color(0xFFA8D8F0),
      Color(0xFFC8EAF8),
    ]);
    _drawZone(c, 500, 700, const [
      Color(0xFF52B840),
      Color(0xFF44A032),
      Color(0xFF35882A),
    ]);
    _drawZone(c, 1200, 400, const [
      Color(0xFF0090C0),
      Color(0xFF0070A0),
      Color(0xFF004E80),
    ]);
    _drawZone(c, 1600, 400, const [
      Color(0xFF6B4018),
      Color(0xFF4E2C10),
      Color(0xFF2A1408),
    ]);

    _isoTiles(c, 0, 500, const Color(0xFF7EC8F0), const Color(0xFF6BB8E4));
    _isoTiles(c, 500, 1200, const Color(0xFF4CAE38), const Color(0xFF56C040));
    _isoTiles(c, 1200, 1600, const Color(0xFF0080B0), const Color(0xFF0070A0));
    _isoTiles(c, 1600, 2000, const Color(0xFF5A3A12), const Color(0xFF4A2C0A));

    _cliff(
      c,
      500,
      const Color(0xFF2A6018),
      const Color(0xFF3A8028),
      const Color(0xFF52A840),
    );
    _cliff(
      c,
      1200,
      const Color(0xFF004470),
      const Color(0xFF006090),
      const Color(0xFF0090C0),
    );
    _cliff(
      c,
      1600,
      const Color(0xFF3E2010),
      const Color(0xFF6B4018),
      const Color(0xFF8B5A2A),
    );

    _drawPath(c);
  }

  void _drawZone(Canvas c, double y, double h, List<Color> colors) {
    final rect = Rect.fromLTWH(0, y, 375, h);
    c.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ).createShader(rect),
    );
  }

  void _isoTiles(Canvas c, double y0, double y1, Color light, Color dark) {
    const tw = 40.0, th = 20.0;
    final paintL = Paint()..color = light.withValues(alpha: 0.22);
    final paintD = Paint()..color = dark.withValues(alpha: 0.22);
    for (double y = y0; y < y1 + th; y += th) {
      for (double x = -tw; x < 375 + tw; x += tw) {
        final ox = ((y / th) % 2 == 0) ? 0.0 : tw / 2;
        final cx = x + ox, cy = y;
        final path = Path()
          ..moveTo(cx, cy - th / 2)
          ..lineTo(cx + tw / 2, cy)
          ..lineTo(cx, cy + th / 2)
          ..lineTo(cx - tw / 2, cy)
          ..close();
        c.drawPath(path, ((x + y) / tw).round() % 2 == 0 ? paintL : paintD);
      }
    }
  }

  void _cliff(Canvas c, double y, Color c1, Color c2, Color c3) {
    // Layer 1 (deepest)
    final p1 = Path()
      ..moveTo(0, y - 22)
      ..cubicTo(80, y - 18, 200, y - 26, 375, y - 20)
      ..lineTo(375, y + 30)
      ..lineTo(0, y + 30)
      ..close();
    c.drawPath(p1, Paint()..color = c1);
    // Layer 2
    final p2 = Path()
      ..moveTo(0, y - 12)
      ..cubicTo(90, y - 8, 200, y - 16, 375, y - 10)
      ..lineTo(375, y + 30)
      ..lineTo(0, y + 30)
      ..close();
    c.drawPath(p2, Paint()..color = c2);
    // Layer 3 (top rim)
    final p3 = Path()
      ..moveTo(0, y - 4)
      ..cubicTo(90, y, 200, y - 8, 375, y - 2)
      ..lineTo(375, y + 30)
      ..lineTo(0, y + 30)
      ..close();
    c.drawPath(p3, Paint()..color = c3);
  }

  void _drawPath(Canvas c) {
    final path = _parsePath();
    // shadow
    c.save();
    c.translate(8, 16);
    c.drawPath(
      path,
      Paint()
        ..color = const Color(0x40000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 54
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    c.restore();
    // road wall
    c.save();
    c.translate(8, 14);
    c.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF8B6010)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 50
        ..strokeCap = StrokeCap.round,
    );
    c.restore();
    // road surface
    c.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFFFF8E7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 44
        ..strokeCap = StrokeCap.round,
    );
    // dashed centerline
    final dashPaint = Paint()
      ..color = const Color(0xFFFFD93D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    _dashPath(c, path, dashPaint, dash: 14, gap: 12);
  }

  void _dashPath(
    Canvas c,
    Path p,
    Paint pt, {
    double dash = 10,
    double gap = 6,
  }) {
    for (final metric in p.computeMetrics()) {
      double d = 0;
      while (d < metric.length) {
        c.drawPath(metric.extractPath(d, d + dash), pt);
        d += dash + gap;
      }
    }
  }

  Path _parsePath() {
    // Handcoded from PATH_D string
    return Path()
      ..moveTo(248, 1730)
      ..cubicTo(195, 1630, 155, 1600, 110, 1510)
      ..cubicTo(65, 1420, 228, 1368, 262, 1300)
      ..cubicTo(296, 1232, 162, 1120, 110, 1070)
      ..cubicTo(58, 1020, 238, 882, 262, 840)
      ..cubicTo(286, 798, 155, 648, 110, 605)
      ..cubicTo(65, 562, 262, 447, 262, 400)
      ..cubicTo(262, 352, 216, 262, 188, 205);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ─── Icon trang trí mờ ở nền ─────────────────────────────────────────────────
class _BgDecor extends StatelessWidget {
  const _BgDecor();

  // (emoji, left%, top%, size, opacity, xoay)
  static const _items = [
    ('🍎', 0.08, 0.10, 34.0, 0.14, -0.2),
    ('🐶', 0.80, 0.08, 38.0, 0.13, 0.2),
    ('📚', 0.85, 0.30, 32.0, 0.12, 0.1),
    ('⭐', 0.14, 0.32, 26.0, 0.16, -0.3),
    ('🎈', 0.05, 0.55, 30.0, 0.12, 0.15),
    ('🧩', 0.82, 0.55, 30.0, 0.12, -0.15),
    ('🌈', 0.10, 0.78, 34.0, 0.12, 0.1),
    ('🎧', 0.78, 0.76, 30.0, 0.13, -0.2),
    ('🐱', 0.45, 0.16, 24.0, 0.12, 0.2),
    ('✏️', 0.50, 0.62, 26.0, 0.12, -0.1),
  ];

  @override
  Widget build(BuildContext c) => IgnorePointer(
    child: LayoutBuilder(
      builder: (_, box) {
        return Stack(
          children: [
            for (final it in _items)
              Positioned(
                left: box.maxWidth * it.$2,
                top: box.maxHeight * it.$3,
                child: Opacity(
                  opacity: it.$5,
                  child: Transform.rotate(
                    angle: it.$6,
                    child: Text(it.$1, style: TextStyle(fontSize: it.$4)),
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}

// ─── Màn Cài đặt (bổ sung, khớp thiết kế Figma) ──────────────────────────────
class SettingsScreen extends StatefulWidget {
  final VoidCallback onClose;
  const SettingsScreen({super.key, required this.onClose});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int direction = 0; // VN→GB / GB→VN
  int difficulty = 1; // Dễ / Vừa / Khó
  int goal = 1; // 5 / 10 / 20
  bool soundFx = true;
  bool bgMusic = true;
  double volume = 0.7;
  bool vibrate = true;
  bool notify = true;
  bool dailyReminder = true;
  bool darkMode = false;
  int themeColor = 0; // mint

  static const _swatches = [C.mint, C.indigo, C.coral, C.amber, C.lavender];
  static const _swatchNames = ['Mint', 'Indigo', 'Coral', 'Amber', 'Lavender'];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [C.mint, C.mintLight, C.mintPale],
          stops: [0, 0.55, 1],
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _header(),
            const SizedBox(height: 18),
            _profileCard(),
            const SizedBox(height: 20),

            _label('HỌC TẬP'),
            _tile(
              '🌐',
              C.indigo,
              C.indigoSoft,
              'Ngôn ngữ',
              'Chọn hướng học từ vựng',
              _segmented(
                ['VN→GB', 'GB→VN'],
                direction,
                (i) => setState(() => direction = i),
              ),
            ),
            _tile(
              '🎯',
              C.coral,
              C.coralSoft,
              'Độ khó',
              'Ảnh hưởng gợi ý và số nghĩa',
              _segmented(
                ['Dễ', 'Vừa', 'Khó'],
                difficulty,
                (i) => setState(() => difficulty = i),
              ),
            ),
            _tile(
              '📗',
              C.mint,
              C.mintPale,
              'Mục tiêu mỗi ngày',
              'Học 10 từ vựng / ngày',
              _segmented(
                ['5', '10', '20'],
                goal,
                (i) => setState(() => goal = i),
              ),
            ),

            const SizedBox(height: 6),
            _label('ÂM THANH'),
            _tile(
              '🔊',
              C.orange,
              C.orangeSoft,
              'Hiệu ứng âm thanh',
              'Tiếng khi bấm và trả lời',
              _switch(soundFx, (v) => setState(() => soundFx = v), C.orange),
            ),
            _tile(
              '🎵',
              C.indigo,
              C.indigoSoft,
              'Nhạc nền',
              'Nhạc êm dịu khi học',
              _switch(bgMusic, (v) => setState(() => bgMusic = v), C.indigo),
            ),
            _tile(
              '🎚️',
              C.mint,
              C.mintPale,
              'Âm lượng',
              '',
              SizedBox(
                width: 140,
                child: Row(
                  children: [
                    const Text('🔉', style: TextStyle(fontSize: 14)),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 5,
                          activeTrackColor: C.mint,
                          inactiveTrackColor: C.mint.withValues(alpha: 0.25),
                          thumbColor: const Color(0xFF1FB9AA),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 12,
                          ),
                        ),
                        child: Slider(
                          value: volume,
                          onChanged: (v) => setState(() => volume = v),
                        ),
                      ),
                    ),
                    const Text('🔊', style: TextStyle(fontSize: 14)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 6),
            _label('THÔNG BÁO'),
            _tile(
              '🔔',
              C.coral,
              C.coralSoft,
              'Bật thông báo',
              'Cho phép app gửi thông báo',
              _switch(notify, (v) => setState(() => notify = v), C.coral),
            ),
            _tile(
              '⏰',
              C.amber,
              C.amberSoft,
              'Nhắc học mỗi ngày',
              'Nhắc lúc 19:00 hằng ngày',
              _switch(
                dailyReminder,
                (v) => setState(() => dailyReminder = v),
                C.amber,
              ),
            ),
            _tile(
              '📳',
              C.orange,
              C.orangeSoft,
              'Rung khi bấm',
              'Rung phản hồi khi tương tác',
              _switch(vibrate, (v) => setState(() => vibrate = v), C.orange),
            ),

            const SizedBox(height: 6),
            _label('HIỂN THỊ'),
            _tile(
              '🌙',
              C.indigo,
              C.indigoSoft,
              'Chế độ tối',
              'Dịu mắt vào buổi tối',
              _switch(darkMode, (v) => setState(() => darkMode = v), C.indigo),
            ),
            _tile(
              '🎨',
              C.purple,
              C.indigoSoft,
              'Chủ đề màu',
              '${_swatchNames[themeColor]} · Đang chọn',
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int i = 0; i < _swatches.length; i++)
                    GestureDetector(
                      onTap: () => setState(() => themeColor = i),
                      child: Container(
                        margin: const EdgeInsets.only(left: 6),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: _swatches[i],
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: themeColor == i ? C.navy : Colors.white,
                            width: themeColor == i ? 2 : 1.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 6),
            _label('PHỤ HUYNH'),
            _tile(
              '🔒',
              C.purple,
              C.indigoSoft,
              'Chế độ phụ huynh',
              'Cần mã PIN để mở',
              _chevron(),
            ),
            _tile(
              '⏳',
              C.amber,
              C.amberSoft,
              'Giới hạn thời gian',
              'Tối đa 45 phút mỗi ngày',
              _chevron(),
            ),

            const SizedBox(height: 6),
            _label('THÔNG TIN'),
            _tile(
              'ℹ️',
              C.indigo,
              C.indigoSoft,
              'Về ứng dụng',
              'Phiên bản 1.2.0',
              _chevron(),
            ),
            _tile(
              '⭐',
              C.amber,
              C.amberSoft,
              'Đánh giá ứng dụng',
              'Gửi cho chúng tôi 5 sao nhé!',
              _chevron(),
            ),
            _tile(
              '🛟',
              C.coral,
              C.coralSoft,
              'Trợ giúp & Hỗ trợ',
              '',
              _chevron(),
            ),
            _tile(
              '🛡️',
              C.mint,
              C.mintPale,
              'Chính sách bảo mật',
              '',
              _chevron(),
            ),

            const SizedBox(height: 8),
            _logoutButton(context),
          ],
        ),
      ),
    );
  }

  Widget _logoutButton(BuildContext context) => GestureDetector(
    onTap: () => _confirmLogout(context),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: C.coralSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: C.coral.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.logout, color: C.coral, size: 20),
          const SizedBox(width: 8),
          Text(
            'Đăng xuất',
            style: t(15, w: FontWeight.w800, color: C.coral),
          ),
        ],
      ),
    ),
  );

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text('Đăng xuất?', style: t(18, w: FontWeight.w900)),
        content: Text(
          'Bạn có chắc muốn đăng xuất khỏi tài khoản Bo không?',
          style: t(14, w: FontWeight.w600, color: C.muted),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(),
            child: Text(
              'Huỷ',
              style: t(14, w: FontWeight.w800, color: C.muted),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dctx).pop();
              widget.onClose();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('👋 Đã đăng xuất. Hẹn gặp lại!'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: C.coral,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              'Đăng xuất',
              style: t(14, w: FontWeight.w800, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() => Row(
    children: [
      GestureDetector(
        onTap: widget.onClose,
        child: Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 12,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(Icons.chevron_left, color: C.navy),
        ),
      ),
      const SizedBox(width: 12),
      Text('Cài đặt ⚙️', style: t(24, w: FontWeight.w900)),
    ],
  );

  Widget _profileCard() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [C.orange, C.coral]),
      borderRadius: BorderRadius.circular(22),
      boxShadow: const [
        BoxShadow(
          color: Color(0x40FF6B6B),
          offset: Offset(0, 6),
          blurRadius: 18,
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.25),
            shape: BoxShape.circle,
          ),
          child: Text(
            'B',
            style: t(24, w: FontWeight.w900, color: Colors.white),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bo',
                style: t(18, w: FontWeight.w800, color: Colors.white),
              ),
              Text(
                'Đã học 48 màn · 5 ngày streak',
                style: t(
                  12,
                  w: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            'Sửa',
            style: t(13, w: FontWeight.w700, color: Colors.white),
          ),
        ),
      ],
    ),
  );

  Widget _label(String s) => Padding(
    padding: const EdgeInsets.only(bottom: 10, top: 4),
    child: Text(
      s,
      style: t(
        12,
        w: FontWeight.w800,
        color: C.muted,
      ).copyWith(letterSpacing: 1),
    ),
  );

  Widget _tile(
    String emoji,
    Color c,
    Color bg,
    String title,
    String sub,
    Widget trailing,
  ) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0F000000),
          blurRadius: 18,
          offset: Offset(0, 6),
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Text(emoji, style: const TextStyle(fontSize: 19)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: t(15, w: FontWeight.w800)),
              if (sub.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  sub,
                  style: t(12, w: FontWeight.w600, color: C.muted),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        trailing,
      ],
    ),
  );

  Widget _chevron() => const Icon(Icons.chevron_right, color: C.muted);

  Widget _switch(bool v, ValueChanged<bool> onChanged, Color c) => Switch(
    value: v,
    onChanged: onChanged,
    activeThumbColor: Colors.white,
    activeTrackColor: c,
  );

  Widget _segmented(
    List<String> labels,
    int selected,
    ValueChanged<int> onTap,
  ) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: const Color(0xFFF1F5F3),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < labels.length; i++)
          GestureDetector(
            onTap: () => onTap(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                color: selected == i ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                boxShadow: selected == i
                    ? const [
                        BoxShadow(
                          color: Color(0x14000000),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                labels[i],
                style: t(
                  11.5,
                  w: FontWeight.w700,
                  color: selected == i ? C.amber : C.muted,
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

// ─── Màn Thành tích (tab cúp) ────────────────────────────────────────────────
class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  // (emoji, tên, mô tả, màu, nền, đã mở khóa)
  static const _all = [
    (
      '🌟',
      'Học liên tiếp 5 ngày',
      'Không nghỉ ngày nào!',
      C.amber,
      C.amberSoft,
      true,
    ),
    ('🐣', 'Từ vựng đầu tiên', 'Học được 10 từ mới', C.mint, C.mintPale, true),
    (
      '🚀',
      'Tốc độ siêu nhanh',
      'Hoàn thành trong 1 phút',
      C.indigo,
      C.indigoSoft,
      true,
    ),
    (
      '💯',
      'Điểm tuyệt đối',
      'Trả lời đúng 100% một màn',
      C.coral,
      C.coralSoft,
      true,
    ),
    ('📚', 'Mọt sách nhí', 'Học đủ 100 từ vựng', C.mint, C.mintPale, true),
    (
      '🦉',
      'Cú đêm chăm chỉ',
      'Học bài sau 22:00',
      C.purple,
      C.indigoSoft,
      true,
    ),
    (
      '🎯',
      'Xạ thủ từ vựng',
      'Đúng 50 từ không sai',
      C.orange,
      C.orangeSoft,
      true,
    ),
    (
      '👑',
      'Nhà vô địch tuần',
      'Đứng top bảng xếp hạng',
      C.amber,
      C.amberSoft,
      true,
    ),
    (
      '🔥',
      'Chuỗi lửa 30 ngày',
      'Học liên tục 30 ngày',
      C.orange,
      C.orangeSoft,
      false,
    ),
    (
      '🏆',
      'Bậc thầy từ vựng',
      'Học đủ 500 từ vựng',
      C.indigo,
      C.indigoSoft,
      false,
    ),
    ('⚡', 'Thần tốc', 'Hoàn thành 10 màn/ngày', C.coral, C.coralSoft, false),
    ('🌍', 'Nhà thám hiểm', 'Mở khóa mọi chủ đề', C.mint, C.mintPale, false),
  ];

  @override
  Widget build(BuildContext ctx) {
    final unlocked = _all.where((a) => a.$6).length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 68, 16, 120),
      children: [
        Text('Thành tích 🏆', style: t(22, w: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(
          'Sưu tầm huy hiệu khi học nhé!',
          style: t(13, w: FontWeight.w600, color: C.muted),
        ),
        const SizedBox(height: 16),
        _progress(unlocked, _all.length),
        const SizedBox(height: 18),
        Text('Đã mở khóa ✨', style: t(15, w: FontWeight.w800)),
        const SizedBox(height: 12),
        ..._all.where((a) => a.$6).map(_card),
        const SizedBox(height: 6),
        Text('Chưa mở khóa 🔒', style: t(15, w: FontWeight.w800)),
        const SizedBox(height: 12),
        ..._all.where((a) => !a.$6).map(_card),
      ],
    );
  }

  Widget _progress(int done, int total) {
    final ratio = done / total;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [C.indigo, C.indigoMid]),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x475B56F0),
            offset: Offset(0, 4),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tiến độ sưu tầm',
                style: t(14, w: FontWeight.w800, color: Colors.white),
              ),
              Text(
                '$done/$total',
                style: t(15, w: FontWeight.w900, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 12,
              color: Colors.white.withValues(alpha: 0.22),
              child: FractionallySizedBox(
                widthFactor: ratio,
                alignment: Alignment.centerLeft,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [C.amber, C.orange]),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card((String, String, String, Color, Color, bool) a) {
    final unlocked = a.$6;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: unlocked ? Colors.white : const Color(0xFFF3F6F4),
          borderRadius: BorderRadius.circular(18),
          boxShadow: unlocked
              ? const [BoxShadow(color: Color(0x0F000000), blurRadius: 14)]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: unlocked ? a.$5 : const Color(0xFFE4EAE7),
                shape: BoxShape.circle,
              ),
              child: unlocked
                  ? Text(a.$1, style: const TextStyle(fontSize: 24))
                  : Opacity(
                      opacity: 0.5,
                      child: Text(a.$1, style: const TextStyle(fontSize: 22)),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.$2,
                    style: t(
                      15,
                      w: FontWeight.w800,
                      color: unlocked ? C.navy : C.muted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    a.$3,
                    style: t(12, w: FontWeight.w600, color: C.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            unlocked
                ? Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: a.$4,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 16,
                      color: Colors.white,
                    ),
                  )
                : const Text('🔒', style: TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );
  }
}
