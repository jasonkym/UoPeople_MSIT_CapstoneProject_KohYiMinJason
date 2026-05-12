import 'dart:io';
import 'dart:ui' as ui;

import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:flutter/material.dart';

import '../services/authentication_service.dart';
import '../services/camera_service.dart';
import '../services/label_export_service.dart';
import '../services/rekognition_service.dart';
import '../services/translate_service.dart';
import 'login_screen.dart';

const _awsRegion = 'ap-southeast-1';

class BeforeScreenshot extends StatefulWidget {
  const BeforeScreenshot({super.key});

  @override
  State<BeforeScreenshot> createState() => _BeforeScreenshotState();
}

class _BeforeScreenshotState extends State<BeforeScreenshot> {
  File? _pickedImage;
  bool _isAnalyzing = false;
  String? _errorMessage;
  List<String> _selectedLanguages = [];

  static const _availableLanguages = {
    'es': 'Spanish',
    'fr': 'French',
    'de': 'German',
    'it': 'Italian',
    'pt': 'Portuguese',
    'ja': 'Japanese',
    'zh': 'Chinese (Simplified)',
    'ko': 'Korean',
    'ar': 'Arabic',
    'ru': 'Russian',
  };

  Future<void> _pickFromCamera() async {
    final pickedImage = await CameraService.pickFromCamera();
    if (pickedImage == null) return;
    setState(() {
      _pickedImage = pickedImage;
      _errorMessage = null;
    });
  }

  Future<void> _pickFromGallery() async {
    final pickedImage = await CameraService.pickFromGallery();
    if (pickedImage == null) return;
    setState(() {
      _pickedImage = pickedImage;
      _errorMessage = null;
    });
  }

  Future<({String accessKey, String secretKey, String sessionToken})>
  _getAwsCredentials() async {
    return await AuthenticationService.getAwsCredentials();
  }

  Future<void> _showLanguageDialog() async {
    final tempSelectedLanguages = List<String>.from(_selectedLanguages);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Select Languages (max 5)'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: _availableLanguages.entries.map((entry) {
                final code = entry.key;
                final name = entry.value;
                final isSelected = tempSelectedLanguages.contains(code);
                return CheckboxListTile(
                  title: Text(name),
                  subtitle: Text(code),
                  value: isSelected,
                  onChanged: (value) {
                    setDialogState(() {
                      if (value == true && tempSelectedLanguages.length < 5) {
                        tempSelectedLanguages.add(code);
                      } else if (value == false) {
                        tempSelectedLanguages.remove(code);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                setState(() => _selectedLanguages = tempSelectedLanguages);
                Navigator.pop(ctx);
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _analyzeImage() async {
    if (_pickedImage == null) return;

    if (_selectedLanguages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select at least one language before detecting labels.',
          ),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
    });

    try {
      final credentials = await _getAwsCredentials();

      final labels = await RekognitionService.detectLabels(
        region: _awsRegion,
        accessKeyId: credentials.accessKey,
        secretKey: credentials.secretKey,
        sessionToken: credentials.sessionToken,
        imageFile: _pickedImage!,
      );

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AfterScreenshot(
            imageFile: _pickedImage!,
            labels: labels,
            preselectedLanguages: _selectedLanguages,
            credentials: credentials,
          ),
        ),
      );
    } on AuthException catch (e) {
      setState(() => _errorMessage = 'Auth error: ${e.message}');
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  Future<void> _signOut() async {
    try {
      final result = await AuthenticationService.signOut();
      if (!mounted) return;

      if (result is CognitoCompleteSignOut) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Sign out was not fully completed. Please try again.',
            ),
          ),
        );
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Sign out failed: ${e.message}')));
    }
  }

  void _showDownloadHint() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Download is available after you detect labels.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Image Recognizer'),
        backgroundColor: colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Select languages',
            onPressed: _showLanguageDialog,
          ),
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Download labels',
            onPressed: _showDownloadHint,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: _signOut,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: _pickedImage == null
                  ? Container(
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.photo_camera,
                              size: 64,
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.4,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Take or select a photo to\ndetect objects',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(
                        _pickedImage!,
                        fit: BoxFit.contain,
                        width: double.infinity,
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: colorScheme.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isAnalyzing ? null : _pickFromCamera,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Camera'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isAnalyzing ? null : _pickFromGallery,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Gallery'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: (_pickedImage != null && !_isAnalyzing)
                    ? _analyzeImage
                    : null,
                icon: _isAnalyzing
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search),
                label: Text(_isAnalyzing ? 'Analysing…' : 'Detect Labels'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AfterScreenshot extends StatefulWidget {
  final File imageFile;
  final List<DetectedLabel> labels;
  final List<String> preselectedLanguages;
  final ({String accessKey, String secretKey, String sessionToken})?
  credentials;

  const AfterScreenshot({
    super.key,
    required this.imageFile,
    required this.labels,
    this.preselectedLanguages = const [],
    this.credentials,
  });

  @override
  State<AfterScreenshot> createState() => _AfterScreenshotState();
}

class _AfterScreenshotState extends State<AfterScreenshot> {
  ui.Image? _uiImage;
  final GlobalKey _imageKey = GlobalKey();
  List<String> _selectedLanguages = [];
  final Map<String, List<TranslatedResult>> _translationCache = {};
  bool _isTranslating = false;
  bool _isDownloading = false;

  static const _availableLanguages = {
    'es': 'Spanish',
    'fr': 'French',
    'de': 'German',
    'it': 'Italian',
    'pt': 'Portuguese',
    'ja': 'Japanese',
    'zh': 'Chinese (Simplified)',
    'ko': 'Korean',
    'ar': 'Arabic',
    'ru': 'Russian',
  };

  @override
  void initState() {
    super.initState();
    _loadUiImage();
    if (widget.preselectedLanguages.isNotEmpty) {
      _selectedLanguages = List<String>.from(widget.preselectedLanguages);
      _translateLabels();
    }
  }

  Future<void> _loadUiImage() async {
    final bytes = await widget.imageFile.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    if (mounted) setState(() => _uiImage = frame.image);
  }

  Future<({String accessKey, String secretKey, String sessionToken})>
  _getAwsCredentials() async {
    return await AuthenticationService.getAwsCredentials();
  }

  Future<void> _showLanguageDialog() async {
    final tempSelectedLanguages = List<String>.from(_selectedLanguages);
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Select Languages (max 5)'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: _availableLanguages.entries.map((entry) {
                final code = entry.key;
                final name = entry.value;
                final isSelected = tempSelectedLanguages.contains(code);
                return CheckboxListTile(
                  title: Text(name),
                  subtitle: Text(code),
                  value: isSelected,
                  onChanged: (value) {
                    setDialogState(() {
                      if (value == true && tempSelectedLanguages.length < 5) {
                        tempSelectedLanguages.add(code);
                      } else if (value == false) {
                        tempSelectedLanguages.remove(code);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                setState(() => _selectedLanguages = tempSelectedLanguages);
                Navigator.pop(ctx);
                if (_selectedLanguages.isNotEmpty) {
                  await _translateLabels();
                }
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _translateLabels() async {
    if (_selectedLanguages.isEmpty) return;
    setState(() => _isTranslating = true);
    try {
      final creds = widget.credentials ?? await _getAwsCredentials();
      final labelText = widget.labels.map((l) => l.name).join(', ');
      final translations = await TranslateService.translateText(
        region: _awsRegion,
        accessKeyId: creds.accessKey,
        secretKey: creds.secretKey,
        sessionToken: creds.sessionToken,
        text: labelText,
        sourceLanguage: 'en',
        targetLanguages: _selectedLanguages,
      );
      if (mounted) {
        setState(() {
          _translationCache.clear();
          for (final result in translations) {
            if (!_translationCache.containsKey(result.targetLanguage)) {
              _translationCache[result.targetLanguage] = [];
            }
            _translationCache[result.targetLanguage]!.add(result);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Translation error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isTranslating = false);
    }
  }

  Future<void> _signOut() async {
    try {
      final result = await AuthenticationService.signOut();
      if (!mounted) return;

      if (result is CognitoCompleteSignOut) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Sign out was not fully completed. Please try again.',
            ),
          ),
        );
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Sign out failed: ${e.message}')));
    }
  }

  Future<void> _downloadLabelsReport() async {
    if (_isDownloading || _isTranslating) return;

    if (_selectedLanguages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one language before download.'),
        ),
      );
      return;
    }

    setState(() => _isDownloading = true);
    try {
      if (_translationCache.isEmpty) {
        await _translateLabels();
      }

      final englishLabels = widget.labels.map((l) => l.name).toList();
      final translatedByLanguage = <String, String>{};
      for (final code in _selectedLanguages) {
        final languageName = _availableLanguages[code] ?? code;
        final translatedText = _translationCache[code]?.isNotEmpty == true
            ? _translationCache[code]!.first.translatedText
            : 'No translation available';
        translatedByLanguage['$languageName ($code)'] = translatedText;
      }

      final report = LabelExportService.buildReport(
        englishLabels: englishLabels,
        translatedByLanguage: translatedByLanguage,
      );
      final savedLocation = await LabelExportService.saveReportWithPicker(
        reportContent: report,
      );
      if (savedLocation == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Download canceled.')));
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Saved to $savedLocation')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Download failed: $e')));
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  List<DetectedLabel> get _allLabels => widget.labels;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detection Results'),
        backgroundColor: colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Select languages',
            onPressed: _showLanguageDialog,
          ),
          IconButton(
            icon: _isDownloading
                ? const Icon(Icons.downloading)
                : const Icon(Icons.download),
            tooltip: 'Download labels',
            onPressed: _isDownloading ? null : _downloadLabelsReport,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: _signOut,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: _uiImage == null
                  ? const Center(child: CircularProgressIndicator())
                  : LayoutBuilder(
                      builder: (ctx, constraints) {
                        final imgAspect = _uiImage!.width / _uiImage!.height;
                        final boxAspect =
                            constraints.maxWidth / constraints.maxHeight;
                        final double renderedW, renderedH;
                        if (imgAspect > boxAspect) {
                          renderedW = constraints.maxWidth;
                          renderedH = constraints.maxWidth / imgAspect;
                        } else {
                          renderedH = constraints.maxHeight;
                          renderedW = constraints.maxHeight * imgAspect;
                        }
                        return Center(
                          child: SizedBox(
                            width: renderedW,
                            height: renderedH,
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(
                                      widget.imageFile,
                                      key: _imageKey,
                                      fit: BoxFit.fill,
                                    ),
                                  ),
                                ),
                                Positioned.fill(
                                  child: CustomPaint(
                                    painter: BoundingBoxPainter(
                                      labels: _allLabels,
                                      imageWidth: renderedW,
                                      imageHeight: renderedH,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Text(
                    _selectedLanguages.isEmpty
                        ? 'Detected Labels'
                        : 'Translations (${_selectedLanguages.length})',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: _isTranslating
                      ? const Center(child: CircularProgressIndicator())
                      : _selectedLanguages.isEmpty
                      ? ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _allLabels.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final label = _allLabels[i];
                            return ListTile(
                              dense: true,
                              leading: const Icon(Icons.label_outline),
                              title: Text(label.name),
                              subtitle: label.boundingBoxes.isNotEmpty
                                  ? Text(
                                      '${label.boundingBoxes.length} instance(s) located',
                                      style: const TextStyle(fontSize: 11),
                                    )
                                  : null,
                            );
                          },
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _selectedLanguages.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final langCode = _selectedLanguages[i];
                            final langName =
                                _availableLanguages[langCode] ?? langCode;
                            final translations =
                                _translationCache[langCode] ?? [];
                            return ExpansionTile(
                              title: Text(langName),
                              subtitle: Text(langCode),
                              children: translations.isEmpty
                                  ? [
                                      const Padding(
                                        padding: EdgeInsets.all(16),
                                        child: Text(
                                          'No translations available',
                                        ),
                                      ),
                                    ]
                                  : translations
                                        .map(
                                          (tr) => Padding(
                                            padding: const EdgeInsets.all(16),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Original:',
                                                  style: Theme.of(
                                                    context,
                                                  ).textTheme.labelSmall,
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  widget.labels
                                                      .map((l) => l.name)
                                                      .join(', '),
                                                ),
                                                const SizedBox(height: 12),
                                                Text(
                                                  'Translated:',
                                                  style: Theme.of(
                                                    context,
                                                  ).textTheme.labelSmall,
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  tr.translatedText,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    color: colorScheme.primary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        )
                                        .toList(),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class BoundingBoxPainter extends CustomPainter {
  final List<DetectedLabel> labels;
  final double imageWidth;
  final double imageHeight;

  static const _palette = [
    Color(0xFFE53935),
    Color(0xFF1E88E5),
    Color(0xFF43A047),
    Color(0xFFFFB300),
    Color(0xFF8E24AA),
    Color(0xFF00ACC1),
    Color(0xFFE91E63),
    Color(0xFF6D4C41),
    Color(0xFF039BE5),
    Color(0xFF7CB342),
  ];

  BoundingBoxPainter({
    required this.labels,
    required this.imageWidth,
    required this.imageHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < labels.length; i++) {
      final label = labels[i];
      final color = _palette[i % _palette.length];
      final boxPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      final bgPaint = Paint()
        ..color = color.withValues(alpha: 0.65)
        ..style = PaintingStyle.fill;

      for (final box in label.boundingBoxes) {
        final rect = Rect.fromLTWH(
          box.left * imageWidth,
          box.top * imageHeight,
          box.width * imageWidth,
          box.height * imageHeight,
        );
        canvas.drawRect(rect, boxPaint);

        const tagPadding = 4.0;
        const fontSize = 11.0;
        final text = label.name;

        final paragraphStyle = ui.ParagraphStyle(
          textAlign: TextAlign.left,
          fontSize: fontSize,
        );
        final paragraphBuilder = ui.ParagraphBuilder(paragraphStyle)
          ..pushStyle(
            ui.TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
            ),
          )
          ..addText(text);
        final paragraph = paragraphBuilder.build()
          ..layout(ui.ParagraphConstraints(width: imageWidth));

        final tagWidth = paragraph.maxIntrinsicWidth + tagPadding * 2;
        final tagHeight = fontSize + tagPadding * 2;
        final tagTop = (rect.top - tagHeight).clamp(0.0, imageHeight);
        final tagRect = Rect.fromLTWH(rect.left, tagTop, tagWidth, tagHeight);

        canvas.drawRect(tagRect, bgPaint);
        canvas.drawParagraph(
          paragraph,
          Offset(tagRect.left + tagPadding, tagRect.top + tagPadding),
        );
      }
    }
  }

  @override
  bool shouldRepaint(BoundingBoxPainter oldDelegate) =>
      oldDelegate.labels != labels ||
      oldDelegate.imageWidth != imageWidth ||
      oldDelegate.imageHeight != imageHeight;
}
