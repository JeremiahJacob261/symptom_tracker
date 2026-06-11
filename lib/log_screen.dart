import 'package:flutter/material.dart';
import 'data/symptom_storage.dart';
import 'models/symptom_entry.dart';

class LogScreen extends StatefulWidget {
  const LogScreen({super.key});

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  double _painLevel = 5;
  String? _mood;
  String? _bodyArea;
  final List<String> _chatNotes = [];
  final TextEditingController _chatController = TextEditingController();

  void _addChatNote() {
    if (_chatController.text.isNotEmpty) {
      setState(() {
        _chatNotes.add(_chatController.text);
        _chatController.clear();
      });
    }
  }

  void _saveEntry() {
    if (_mood != null && _bodyArea != null) {
      final entry = SymptomEntry(
        date: DateTime.now(),
        painLevel: _painLevel.toInt(),
        mood: _mood!,
        bodyArea: _bodyArea!,
        notes: _chatNotes.join(" | "), // combine chat notes
      );
      SymptomStorage.addEntry(entry);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Entry saved!")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Log Symptom")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text("Pain Level: ${_painLevel.toInt()}"),
            Slider(
              value: _painLevel,
              min: 0,
              max: 10,
              divisions: 10,
              label: _painLevel.toInt().toString(),
              onChanged: (val) {
                setState(() {
                  _painLevel = val;
                });
              },
            ),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: "Mood"),
              items: [
                "sad",
                "worried",
                "neutral",
                "good",
                "happy",
              ].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
              onChanged: (val) {
                setState(() {
                  _mood = val;
                });
              },
            ),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: "Body Area"),
              items: [
                "Head",
                "Chest",
                "Abdomen",
                "Back",
                "Arms",
                "Legs",
                "Throat",
                "Whole Body",
                "Other",
              ].map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
              onChanged: (val) {
                setState(() {
                  _bodyArea = val;
                });
              },
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: _chatNotes.length,
                itemBuilder: (context, index) {
                  return ListTile(title: Text(_chatNotes[index]));
                },
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatController,
                    decoration: const InputDecoration(
                      labelText: "Describe your symptom...",
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _addChatNote,
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _saveEntry, child: const Text("Save")),
          ],
        ),
      ),
    );
  }
}
