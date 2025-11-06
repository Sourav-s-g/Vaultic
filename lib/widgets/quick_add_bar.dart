import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/parsed_transaction.dart';
import '../services/smart_input_parser.dart';

class QuickAddBar extends StatefulWidget {
  final List<String> categories;
  final Function(ParsedTransaction) onQuickAdd;
  final Function(ParsedTransaction) onExpand;

  const QuickAddBar({
    super.key,
    required this.categories,
    required this.onQuickAdd,
    required this.onExpand,
  });

  @override
  State<QuickAddBar> createState() => _QuickAddBarState();
}

class _QuickAddBarState extends State<QuickAddBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  ParsedTransaction? _parsed;
  List<String> _suggestions = [];
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _controller.text.trim();
    
    if (text.isEmpty) {
      setState(() {
        _parsed = null;
        _suggestions = [];
        _showSuggestions = false;
      });
      return;
    }

    // Parse the input
    final parsed = SmartInputParser.parseInput(text, widget.categories);
    setState(() {
      _parsed = parsed;
    });

    // Get suggestions for autocomplete
    final suggestions = SmartInputParser.getSuggestions(text, widget.categories);
    setState(() {
      _suggestions = suggestions;
      _showSuggestions = suggestions.isNotEmpty && _focusNode.hasFocus;
    });
  }

  void _onFocusChanged() {
    setState(() {
      _showSuggestions = _suggestions.isNotEmpty && _focusNode.hasFocus;
    });
  }

  void _handleSubmit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final parsed = SmartInputParser.parseInput(text, widget.categories);
    
    if (parsed.isHighConfidence && parsed.hasAmount) {
      // Auto-submit if high confidence
      widget.onQuickAdd(parsed);
      _controller.clear();
      _focusNode.unfocus();
    } else {
      // Expand to full dialog for review
      widget.onExpand(parsed);
      _controller.clear();
      _focusNode.unfocus();
    }
  }

  void _handleExpand() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final parsed = SmartInputParser.parseInput(text, widget.categories);
    widget.onExpand(parsed);
    _controller.clear();
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF0E1F1F),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _focusNode.hasFocus ? Colors.green : Colors.white24,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.edit_note,
                color: Colors.white70,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  style: GoogleFonts.nunito(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Type: "Lunch 250" or "Got ₹500 salary"',
                    hintStyle: GoogleFonts.nunito(
                      color: Colors.white38,
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onSubmitted: (_) => _handleSubmit(),
                ),
              ),
              if (_parsed != null && _parsed!.hasAmount) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _parsed!.type == 'Credit' ? Icons.arrow_downward : Icons.arrow_upward,
                        size: 14,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '₹${_parsed!.amount!.toStringAsFixed(0)}',
                        style: GoogleFonts.nunito(
                          color: Colors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_parsed!.hasCategory) ...[
                        const SizedBox(width: 4),
                        Text(
                          '• ${_parsed!.category}',
                          style: GoogleFonts.nunito(
                            color: Colors.green.withOpacity(0.8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  Icons.expand_more,
                  color: Colors.white70,
                  size: 20,
                ),
                onPressed: _handleExpand,
                tooltip: 'Expand to full form',
              ),
              IconButton(
                icon: Icon(
                  Icons.check_circle,
                  color: _parsed != null && _parsed!.hasAmount 
                      ? Colors.green 
                      : Colors.white38,
                  size: 24,
                ),
                onPressed: _handleSubmit,
                tooltip: 'Add transaction',
              ),
            ],
          ),
        ),
        // Suggestions dropdown
        if (_showSuggestions && _suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF0E1F1F),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24),
            ),
            constraints: const BoxConstraints(maxHeight: 150),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _suggestions.length,
              itemBuilder: (context, index) {
                final suggestion = _suggestions[index];
                return ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  title: Text(
                    suggestion,
                    style: GoogleFonts.nunito(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                  onTap: () {
                    final currentText = _controller.text;
                    _controller.text = '$currentText $suggestion';
                    _controller.selection = TextSelection.fromPosition(
                      TextPosition(offset: _controller.text.length),
                    );
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}

