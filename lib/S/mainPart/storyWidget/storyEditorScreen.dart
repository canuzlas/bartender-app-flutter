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

  @override
  void initState() {
    super.initState();
    selectedFilter = filters[0]; // Start with normal filter
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
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
          IconButton(
            icon: Icon(
              Icons.text_fields,
              color: _isTextMode ? primaryColor : Colors.white,
            ),
            onPressed: () {
              setState(() {
                _isTextMode = !_isTextMode;
                if (!_isTextMode) {
                  _inputText = _textController.text;
                  _textController.clear();
                }
              });
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
                    ],
                  ),
                ),

                // Text input overlay with new options
                if (_isTextMode)
                  Container(
                    color: Colors.black.withOpacity(0.7),
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextField(
                          controller: _textController,
                          style: TextStyle(
                            color: _textColor,
                            fontSize: _textSize,
                            fontWeight:
                                _isBold ? FontWeight.bold : FontWeight.normal,
                            fontStyle:
                                _isItalic ? FontStyle.italic : FontStyle.normal,
                          ),
                          textAlign: _textAlignment,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: language == 'tr'
                                ? 'Metin girin...'
                                : 'Enter text...',
                            hintStyle:
                                TextStyle(color: _textColor.withOpacity(0.7)),
                            border: InputBorder.none,
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Text size slider
                        Row(
                          children: [
                            const Icon(Icons.format_size, color: Colors.white),
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
                                color: _isBold ? primaryColor : Colors.white,
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
                                color: _isItalic ? primaryColor : Colors.white,
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
                                      MediaQuery.of(context).size.width / 2 -
                                          50;
                                  _textY =
                                      MediaQuery.of(context).size.height / 4;
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
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 4),
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: _colorPalette[index],
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: _textColor == _colorPalette[index]
                                          ? primaryColor
                                          : Colors.white,
                                      width: _textColor == _colorPalette[index]
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
                                      _hasTextBackground = !_hasTextBackground;
                                    });
                                  },
                                ),
                                Text(
                                  language == 'tr' ? 'Arkaplan' : 'Background',
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
                                  style: const TextStyle(color: Colors.white),
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
                                            margin: const EdgeInsets.symmetric(
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

                // Loading indicator
                if (_isUploading)
                  Container(
                    color: Colors.black.withOpacity(0.7),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: primaryColor),
                          const SizedBox(height: 16),
                          Text(
                            language == 'tr' ? 'Yükleniyor...' : 'Uploading...',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Bottom filters
          if (!_isTextMode)
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

  Future<void> _captureAndUpload() async {
    if (_isUploading) return;

    setState(() {
      _isUploading = true;
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
        customMetadata: {'edited': 'true'},
      );

      // Upload the file
      final UploadTask uploadTask = storageRef.putFile(tempFile, metadata);

      // Handle potential errors
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        if (snapshot.state == TaskState.error) {
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

      // Create story document in Firestore
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

class FilterOption {
  final String name;
  final List<double>? matrix;

  FilterOption({required this.name, required this.matrix});
}
