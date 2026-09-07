import 'package:flutter/material.dart';

import 'inference_service.dart';
import 'main.dart' show C, t;

class ResearchResultsScreen extends StatefulWidget {
  const ResearchResultsScreen({super.key});

  @override
  State<ResearchResultsScreen> createState() => _ResearchResultsScreenState();
}

class _ResearchResultsScreenState extends State<ResearchResultsScreen> {
  final _service = const InferenceService();
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.fetchResearchResults();
  }

  void _reload() => setState(() {
    _future = _service.fetchResearchResults();
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFDDFCF5),
      appBar: AppBar(
        title: Text('Kết quả thực nghiệm E4', style: t(18, w: FontWeight.w800)),
        backgroundColor: Colors.white,
        foregroundColor: C.navy,
        elevation: 0,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: C.indigo),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: C.coral,
                      size: 52,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: t(13),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _reload,
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            );
          }
          return _content(snapshot.data!);
        },
      ),
    );
  }

  Widget _content(Map<String, dynamic> data) {
    final seed0 = (data['seed0'] as List).cast<Map<String, dynamic>>();
    final threeSeed = (data['three_seed'] as List).cast<Map<String, dynamic>>();
    final differences = (data['differences'] as List).cast<String>();
    final sources = data['sources'] as Map<String, dynamic>;
    final protocol = data['protocol'] as Map<String, dynamic>;
    final matches = data['artifact_matches_reported'] as bool;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _status(matches, differences),
        const SizedBox(height: 14),
        _section(
          title: 'Kiểm thử seed 0',
          subtitle:
              'Giá trị AP theo giao thức đánh giá gốc. Δ là chênh lệch so với E0, tính bằng điểm phần trăm.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _seed0Table(seed0),
              const SizedBox(height: 10),
              Text(
                _comparison(seed0, 'E4', 'E1', 'E4 so với InterpIoU cố định'),
                style: t(11.5, w: FontWeight.w700, color: C.indigo, h: 1.4),
              ),
              const SizedBox(height: 4),
              Text(
                _comparison(seed0, 'E4', 'E0', 'E4 so với mô hình cơ sở'),
                style: t(11.5, w: FontWeight.w700, color: C.indigo, h: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _section(
          title: 'Tổng hợp 3 seed',
          subtitle:
              '${protocol['three_seed']}. E1 không có trong summary.csv nên không được trộn vào bảng này.',
          child: _threeSeedTable(threeSeed),
        ),
        const SizedBox(height: 14),
        _section(
          title: 'Cách đọc đúng',
          child: Text(
            'Confidence của một box không phải độ chính xác của mô hình. Ảnh người dùng không có ground truth nên demo không tính AP, mAP, Precision hay Recall. Các chỉ số trên thuộc ${protocol['split']} với ${protocol['evaluator']}; chúng không tự động đại diện cho mọi ngưỡng confidence hoặc hậu xử lý trong demo.',
            style: t(12.5, w: FontWeight.w600, color: C.muted, h: 1.45),
          ),
        ),
        const SizedBox(height: 14),
        _section(
          title: 'Nguồn đã xác minh',
          child: SelectableText(
            '${sources['summary_csv']}\n\nE1 seed 0: ${sources['e1_seed0']}\n'
            'Prediction E1 fixed-test: ${sources['e1_predictions']}\n\n${sources['note']}',
            style: t(11.5, w: FontWeight.w600, color: C.muted, h: 1.4),
          ),
        ),
      ],
    );
  }

  Widget _status(bool matches, List<String> differences) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: matches ? C.mintPale : C.amberSoft,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: matches ? C.mint : C.amber),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          matches ? Icons.verified_rounded : Icons.warning_amber_rounded,
          color: matches ? C.navy : C.orange,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            matches
                ? 'Artifact E0/E4 và nguồn E1 khớp số seed 0 đã báo cáo.'
                : 'Có khác biệt cần kiểm tra:\n${differences.join('\n')}',
            style: t(12.5, w: FontWeight.w700, h: 1.4),
          ),
        ),
      ],
    ),
  );

  Widget _section({
    required String title,
    String? subtitle,
    required Widget child,
  }) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.white),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: t(16, w: FontWeight.w900)),
        if (subtitle != null) ...[
          const SizedBox(height: 5),
          Text(
            subtitle,
            style: t(11.5, w: FontWeight.w600, color: C.muted, h: 1.35),
          ),
        ],
        const SizedBox(height: 12),
        child,
      ],
    ),
  );

  Widget _seed0Table(List<Map<String, dynamic>> rows) {
    final baseline = rows.firstWhere((row) => row['method'] == 'E0');
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 18,
        horizontalMargin: 4,
        columns: const [
          DataColumn(label: Text('Phương pháp')),
          DataColumn(label: Text('AP50'), numeric: true),
          DataColumn(label: Text('AP75'), numeric: true),
          DataColumn(label: Text('mAP50–95'), numeric: true),
          DataColumn(label: Text('Δ mAP'), numeric: true),
        ],
        rows: rows.map((row) {
          final delta =
              ((row['mAP50_95'] as num) - (baseline['mAP50_95'] as num)) * 100;
          return DataRow(
            cells: [
              DataCell(
                SizedBox(width: 150, child: Text(row['label'] as String)),
              ),
              DataCell(Text(_metric(row['AP50']))),
              DataCell(Text(_metric(row['AP75']))),
              DataCell(Text(_metric(row['mAP50_95']))),
              DataCell(
                Text('${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(4)} đpt'),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _threeSeedTable(
    List<Map<String, dynamic>> rows,
  ) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: DataTable(
      columnSpacing: 18,
      horizontalMargin: 4,
      columns: const [
        DataColumn(label: Text('Phương pháp')),
        DataColumn(label: Text('AP50 mean±SD'), numeric: true),
        DataColumn(label: Text('AP75 mean±SD'), numeric: true),
        DataColumn(label: Text('mAP mean±SD'), numeric: true),
        DataColumn(label: Text('Δ mAP'), numeric: true),
      ],
      rows: rows.map((row) {
        final mean = row['mean'] as Map<String, dynamic>;
        final std = row['sample_std'] as Map<String, dynamic>;
        final baseline = rows.firstWhere((item) => item['method'] == 'E0');
        final baselineMean = baseline['mean'] as Map<String, dynamic>;
        final delta =
            ((mean['mAP50_95'] as num) - (baselineMean['mAP50_95'] as num)) *
            100;
        return DataRow(
          cells: [
            DataCell(
              SizedBox(
                width: 135,
                child: Text('${row['label']} (n=${row['seed_count']})'),
              ),
            ),
            DataCell(
              Text('${_metric(mean['AP50'])} ± ${_metric(std['AP50'])}'),
            ),
            DataCell(
              Text('${_metric(mean['AP75'])} ± ${_metric(std['AP75'])}'),
            ),
            DataCell(
              Text(
                '${_metric(mean['mAP50_95'])} ± ${_metric(std['mAP50_95'])}',
              ),
            ),
            DataCell(
              Text('${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(4)} đpt'),
            ),
          ],
        );
      }).toList(),
    ),
  );

  String _comparison(
    List<Map<String, dynamic>> rows,
    String leftMethod,
    String rightMethod,
    String title,
  ) {
    final left = rows.firstWhere((row) => row['method'] == leftMethod);
    final right = rows.firstWhere((row) => row['method'] == rightMethod);
    String delta(String metric) {
      final value = ((left[metric] as num) - (right[metric] as num)) * 100;
      return '${value >= 0 ? '+' : ''}${value.toStringAsFixed(4)} đpt';
    }

    return '$title: AP50 ${delta('AP50')}; AP75 ${delta('AP75')}; '
        'mAP50–95 ${delta('mAP50_95')}.';
  }

  String _metric(Object? value) => (value as num).toDouble().toStringAsFixed(6);
}
