import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'chat_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:record/record.dart';

class OnboardingScreen extends StatefulWidget {
  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final List<Map<String, String>> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final _audioRecorder = AudioRecorder();
  
  bool _isLoading = false;
  bool _isRecording = false;
  int _questionCount = 0;
  final int _maxQuestions = 5;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      setState(() {});
    });
    _fetchNextQuestion();
  }

  @override
  void dispose() {
    _controller.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _fetchNextQuestion() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('http://2.25.120.253:3000/api/onboarding/question'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'previousQA': _messages}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _messages.add({'role': 'jarvis', 'text': data['question']});
        });
      }
    } catch (e) {
      setState(() => _messages.add({'role': 'jarvis', 'text': 'Error: $e'}));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitAnswer(String answer) async {
    if (answer.trim().isEmpty) return;
    setState(() {
      _messages.add({'role': 'user', 'text': answer});
      _controller.clear();
      _questionCount++;
    });

    if (_questionCount >= _maxQuestions) {
      await _finalizeOnboarding();
    } else {
      await _fetchNextQuestion();
    }
  }

  Future<void> _finalizeOnboarding() async {
    setState(() {
      _isLoading = true;
      _messages.add({'role': 'jarvis', 'text': 'Creando tu Life Blueprint...'});
    });
    try {
      final response = await http.post(
        Uri.parse('http://2.25.120.253:3000/api/assessment'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': 'default_user', 'answers': jsonEncode(_messages)}),
      );
      if (response.statusCode == 200) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => ChatScreen()));
      }
    } catch (e) {
      setState(() {
        _messages.add({'role': 'jarvis', 'text': 'Error: $e'});
        _isLoading = false;
      });
    }
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
          _submitAnswer(text);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error subiendo audio: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool canShowMic = _controller.text.trim().isEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: Text('Construyendo tu Blueprint', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 18)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final isUser = _messages[index]['role'] == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(16),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                    decoration: BoxDecoration(
                      color: isUser ? const Color(0xFF1F6FEB) : const Color(0xFF161B22),
                      borderRadius: BorderRadius.circular(16),
                      border: isUser ? null : Border.all(color: const Color(0xFF30363D)),
                    ),
                    child: Text(_messages[index]['text']!, style: GoogleFonts.inter(color: Colors.white, fontSize: 15, height: 1.5)),
                  ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),
                );
              },
            ),
          ),
          if (_isLoading)
            const Padding(padding: EdgeInsets.all(20.0), child: CircularProgressIndicator(color: Color(0xFF1F6FEB))),
          
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            decoration: const BoxDecoration(
              color: Color(0xFF0D1117),
              border: Border(top: BorderSide(color: Color(0xFF30363D))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: GoogleFonts.inter(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: _isRecording ? 'Grabando...' : 'Respuesta (o mantén presionado el mic)...',
                      hintStyle: TextStyle(color: _isRecording ? Colors.redAccent : Colors.white.withOpacity(0.5)),
                      filled: true,
                      fillColor: const Color(0xFF161B22),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    ),
                    onSubmitted: _submitAnswer,
                  ),
                ),
                const SizedBox(width: 10),
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
                  onTap: () {
                    if (!canShowMic) {
                      _submitAnswer(_controller.text);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _isRecording ? Colors.redAccent : const Color(0xFF00E5FF),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      canShowMic ? Icons.mic : Icons.send, 
                      color: _isRecording ? Colors.white : Colors.black,
                      size: 24
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
