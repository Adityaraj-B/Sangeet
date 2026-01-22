import 'dart:ui';
import 'package:flutter/material.dart';

class AudioQualityScreen extends StatefulWidget {
  const AudioQualityScreen({super.key});

  @override
  State<AudioQualityScreen> createState() => _AudioQualityScreenState();
}

class _AudioQualityScreenState extends State<AudioQualityScreen> {
  String _selected = 'High';

  final List<_QualityOption> _options = const [
    _QualityOption(
      title: 'Low',
      description: 'Low data usage',
    ),
    _QualityOption(
      title: 'Normal',
      description: 'Balanced quality and data',
    ),
    _QualityOption(
      title: 'High',
      description: 'Better sound quality',
    ),
    _QualityOption(
      title: 'Very High',
      description: 'Best quality (uses more data)',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Audio Quality',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: _options.map(_buildTile).toList(),
      ),
    );
  }

  Widget _buildTile(_QualityOption option) {
    final isSelected = _selected == option.title;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: InkWell(
            onTap: () {
              setState(() => _selected = option.title);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 16,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha :isSelected ? 0.14 : 0.08),
                    Colors.white.withValues(alpha :0.03),
                  ],
                ),
                border: Border.all(
                  color: isSelected
                      ? Colors.white.withValues(alpha :0.4)
                      : Colors.white.withValues(alpha :0.18),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          option.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          option.description,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha :0.6),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? Colors.white
                            : Colors.white38,
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                      ),
                    )
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QualityOption {
  final String title;
  final String description;

  const _QualityOption({
    required this.title,
    required this.description,
  });
}
