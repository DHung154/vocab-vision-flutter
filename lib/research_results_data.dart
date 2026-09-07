const researchResultsData = <String, dynamic>{
  'title': 'Kết quả thực nghiệm E4',
  'artifact_matches_reported': true,
  'differences': <String>[],
  'seed0': <Map<String, dynamic>>[
    {
      'method': 'E0',
      'label': 'YOLO26-S cơ sở',
      'AP50': 0.8191060178072489,
      'AP75': 0.7700061313248272,
      'mAP50_95': 0.7355042777892323,
    },
    {
      'method': 'E1',
      'label': 'InterpIoU cố định',
      'AP50': 0.805292,
      'AP75': 0.758314,
      'mAP50_95': 0.728457,
    },
    {
      'method': 'E4',
      'label': 'E4 affine + EMA',
      'AP50': 0.822160205411961,
      'AP75': 0.7714082358888947,
      'mAP50_95': 0.7385505647288786,
    },
  ],
  'three_seed': <Map<String, dynamic>>[
    {
      'method': 'E0',
      'label': 'YOLO26-S cơ sở',
      'seed_count': 3,
      'seeds': <int>[0, 1, 2],
      'mean': <String, double>{
        'AP50': 0.8194155163368089,
        'AP75': 0.7710242682899175,
        'mAP50_95': 0.7364912933720885,
      },
      'sample_std': <String, double>{
        'AP50': 0.0051368597208019924,
        'AP75': 0.004492340090162866,
        'mAP50_95': 0.0039814424784644815,
      },
    },
    {
      'method': 'E4',
      'label': 'E4 affine + EMA',
      'seed_count': 3,
      'seeds': <int>[0, 1, 2],
      'mean': <String, double>{
        'AP50': 0.8224739147521866,
        'AP75': 0.7713114652591873,
        'mAP50_95': 0.739040954808035,
      },
      'sample_std': <String, double>{
        'AP50': 0.003449291630582286,
        'AP75': 0.0013501894971855164,
        'mAP50_95': 0.001482574229212602,
      },
    },
  ],
  'sources': <String, String>{
    'summary_csv': r'E:\KLTN\outputs\yolo_seed_test_fixed\summary.csv',
    'e1_seed0':
        r'E:\KLTN\analysis\fair_rewrite_teacher_notes_20260825\source_content.txt',
    'e1_predictions': r'E:\KLTN\outputs\preds_yolo\E1_test.json',
    'note':
        'Bản snapshot offline đã được đối chiếu khi build; summary.csv chỉ chứa E0/E4, E1 là kết quả seed 0 từ bảng kiểm thử đã khóa.',
  },
  'protocol': <String, dynamic>{
    'split': 'fixed test',
    'seed0': 0,
    'three_seed': 'seed 0, 1, 2; mean và sample standard deviation (n-1)',
    'evaluator': 'faster-coco-eval 1.7.2 theo giao thức đánh giá gốc',
  },
};
