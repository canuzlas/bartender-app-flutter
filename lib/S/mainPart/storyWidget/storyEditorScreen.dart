import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:bartender/mainSettings.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image/image.dart' as img;

class StoryEditorScreen extends ConsumerStatefulWidget {
  final File imageFile;
  final bool isCamera;
  final Function(bool success) onComplete;

  const StoryEditorScreen({
    super.key,
    required this.imageFile,
    required this.isCamera,
    required this.onComplete,
  });

  @override
  ConsumerState<StoryEditorScreen> createState() => _StoryEditorScreenState();
}

class _StoryEditorScreenState extends ConsumerState<StoryEditorScreen> {
  final GlobalKey _globalKey = GlobalKey();
  final TextEditingController _textController = TextEditingController();

  bool _isUploading = false;
  bool _isTextMode = false;
  String _inputText = '';
  Color _textColor = Colors.white;
  double _textSize = 24.0;
  double _textX = 0.0;
  double _textY = 0.0;
  bool _isBold = false;
  bool _isItalic = false;
  double _sliderValue = 0.0;
  // New text formatting properties
  TextAlign _textAlignment = TextAlign.center;
  bool _hasTextShadow = true;
  Color _shadowColor = Colors.black;
  bool _hasTextBackground = false;
  Color _textBackgroundColor = Colors.black.withOpacity(0.5);
  double _textRotation = 0.0;

  // New features
  double _uploadProgress = 0.0;
  bool _showWatermark = false;
  String _watermarkText = '';
  int _imageQuality = 85; // Default image quality (0-100)
  bool _showHashtagMention = false;
  TextEditingController _hashtagController = TextEditingController();
  List<String> _hashtags = [];
  List<String> _mentions = [];

  // Filter options
  List<FilterOption> filters = [
    FilterOption(name: 'Normal', matrix: null),
    FilterOption(name: 'Grayscale', matrix: [
      0.2126,
      0.7152,
      0.0722,
      0,
      0,
      0.2126,
      0.7152,
      0.0722,
      0,
      0,
      0.2126,
      0.7152,
      0.0722,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ]),
    FilterOption(name: 'Sepia', matrix: [
      0.393,
      0.769,
      0.189,
      0,
      0,
      0.349,
      0.686,
      0.168,
      0,
      0,
      0.272,
      0.534,
      0.131,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ]),
    FilterOption(name: 'Vintage', matrix: [
      0.9,
      0.5,
      0.1,
      0,
      0,
      0.3,
      0.8,
      0.1,
      0,
      0,
      0.2,
      0.3,
      0.5,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ]),
    FilterOption(name: 'Sweet', matrix: [
      1.0,
      0.0,
      0.2,
      0,
      0,
      0.0,
      1.0,
      0.0,
      0,
      0,
      0.0,
      0.0,
      1.0,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ]),
    FilterOption(name: 'Cool', matrix: [
      0.8,
      0.0,
      0.0,
      0,
      0,
      0.0,
      1.0,
      0.2,
      0,
      0,
      0.2,
      0.0,
      1.0,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ]),
  ];

  FilterOption? selectedFilter;

  // Color palette for text
  final List<Color> _colorPalette = [
    Colors.white,
    Colors.black,
    Colors.red,
    Colors.orange,
    Colors.yellow,
    Colors.green,
    Colors.blue,
    Colors.purple,
    Colors.pink,
  ];

  // Drawing feature
  bool _isDrawingMode = false;
  List<DrawingStroke> _strokes = [];
  List<Offset> _currentStroke = [];
  Color _drawingColor = Colors.white;
  double _brushSize = 5.0;

  // Stickers feature
  bool _showStickerPicker = false;
  List<StickerItem> _stickers = [];
  double _initialScale = 1.0;
  double _initialRotation = 0.0;

  // Common emoji sets for stickers
  final List<String> _popularEmojis = [
    '😂',
    '❤️',
    '😍',
    '🔥',
    '👍',
    '✨',
    '🎉',
    '🥰',
    '😊',
    '🤔',
    '😭',
    '🙌',
    '💯',
    '🤩',
    '😎',
    '👏',
  ];

  @override
  void initState() {
    super.initState();
    selectedFilter = filters[0]; // Start with normal filter

    // Initialize text position to center of screen (modified to be more precise)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final size = MediaQuery.of(context).size;
      setState(() {
        _textX = size.width / 2 - 100;
        _textY = size.height / 3;
      });
    });

    // Set default watermark to username if available
    final user = FirebaseAuth.instance.currentUser;
    if (user?.displayName != null) {
      _watermarkText = '@${user!.displayName}';
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _hashtagController.dispose();
    super.dispose();
  }

  // Fixed the text mode toggling to properly handle text input
  void _toggleTextMode() {
    setState(() {
      _isTextMode = !_isTextMode;
      _showHashtagMention = false;

      if (_isTextMode) {
        // When entering text mode, initialize controller with existing text
        _textController.text = _inputText;
      } else {
        // When exiting text mode, save the input
        if (_textController.text.isNotEmpty) {
          _inputText = _textController.text;

          // Position the text in a good spot if it's newly added
          if (_textX == 0 && _textY == 0) {
            _textX = MediaQuery.of(context).size.width / 2 - 100;
            _textY = MediaQuery.of(context).size.height / 3;
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(lang);
    final isDarkTheme = ref.watch(darkTheme);
    final primaryColor = isDarkTheme ? Colors.orangeAccent : Colors.deepOrange;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          language == 'tr' ? 'Hikaye Düzenle' : 'Edit Story',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          // Text button with fixed functionality
          IconButton(
            icon: Icon(
              Icons.text_fields,
              color: _isTextMode ? primaryColor : Colors.white,
            ),
            onPressed: _toggleTextMode, // Use the improved method
          ),
          // New feature: Show hashtag menu
          IconButton(
            icon: Icon(
              Icons.tag,
              color: _showHashtagMention ? primaryColor : Colors.white,
            ),
            onPressed: () {
              setState(() {
                _showHashtagMention = !_showHashtagMention;
                _isTextMode = false;
              });
            },
          ),
          // Quality settings
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () {
              _showQualitySettings(context, primaryColor, language);
            },
          ),
          IconButton(
            icon: const Icon(Icons.check, color: Colors.white),
            onPressed: _isUploading ? null : _captureAndUpload,
          ),
        ],
      ),
      body: Column(
        children: [
          // Main editor area
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Image with filter
                RepaintBoundary(
                  key: _globalKey,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Image with filter
                      ColorFiltered(
                        colorFilter:
                            ColorFilter.matrix(selectedFilter?.matrix ??
                                [
                                  1,
                                  0,
                                  0,
                                  0,
                                  0,
                                  0,
                                  1,
                                  0,
                                  0,
                                  0,
                                  0,
                                  0,
                                  1,
                                  0,
                                  0,
                                  0,
                                  0,
                                  0,
                                  1,
                                  0,
                                ]),
                        child: Image.file(
                          widget.imageFile,
                          fit: BoxFit.contain,
                        ),
                      ),

                      // Positioned text with new features
                      if (_inputText.isNotEmpty)
                        Positioned(
                          left: _textX,
                          top: _textY,
                          child: GestureDetector(
                            onPanUpdate: (details) {
                              setState(() {
                                _textX += details.delta.dx;
                                _textY += details.delta.dy;
                              });
                            },
                            child: Transform.rotate(
                              angle: _textRotation * (3.1415927 / 180),
                              child: Container(
                                padding: _hasTextBackground
                                    ? const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4)
                                    : EdgeInsets.zero,
                                decoration: _hasTextBackground
                                    ? BoxDecoration(
                                        color: _textBackgroundColor,
                                        borderRadius: BorderRadius.circular(4),
                                      )
                                    : null,
                                child: Text(
                                  _inputText,
                                  textAlign: _textAlignment,
                                  style: TextStyle(
                                    color: _textColor,
                                    fontSize: _textSize,
                                    fontWeight: _isBold
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    fontStyle: _isItalic
                                        ? FontStyle.italic
                                        : FontStyle.normal,
                                    shadows: _hasTextShadow
                                        ? [
                                            Shadow(
                                              blurRadius: 3.0,
                                              color:
                                                  _shadowColor.withOpacity(0.8),
                                              offset: const Offset(1.0, 1.0),
                                            ),
                                          ]
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                      // Watermark
                      if (_showWatermark && _watermarkText.isNotEmpty)
                        Positioned(
                          right: 15,
                          bottom: 15,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _watermarkText,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                                fontWeight: FontWeight.normal,
                                shadows: [
                                  Shadow(
                                    blurRadius: 3.0,
                                    color: Colors.black.withOpacity(0.8),
                                    offset: const Offset(1.0, 1.0),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                      // Display hashtags and mentions
                      if (_hashtags.isNotEmpty || _mentions.isNotEmpty)
                        Positioned(
                          left: 15,
                          bottom: 15,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.7,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_hashtags.isNotEmpty) ...[
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: _hashtags
                                        .map((tag) => Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.blue
                                                    .withOpacity(0.3),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: Colors.blue
                                                      .withOpacity(0.5),
                                                  width: 1,
                                                ),
                                              ),
                                              child: Text(
                                                '#$tag',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ))
                                        .toList(),
                                  ),
                                  if (_mentions.isNotEmpty)
                                    const SizedBox(height: 8),
                                ],
                                if (_mentions.isNotEmpty)
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: _mentions
                                        .map((mention) => Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.purple
                                                    .withOpacity(0.3),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: Colors.purple
                                                      .withOpacity(0.5),
                                                  width: 1,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(
                                                    Icons.alternate_email,
                                                    size: 14,
                                                    color: Colors.white70,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    mention,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ))
                                        .toList(),
                                  ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Improved text input overlay (Keep only this one version)
                if (_isTextMode)
                  GestureDetector(
                    onTap: () {
                      // Close the text input when tapping outside
                      _toggleTextMode();
                    },
                    child: Container(
                      color: Colors.black.withOpacity(0.7),
                      padding: const EdgeInsets.all(16.0),
                      child: GestureDetector(
                        // Prevent taps inside from closing
                        onTap: () {},
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextField(
                              controller: _textController,
                              style: TextStyle(
                                color: _textColor,
                                fontSize: _textSize,
                                fontWeight: _isBold
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontStyle: _isItalic
                                    ? FontStyle.italic
                                    : FontStyle.normal,
                              ),
                              textAlign: _textAlignment,
                              maxLines: 3,
                              autofocus: true,
                              decoration: InputDecoration(
                                hintText: language == 'tr'
                                    ? 'Metin girin...'
                                    : 'Enter text...',
                                hintStyle: TextStyle(
                                    color: _textColor.withOpacity(0.7)),
                                border: InputBorder.none,
                              ),
                            ),
                            const SizedBox(height: 20),
                            // Text size slider
                            Row(
                              children: [
                                const Icon(Icons.format_size,
                                    color: Colors.white),
                                Expanded(
                                  child: Slider(
                                    value: _textSize,
                                    min: 12.0,
                                    max: 48.0,
                                    activeColor: primaryColor,
                                    inactiveColor: Colors.grey,
                                    onChanged: (value) {
                                      setState(() {
                                        _textSize = value;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),

                            // Text formatting buttons with new options
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    Icons.format_bold,
                                    color:
                                        _isBold ? primaryColor : Colors.white,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _isBold = !_isBold;
                                    });
                                  },
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.format_italic,
                                    color:
                                        _isItalic ? primaryColor : Colors.white,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _isItalic = !_isItalic;
                                    });
                                  },
                                ),
                                // Text alignment button
                                IconButton(
                                  icon: Icon(
                                    _textAlignment == TextAlign.left
                                        ? Icons.format_align_left
                                        : _textAlignment == TextAlign.center
                                            ? Icons.format_align_center
                                            : Icons.format_align_right,
                                    color: Colors.white,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      if (_textAlignment == TextAlign.left) {
                                        _textAlignment = TextAlign.center;
                                      } else if (_textAlignment ==
                                          TextAlign.center) {
                                        _textAlignment = TextAlign.right;
                                      } else {
                                        _textAlignment = TextAlign.left;
                                      }
                                    });
                                  },
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryColor,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _inputText = _textController.text;
                                      _isTextMode = false;
                                      // Center the text initially
                                      _textX =
                                          MediaQuery.of(context).size.width /
                                                  2 -
                                              50;
                                      _textY =
                                          MediaQuery.of(context).size.height /
                                              4;
                                    });
                                  },
                                  child: Text(
                                    language == 'tr' ? 'Uygula' : 'Apply',
                                  ),
                                ),
                              ],
                            ),

                            // Color palette
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 40,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: _colorPalette.length,
                                itemBuilder: (context, index) {
                                  return GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _textColor = _colorPalette[index];
                                      });
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 4),
                                      width: 30,
                                      height: 30,
                                      decoration: BoxDecoration(
                                        color: _colorPalette[index],
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color:
                                              _textColor == _colorPalette[index]
                                                  ? primaryColor
                                                  : Colors.white,
                                          width:
                                              _textColor == _colorPalette[index]
                                                  ? 2
                                                  : 1,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),

                            // New advanced text formatting options
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                // Text shadow toggle
                                Column(
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        Icons.blur_on,
                                        color: _hasTextShadow
                                            ? primaryColor
                                            : Colors.white,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _hasTextShadow = !_hasTextShadow;
                                        });
                                      },
                                    ),
                                    Text(
                                      language == 'tr' ? 'Gölge' : 'Shadow',
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 12),
                                    ),
                                  ],
                                ),

                                // Text background toggle
                                Column(
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        Icons.format_color_fill,
                                        color: _hasTextBackground
                                            ? primaryColor
                                            : Colors.white,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _hasTextBackground =
                                              !_hasTextBackground;
                                        });
                                      },
                                    ),
                                    Text(
                                      language == 'tr'
                                          ? 'Arkaplan'
                                          : 'Background',
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 12),
                                    ),
                                  ],
                                ),

                                // Rotation control
                                Column(
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.rotate_right,
                                        color: Colors.white,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _textRotation =
                                              (_textRotation + 15) % 360;
                                        });
                                      },
                                    ),
                                    Text(
                                      language == 'tr' ? 'Döndür' : 'Rotate',
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            // Shadow and background color options
                            if (_hasTextShadow || _hasTextBackground)
                              Padding(
                                padding: const EdgeInsets.only(top: 16.0),
                                child: Row(
                                  children: [
                                    Text(
                                      _hasTextShadow
                                          ? (language == 'tr'
                                              ? 'Gölge Rengi:'
                                              : 'Shadow Color:')
                                          : (language == 'tr'
                                              ? 'Arkaplan Rengi:'
                                              : 'Background Color:'),
                                      style:
                                          const TextStyle(color: Colors.white),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: SizedBox(
                                        height: 30,
                                        child: ListView.builder(
                                          scrollDirection: Axis.horizontal,
                                          itemCount: _colorPalette.length,
                                          itemBuilder: (context, index) {
                                            return GestureDetector(
                                              onTap: () {
                                                setState(() {
                                                  if (_hasTextShadow) {
                                                    _shadowColor =
                                                        _colorPalette[index];
                                                  } else {
                                                    _textBackgroundColor =
                                                        _colorPalette[index]
                                                            .withOpacity(0.5);
                                                  }
                                                });
                                              },
                                              child: Container(
                                                margin:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 4),
                                                width: 24,
                                                height: 24,
                                                decoration: BoxDecoration(
                                                  color: _colorPalette[index],
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: (_hasTextShadow &&
                                                                _shadowColor ==
                                                                    _colorPalette[
                                                                        index]) ||
                                                            (!_hasTextShadow &&
                                                                _textBackgroundColor
                                                                        .withOpacity(
                                                                            1.0) ==
                                                                    _colorPalette[
                                                                        index])
                                                        ? primaryColor
                                                        : Colors.white,
                                                    width: 1,
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Hashtag and mention interface
                if (_showHashtagMention)
                  GestureDetector(
                    onTap: () {
                      // Close the hashtag menu when tapping outside
                      setState(() {
                        _showHashtagMention = false;
                      });
                    },
                    child: Container(
                      color: Colors.black.withOpacity(0.7),
                      padding: const EdgeInsets.all(16.0),
                      child: GestureDetector(
                        // Prevent taps inside from closing
                        onTap: () {},
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _hashtagController,
                                    style: TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      hintText: language == 'tr'
                                          ? 'Etiket veya @kullanıcı ekle'
                                          : 'Add hashtag or @mention',
                                      hintStyle:
                                          TextStyle(color: Colors.white70),
                                      prefixText: _hashtagController.text
                                              .startsWith('@')
                                          ? ''
                                          : '#',
                                      prefixStyle:
                                          TextStyle(color: Colors.white),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide:
                                            BorderSide(color: Colors.grey),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide:
                                            BorderSide(color: Colors.grey),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide:
                                            BorderSide(color: primaryColor),
                                      ),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.add, color: primaryColor),
                                  onPressed: () {
                                    setState(() {
                                      String text =
                                          _hashtagController.text.trim();
                                      if (text.isNotEmpty) {
                                        if (text.startsWith('@')) {
                                          _mentions.add(text.substring(1));
                                        } else if (text.startsWith('#')) {
                                          _hashtags.add(text.substring(1));
                                        } else {
                                          _hashtags.add(text);
                                        }
                                        _hashtagController.clear();
                                      }
                                    });
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              language == 'tr'
                                  ? 'Etiketler ve Kullanıcılar'
                                  : 'Hashtags and Mentions',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    spacing: 8,
                                    children: _hashtags
                                        .map((tag) => Chip(
                                              backgroundColor:
                                                  primaryColor.withOpacity(0.3),
                                              label: Text('#$tag',
                                                  style: TextStyle(
                                                      color: Colors.white)),
                                              deleteIcon: Icon(Icons.close,
                                                  size: 18,
                                                  color: Colors.white),
                                              onDeleted: () {
                                                setState(() {
                                                  _hashtags.remove(tag);
                                                });
                                              },
                                            ))
                                        .toList(),
                                  ),
                                  Wrap(
                                    spacing: 8,
                                    children: _mentions
                                        .map((mention) => Chip(
                                              backgroundColor:
                                                  Colors.blue.withOpacity(0.3),
                                              label: Text('@$mention',
                                                  style: TextStyle(
                                                      color: Colors.white)),
                                              deleteIcon: Icon(Icons.close,
                                                  size: 18,
                                                  color: Colors.white),
                                              onDeleted: () {
                                                setState(() {
                                                  _mentions.remove(mention);
                                                });
                                              },
                                            ))
                                        .toList(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Loading indicator with progress
                if (_isUploading)
                  Container(
                    color: Colors.black.withOpacity(0.7),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              CircularProgressIndicator(
                                value: _uploadProgress > 0
                                    ? _uploadProgress
                                    : null,
                                color: primaryColor,
                              ),
                              if (_uploadProgress > 0)
                                Text(
                                  '${(_uploadProgress * 100).toInt()}%',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            language == 'tr' ? 'Yükleniyor...' : 'Uploading...',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Extended Features Bar (new)
                if (!_isTextMode && !_showHashtagMention && !_isUploading)
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Column(
                      children: [
                        // Drawing tool
                        CircleAvatar(
                          backgroundColor:
                              _isDrawingMode ? primaryColor : Colors.black54,
                          radius: 24,
                          child: IconButton(
                            icon: Icon(
                              Icons.brush,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              setState(() {
                                _isDrawingMode = !_isDrawingMode;
                                if (_isDrawingMode) {
                                  _showStickerPicker = false;
                                }
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Stickers/Emoji button
                        CircleAvatar(
                          backgroundColor: _showStickerPicker
                              ? primaryColor
                              : Colors.black54,
                          radius: 24,
                          child: IconButton(
                            icon: Icon(
                              Icons.emoji_emotions,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              setState(() {
                                _showStickerPicker = !_showStickerPicker;
                                if (_showStickerPicker) {
                                  _isDrawingMode = false;
                                }
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                // Completely reworked drawing functionality
                if (_isDrawingMode)
                  Stack(
                    fit: StackFit.expand,
                    children: [
                      // Drawing area with improved event handling
                      GestureDetector(
                        // Using GestureDetector instead of Listener for better control
                        onPanStart: (details) {
                          setState(() {
                            RenderBox renderBox =
                                context.findRenderObject() as RenderBox;
                            Offset localPosition =
                                renderBox.globalToLocal(details.globalPosition);
                            _currentStroke = [localPosition];
                          });
                        },
                        onPanUpdate: (details) {
                          setState(() {
                            RenderBox renderBox =
                                context.findRenderObject() as RenderBox;
                            Offset localPosition =
                                renderBox.globalToLocal(details.globalPosition);
                            _currentStroke.add(localPosition);
                          });
                        },
                        onPanEnd: (details) {
                          if (_currentStroke.length > 1) {
                            setState(() {
                              _strokes.add(
                                DrawingStroke(
                                  points: List.from(_currentStroke),
                                  color: _drawingColor,
                                  width: _brushSize,
                                ),
                              );
                              _currentStroke = [];
                            });
                          }
                        },
                        child: Container(
                          color: Colors
                              .transparent, // Transparent container to capture all touches
                          child: CustomPaint(
                            painter: DrawingPainter(
                              strokes: _strokes,
                              currentStroke: _currentStroke,
                              currentColor: _drawingColor,
                              currentWidth: _brushSize,
                            ),
                            size: Size.infinite,
                          ),
                        ),
                      ),

                      // Drawing tools panel - remain at the same location
                      Positioned(
                        bottom: 110,
                        left: 0,
                        right: 0,
                        child: Container(
                          color: Colors.black54,
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Brush size slider
                              Row(
                                children: [
                                  const Icon(Icons.line_weight,
                                      color: Colors.white, size: 18),
                                  Expanded(
                                    child: Slider(
                                      value: _brushSize,
                                      min: 1.0,
                                      max: 20.0,
                                      activeColor: _drawingColor,
                                      onChanged: (value) {
                                        setState(() {
                                          _brushSize = value;
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),

                              // Color palette and tools - wrap in SingleChildScrollView to handle overflow
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    // Undo button
                                    IconButton(
                                      icon: const Icon(Icons.undo,
                                          color: Colors.white),
                                      onPressed: _strokes.isNotEmpty
                                          ? () {
                                              setState(() {
                                                _strokes.removeLast();
                                              });
                                            }
                                          : null,
                                      constraints: BoxConstraints.tightFor(
                                          width: 40, height: 40),
                                      padding: EdgeInsets.zero,
                                    ),

                                    // Color selectors
                                    for (Color color in [
                                      Colors.white,
                                      Colors.black,
                                      Colors.red,
                                      Colors.green,
                                      Colors.blue,
                                      Colors.yellow
                                    ])
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 4),
                                        child: GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _drawingColor = color;
                                            });
                                          },
                                          child: Container(
                                            width: 24,
                                            height: 24,
                                            decoration: BoxDecoration(
                                              color: color,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: _drawingColor == color
                                                    ? primaryColor
                                                    : Colors.white,
                                                width: _drawingColor == color
                                                    ? 2
                                                    : 1,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),

                                    // Clear all button
                                    IconButton(
                                      icon: const Icon(Icons.clear_all,
                                          color: Colors.white),
                                      onPressed: _strokes.isNotEmpty
                                          ? () {
                                              setState(() {
                                                _strokes = [];
                                              });
                                            }
                                          : null,
                                      constraints: BoxConstraints.tightFor(
                                          width: 40, height: 40),
                                      padding: EdgeInsets.zero,
                                    ),

                                    // Done button
                                    IconButton(
                                      icon: Icon(Icons.check,
                                          color: primaryColor),
                                      onPressed: () {
                                        setState(() {
                                          _isDrawingMode = false;
                                        });
                                      },
                                      constraints: BoxConstraints.tightFor(
                                          width: 40, height: 40),
                                      padding: EdgeInsets.zero,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                // Sticker Picker Panel
                if (_showStickerPicker)
                  Container(
                    color: Colors.black.withOpacity(0.85),
                    child: Column(
                      children: [
                        // Header
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Text(
                                language == 'tr' ? 'Çıkartmalar' : 'Stickers',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.close,
                                    color: Colors.white),
                                onPressed: () {
                                  setState(() {
                                    _showStickerPicker = false;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),

                        // Stickers grid
                        Expanded(
                          child: GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              childAspectRatio: 1,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                            itemCount: _popularEmojis.length,
                            itemBuilder: (context, index) {
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _stickers.add(
                                      StickerItem(
                                        content: _popularEmojis[index],
                                        x: MediaQuery.of(context).size.width /
                                                2 -
                                            30,
                                        y: MediaQuery.of(context).size.height /
                                            3,
                                        scale: 1.0,
                                        rotation: 0.0,
                                      ),
                                    );
                                    _showStickerPicker = false;
                                  });
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white10,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Text(
                                      _popularEmojis[index],
                                      style: const TextStyle(fontSize: 32),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                // Render all placed stickers
                ..._stickers.map((sticker) => Positioned(
                      left: sticker.x,
                      top: sticker.y,
                      child: GestureDetector(
                        onScaleStart: (details) {
                          // Store initial values for this specific sticker
                          _initialScale = sticker.scale;
                          _initialRotation = sticker.rotation;
                        },
                        onScaleUpdate: (details) {
                          setState(() {
                            // Get index safely with a null check
                            final index = _stickers.indexOf(sticker);

                            // Only update if the sticker still exists in the list
                            if (index >= 0 && index < _stickers.length) {
                              _stickers[index] = StickerItem(
                                content: sticker.content,
                                x: sticker.x + details.focalPointDelta.dx,
                                y: sticker.y + details.focalPointDelta.dy,
                                scale: _initialScale * details.scale,
                                rotation: _initialRotation + details.rotation,
                              );
                            }
                          });
                        },
                        onLongPress: () {
                          setState(() {
                            _stickers.remove(sticker);
                          });
                        },
                        child: Transform.scale(
                          scale: sticker.scale,
                          child: Transform.rotate(
                            angle: sticker.rotation,
                            child: Text(
                              sticker.content,
                              style: const TextStyle(fontSize: 50),
                            ),
                          ),
                        ),
                      ),
                    )),

                // ...existing code...
              ],
            ),
          ),

          // Bottom filters
          if (!_isTextMode && !_showHashtagMention)
            Container(
              height: 100,
              color: Colors.black,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: filters.length,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedFilter = filters[index];
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.all(8),
                      width: 80,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: selectedFilter == filters[index]
                              ? primaryColor
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: ColorFiltered(
                        colorFilter: ColorFilter.matrix(
                          filters[index].matrix ??
                              [
                                1,
                                0,
                                0,
                                0,
                                0,
                                0,
                                1,
                                0,
                                0,
                                0,
                                0,
                                0,
                                1,
                                0,
                                0,
                                0,
                                0,
                                0,
                                1,
                                0,
                              ],
                        ),
                        child: Image.file(
                          widget.imageFile,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  // Method to show quality settings dialog
  void _showQualitySettings(
      BuildContext context, Color primaryColor, String language) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black,
      isDismissible: true, // Allow dismissal by tapping outside
      enableDrag: true, // Allow dragging to dismiss
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    language == 'tr' ? 'Ayarlar' : 'Settings',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Watermark settings
                  SwitchListTile(
                    title: Text(
                      language == 'tr' ? 'Filigran Göster' : 'Show Watermark',
                      style: TextStyle(color: Colors.white),
                    ),
                    value: _showWatermark,
                    activeColor: primaryColor,
                    onChanged: (value) {
                      setModalState(() {
                        setState(() {
                          _showWatermark = value;
                        });
                      });
                    },
                  ),

                  if (_showWatermark)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: TextField(
                        style: TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: language == 'tr'
                              ? 'Filigran metni'
                              : 'Watermark text',
                          hintStyle: TextStyle(color: Colors.white54),
                        ),
                        onChanged: (value) {
                          setModalState(() {
                            setState(() {
                              _watermarkText = value;
                            });
                          });
                        },
                        controller: TextEditingController(text: _watermarkText),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Image quality slider
                  Text(
                    language == 'tr'
                        ? 'Resim Kalitesi: $_imageQuality%'
                        : 'Image Quality: $_imageQuality%',
                    style: TextStyle(color: Colors.white),
                  ),
                  Slider(
                    value: _imageQuality.toDouble(),
                    min: 30,
                    max: 100,
                    divisions: 7,
                    activeColor: primaryColor,
                    inactiveColor: Colors.grey,
                    onChanged: (value) {
                      setModalState(() {
                        setState(() {
                          _imageQuality = value.round();
                        });
                      });
                    },
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          language == 'tr' ? 'Düşük' : 'Low',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        Text(
                          language == 'tr' ? 'Yüksek' : 'High',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _captureAndUpload() async {
    if (_isUploading) return;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      // Capture the widget as an image
      RenderRepaintBoundary boundary = _globalKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        throw Exception("Failed to get image data");
      }

      Uint8List pngBytes = byteData.buffer.asUint8List();

      // Create a temporary file to save the captured image
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/${const Uuid().v4()}.png');

      // Save the PNG with transparency preserved
      await tempFile.writeAsBytes(pngBytes);

      // Compress the image if needed (based on quality setting)
      if (_imageQuality < 100) {
        final img.Image? originalImage = img.decodeImage(pngBytes);
        if (originalImage != null) {
          final img.Image compressedImage = img.copyResize(
            originalImage,
            width: (originalImage.width * (_imageQuality / 100)).round(),
            height: (originalImage.height * (_imageQuality / 100)).round(),
            interpolation: img.Interpolation.average,
          );

          final compressedBytes = img.encodePng(compressedImage, level: 6);
          await tempFile.writeAsBytes(compressedBytes);
        }
      }

      // Upload to Firebase Storage
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("User not logged in");
      }

      final String fileName = const Uuid().v4();
      final Reference storageRef = FirebaseStorage.instance
          .ref()
          .child('stories')
          .child(user.uid)
          .child('$fileName.png');

      // Set metadata to preserve transparency with PNG format
      final SettableMetadata metadata = SettableMetadata(
        contentType: 'image/png',
        customMetadata: {
          'edited': 'true',
          'quality': _imageQuality.toString(),
          'hasWatermark': _showWatermark.toString(),
          'hasHashtags': _hashtags.isNotEmpty.toString(),
          'hasMentions': _mentions.isNotEmpty.toString(),
        },
      );

      // Upload the file with progress tracking
      final UploadTask uploadTask = storageRef.putFile(tempFile, metadata);

      // Track upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        if (snapshot.state == TaskState.running) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          setState(() {
            _uploadProgress = progress;
          });
        } else if (snapshot.state == TaskState.error) {
          if (mounted) {
            setState(() {
              _isUploading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(ref.watch(lang) == 'tr'
                  ? 'Yükleme başarısız oldu'
                  : 'Upload failed'),
              backgroundColor: Colors.red,
            ));
          }
        }
      }, onError: (error) {
        if (mounted) {
          setState(() {
            _isUploading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                ref.watch(lang) == 'tr' ? 'Yükleme hatası' : 'Upload error'),
            backgroundColor: Colors.red,
          ));
        }
      });

      // Complete the upload
      final TaskSnapshot taskSnapshot = await uploadTask;
      final String downloadUrl = await taskSnapshot.ref.getDownloadURL();

      // Create story document in Firestore with hashtags and mentions
      final now = Timestamp.now();
      final expiresAt =
          Timestamp.fromDate(DateTime.now().add(const Duration(hours: 24)));

      await FirebaseFirestore.instance.collection('stories').add({
        'userId': user.uid,
        'userPhotoURL': user.photoURL,
        'userName': user.displayName,
        'media': downloadUrl,
        'description': '', // Empty description to save space
        'timestamp': now,
        'expiresAt': expiresAt,
        'viewedBy': [],
        'likedBy': [],
        'hashtags': _hashtags,
        'mentions': _mentions,
        'hasDrawing': _strokes.isNotEmpty,
        'hasStickers': _stickers.isNotEmpty,
      });

      // Delete the temporary file
      if (tempFile.existsSync()) {
        await tempFile.delete();
      }

      if (!mounted) return;

      // Success callback
      widget.onComplete(true);

      // Close the editor
      Navigator.pop(context);
    } catch (e) {
      print('Error capturing and uploading: $e');
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ));

        // Error callback
        widget.onComplete(false);
      }
    }
  }
}

// Supporting classes for new features

class DrawingStroke {
  final List<Offset> points;
  final Color color;
  final double width;

  DrawingStroke({
    required this.points,
    required this.color,
    required this.width,
  });
}

class DrawingPainter extends CustomPainter {
  final List<DrawingStroke> strokes;
  final List<Offset> currentStroke;
  final Color currentColor;
  final double currentWidth;

  DrawingPainter({
    required this.strokes,
    required this.currentStroke,
    required this.currentColor,
    required this.currentWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Improved drawing path construction for better performance and quality

    // Function to draw a single stroke
    void drawStroke(List<Offset> points, Color color, double width) {
      if (points.isEmpty) return;

      final paint = Paint()
        ..color = color
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      if (points.length == 1) {
        // For a single point, draw a circle to make it visible
        canvas.drawCircle(points.first, width / 2, paint);
      } else {
        // For a stroke with multiple points, create a smooth path
        final path = Path();

        // Start at the first point
        path.moveTo(points.first.dx, points.first.dy);

        // Use quadratic bezier curves for smoother lines between points
        for (int i = 0; i < points.length - 1; i++) {
          final p0 = points[i];
          final p1 = points[i + 1];

          // Simple direct line for now (more reliable)
          path.lineTo(p1.dx, p1.dy);

          // Alternatively, for smoother curves (but can be less reliable):
          // final midPoint = Offset((p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
          // path.quadraticBezierTo(p0.dx, p0.dy, midPoint.dx, midPoint.dy);
        }

        canvas.drawPath(path, paint);
      }
    }

    // Draw all completed strokes
    for (final stroke in strokes) {
      drawStroke(stroke.points, stroke.color, stroke.width);
    }

    // Draw the current stroke being drawn
    drawStroke(currentStroke, currentColor, currentWidth);
  }

  @override
  bool shouldRepaint(covariant DrawingPainter oldDelegate) {
    return oldDelegate.strokes != strokes ||
        oldDelegate.currentStroke != currentStroke ||
        oldDelegate.currentColor != currentColor ||
        oldDelegate.currentWidth != currentWidth;
  }
}

class StickerItem {
  final String content;
  final double x;
  final double y;
  final double scale;
  final double rotation;

  // Simplify by removing unnecessary fields that were causing problems
  StickerItem({
    required this.content,
    required this.x,
    required this.y,
    required this.scale,
    required this.rotation,
  });
}

class FilterOption {
  final String name;
  final List<double>? matrix;

  FilterOption({required this.name, required this.matrix});
}
