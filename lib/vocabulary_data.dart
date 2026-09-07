class VocabularyWord {
  final String apiLabel;
  final String emoji;
  final String english;
  final String vietnamese;

  const VocabularyWord({
    required this.apiLabel,
    required this.emoji,
    required this.english,
    required this.vietnamese,
  });
}

const vocabularyWords = <VocabularyWord>[
  VocabularyWord(
    apiLabel: 'abacus',
    emoji: '🧮',
    english: 'Abacus',
    vietnamese: 'Bàn tính',
  ),
  VocabularyWord(
    apiLabel: 'backpack',
    emoji: '🎒',
    english: 'Backpack',
    vietnamese: 'Ba lô',
  ),
  VocabularyWord(
    apiLabel: 'chalk',
    emoji: '🖍️',
    english: 'Chalk',
    vietnamese: 'Phấn',
  ),
  VocabularyWord(
    apiLabel: 'chalkboard',
    emoji: '🟩',
    english: 'Chalkboard',
    vietnamese: 'Bảng phấn',
  ),
  VocabularyWord(
    apiLabel: 'crayon',
    emoji: '🖍️',
    english: 'Crayon',
    vietnamese: 'Bút sáp màu',
  ),
  VocabularyWord(
    apiLabel: 'cup',
    emoji: '🥤',
    english: 'Cup',
    vietnamese: 'Cốc',
  ),
  VocabularyWord(
    apiLabel: 'eraser',
    emoji: '🧽',
    english: 'Eraser',
    vietnamese: 'Cục tẩy',
  ),
  VocabularyWord(
    apiLabel: 'glue_stick',
    emoji: '🧴',
    english: 'Glue stick',
    vietnamese: 'Hồ khô',
  ),
  VocabularyWord(
    apiLabel: 'kids_chair',
    emoji: '🪑',
    english: 'Kids chair',
    vietnamese: 'Ghế trẻ em',
  ),
  VocabularyWord(
    apiLabel: 'notebook',
    emoji: '📓',
    english: 'Notebook',
    vietnamese: 'Vở',
  ),
  VocabularyWord(
    apiLabel: 'paintbrush',
    emoji: '🖌️',
    english: 'Paintbrush',
    vietnamese: 'Cọ vẽ',
  ),
  VocabularyWord(
    apiLabel: 'pencil',
    emoji: '✏️',
    english: 'Pencil',
    vietnamese: 'Bút chì',
  ),
  VocabularyWord(
    apiLabel: 'pencil_sharpener',
    emoji: '🔺',
    english: 'Pencil sharpener',
    vietnamese: 'Gọt bút chì',
  ),
  VocabularyWord(
    apiLabel: 'ruler',
    emoji: '📏',
    english: 'Ruler',
    vietnamese: 'Thước kẻ',
  ),
  VocabularyWord(
    apiLabel: 'scissors',
    emoji: '✂️',
    english: 'Scissors',
    vietnamese: 'Kéo',
  ),
];
