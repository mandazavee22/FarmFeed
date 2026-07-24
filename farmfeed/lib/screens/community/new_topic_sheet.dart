import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/api_client.dart';

class NewTopicSheet extends StatefulWidget {
  const NewTopicSheet({super.key});

  @override
  State<NewTopicSheet> createState() => _NewTopicSheetState();
}

class _NewTopicSheetState extends State<NewTopicSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  String _selectedCategory = 'General';
  bool _loading = false;

  final _categories = ['General', 'Tips', 'Deals', 'Alerts'];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ApiClient.instance.createForumTopic({
        'title': _titleCtrl.text.trim(),
        'content': _contentCtrl.text.trim(),
        'category': _selectedCategory,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to create topic.')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20),
        child: Form(
          key: _formKey,
          child: ListView(
            controller: ctrl,
            children: [
              Center(
                child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: FarmColors.borderLight,
                        borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 16),
              Text('Start a New Topic',
                  style: FarmTextStyles.headlineMedium.copyWith(color: FarmColors.darkGreen)),
              const SizedBox(height: 20),
              TextFormField(
                controller: _titleCtrl,
                maxLength: 150,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (v) => (v?.trim().isEmpty ?? true) ? 'Title is required' : null,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(labelText: 'Category'),
                items: _categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedCategory = v!),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _contentCtrl,
                maxLines: 6,
                maxLength: 2000,
                decoration: const InputDecoration(
                    labelText: 'What\'s on your mind?',
                    alignLabelWithHint: true),
                validator: (v) => (v?.trim().isEmpty ?? true) ? 'Content is required' : null,
              ),
              const SizedBox(height: 20),
              _loading
                  ? const Center(child: CircularProgressIndicator(color: FarmColors.primaryGreen))
                  : ElevatedButton.icon(
                      onPressed: _submit,
                      icon: const Icon(Icons.send, color: Colors.white),
                      label: Text('Post Topic',
                          style: FarmTextStyles.buttonText),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 52),
                        backgroundColor: FarmColors.primaryGreen,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
