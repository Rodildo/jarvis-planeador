import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:record/record.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _energyController = TextEditingController();
  final _audioRecorder = AudioRecorder();
  
  bool _isLoading = false;
  bool _isRecording = false;
  String _jarvisMessage = "¡Buenos días! Soy Jarvis. ¿Del 1 al 5, cómo está tu nivel de energía hoy?";
  
  Map<String, dynamic>? _morningOptions;
  Map<String, dynamic> _selectedActions = {};
  bool _dayStarted = false;
  bool _showMiddayInput = false;

  @override
  void initState() {
    super.initState();
    _energyController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _energyController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _sendAudioToBackend(String path) async {
    setState(() => _isLoading = true);
    try {
      final audioData = await http.get(Uri.parse(path));
      final bytes = audioData.bodyBytes;
      
      var request = http.MultipartRequest('POST', Uri.parse('http://2.25.120.253:3000/api/transcribe'));
      request.files.add(http.MultipartFile.fromBytes('audio', bytes, filename: 'audio.webm'));
      
      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      
      if (response.statusCode == 200) {
        final text = jsonDecode(responseData)['text'];
        if (text != null && text.isNotEmpty) {
          setState(() {
            _energyController.text = text;
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error subiendo audio: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _requestBriefing() async {
    // Basic regex to find the first digit 1-5 in the text to make it more flexible for transcribed audio
    final text = _energyController.text.trim();
    int? energyLevel = int.tryParse(text);
    if (energyLevel == null) {
      final match = RegExp(r'[1-5]').firstMatch(text);
      if (match != null) {
        energyLevel = int.parse(match.group(0)!);
      }
    }

    if (energyLevel == null || energyLevel < 1 || energyLevel > 5) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ingresa nivel 1-5')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('http://2.25.120.253:3000/api/briefing'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': 'default_user',
          'date': DateTime.now().toIso8601String().split('T')[0],
          'energyLevel': energyLevel
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _morningOptions = data['briefing'];
          _jarvisMessage = "Aquí tienes tus opciones para hoy. Selecciona una intensidad por cada objetivo.";
        });
      }
    } catch (e) {
      setState(() => _jarvisMessage = "Error de conexión: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmDay() async {
    setState(() => _isLoading = true);
    try {
      await http.post(
        Uri.parse('http://2.25.120.253:3000/api/daily-actions'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': 'default_user',
          'date': DateTime.now().toIso8601String().split('T')[0],
          'actions': _selectedActions
        }),
      );
      setState(() {
        _dayStarted = true;
        _jarvisMessage = "¡Día guardado con éxito! Ve a cumplir tus metas. Me comunicaré contigo en 6 horas.";
      });
    } catch (e) {
      setState(() => _jarvisMessage = "Error guardando el día: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _triggerMiddayCheck() async {
    final text = _energyController.text.trim();
    int? energyLevel = int.tryParse(text);
    if (energyLevel == null) {
      final match = RegExp(r'[1-5]').firstMatch(text);
      if (match != null) energyLevel = int.parse(match.group(0)!);
    }

    if (energyLevel == null || energyLevel < 1 || energyLevel > 5) return;
    
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('http://2.25.120.253:3000/api/midday'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': 'default_user',
          'date': DateTime.now().toIso8601String().split('T')[0],
          'energyLevel': energyLevel
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _jarvisMessage = data['message'];
          _showMiddayInput = false;
        });
      }
    } catch (e) {
      setState(() => _jarvisMessage = "Error en el chequeo de 6h: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildOptionCard(String goal, dynamic option) {
    bool isSelected = _selectedActions[goal] == option;
    
    Color intensityColor;
    switch(option['intensity']) {
      case 'Suave': intensityColor = Colors.greenAccent; break;
      case 'Intensa': intensityColor = Colors.pinkAccent; break;
      default: intensityColor = Colors.amberAccent;
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedActions[goal] = option;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 16),
        width: 170,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? intensityColor.withOpacity(0.15) : const Color(0xFF1E293B),
          border: Border.all(
            color: isSelected ? intensityColor : const Color(0xFF334155),
            width: isSelected ? 2 : 1
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected ? [BoxShadow(color: intensityColor.withOpacity(0.2), blurRadius: 10)] : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(option['intensity'] ?? 'Media', style: GoogleFonts.outfit(color: intensityColor, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Expanded(
              child: Text(option['action'] ?? '', 
                style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4), 
                maxLines: 4, 
                overflow: TextOverflow.ellipsis
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.timer_outlined, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(option['time_estimate'] ?? '-- min', style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            )
          ],
        ),
      ).animate().scale(duration: 200.ms, curve: Curves.easeOut),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool canConfirm = _morningOptions != null && _selectedActions.length == _morningOptions!.keys.length;
    bool canShowMic = _energyController.text.trim().isEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.psychology, color: Colors.cyanAccent, size: 28)
                .animate(onPlay: (controller) => controller.repeat())
                .shimmer(duration: 2500.ms, color: Colors.white),
            const SizedBox(width: 10),
            Text('JARVIS', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, letterSpacing: 3.0, color: Colors.white)),
          ],
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Jarvis Message Bubble
          Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B).withOpacity(0.9),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.assistant, color: Colors.cyanAccent, size: 40),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(_jarvisMessage, 
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 15, height: 1.5)
                  ),
                ),
              ],
            ),
          ).animate().slideY(begin: -0.2, end: 0).fadeIn(),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(20.0),
              child: CircularProgressIndicator(color: Colors.cyanAccent),
            ),

          // Render Morning Options
          if (_morningOptions != null && !_dayStarted)
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: _morningOptions!.entries.map((entry) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(entry.key.toUpperCase(), style: GoogleFonts.outfit(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
                      ),
                      SizedBox(
                        height: 160,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: (entry.value as List).length,
                          itemBuilder: (context, index) {
                            return _buildOptionCard(entry.key, entry.value[index]);
                          },
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),

          // Confirm Button
          if (canConfirm && !_dayStarted)
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: ElevatedButton(
                onPressed: _confirmDay,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyanAccent,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text('Confirmar Selección', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
              ).animate().fadeIn(),
            ),

          // Midday Simulator Button
          if (_dayStarted && !_showMiddayInput)
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: ElevatedButton(
                onPressed: () => setState(() => _showMiddayInput = true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pinkAccent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text('Simular Check-in (+6 horas)', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
              ).animate().fadeIn(),
            ),

          // Input Area (For initial energy or midday energy)
          if (_morningOptions == null || _showMiddayInput)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _energyController,
                      style: GoogleFonts.inter(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: _isRecording ? 'Grabando...' : 'Nivel de energía (1-5)...',
                        hintStyle: TextStyle(color: _isRecording ? Colors.redAccent : Colors.white.withOpacity(0.3)),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      ),
                      onSubmitted: (_) {
                        if (!_isLoading) {
                          _showMiddayInput ? _triggerMiddayCheck() : _requestBriefing();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onLongPressStart: canShowMic ? (_) async {
                      if (await _audioRecorder.hasPermission()) {
                        await _audioRecorder.start(const RecordConfig(), path: 'audio.webm');
                        setState(() => _isRecording = true);
                      }
                    } : null,
                    onLongPressEnd: canShowMic ? (_) async {
                      if (_isRecording) {
                        final path = await _audioRecorder.stop();
                        setState(() => _isRecording = false);
                        if (path != null) await _sendAudioToBackend(path);
                      }
                    } : null,
                    onTap: _isLoading ? null : () {
                      if (!canShowMic) {
                        _showMiddayInput ? _triggerMiddayCheck() : _requestBriefing();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _isRecording ? Colors.redAccent : Colors.cyanAccent, 
                        shape: BoxShape.circle
                      ),
                      child: Icon(
                        canShowMic ? Icons.mic : Icons.send, 
                        color: _isRecording ? Colors.white : const Color(0xFF0F172A), 
                        size: 22
                      )
                      .animate(target: _isRecording ? 1 : 0)
                      .scale(begin: const Offset(1,1), end: const Offset(1.2, 1.2)),
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
