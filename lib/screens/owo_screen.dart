import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/owo_entry.dart';
import '../services/hybrid_storage_service.dart';

class OwesOwnsScreen extends StatefulWidget {
  final bool contentOnly; 
  const OwesOwnsScreen({super.key, this.contentOnly = false});

  @override
  State<OwesOwnsScreen> createState() => _OwesOwnsScreenState();
}

class _OwesOwnsScreenState extends State<OwesOwnsScreen> {
  List<OweEntry> _entries = [];
  String _query = '';
  bool _showSettled = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final raw = await OwesOwnsStorage.getOwoEntries();
    if (mounted) {
      setState(() {
        _entries = raw.map((e) => OweEntry.fromMap(e)).toList()..sort((a,b)=> b.createdAt.compareTo(a.createdAt));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bodyContent = ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildHeaderSummary(),
        const SizedBox(height: 12),
        _buildSearchAndFilter(),
        const SizedBox(height: 12),
        if (_filtered().isEmpty)
          _emptyState()
        else
          ..._filtered().map(_tile),
        const SizedBox(height: 40),
      ],
    );

    final fullContent = Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF032221), Colors.black, Color(0xFF032221)],
        ),
      ),
      child: SafeArea(
        top: !widget.contentOnly,
        bottom: true,
        child: bodyContent,
      ),
    );

    if (widget.contentOnly) return Container(color: Colors.transparent, child: bodyContent);

    return Scaffold(
      backgroundColor: const Color(0xFF032221),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF032221), Colors.black],
            ),
          ),
          child: AppBar(
            title: Text('Owes & Owns', style: GoogleFonts.nunito(color: Colors.white)),
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              IconButton(onPressed: _showAddDialog, icon: const Icon(Icons.add, color: Colors.white)),
            ],
          ),
        ),
      ),
      body: fullContent,
    );
  }

  List<OweEntry> _filtered() {
    return _entries.where((e){
      if (!_showSettled && e.settled) return false;
      if (_query.isEmpty) return true;
      return e.counterparty.toLowerCase().contains(_query.toLowerCase()) || e.note.toLowerCase().contains(_query.toLowerCase());
    }).toList();
  }

  Widget _buildHeaderSummary() {
    final owedToYou = _entries.where((e)=> e.direction == 'owned' && !e.settled).fold(0.0, (s,e)=> s + e.amount);
    final youOwe = _entries.where((e)=> e.direction == 'owe' && !e.settled).fold(0.0, (s,e)=> s + e.amount);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05), 
        borderRadius: BorderRadius.circular(12), 
        border: Border.all(color: Colors.white.withOpacity(0.1))
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _summaryItem('You Owe', youOwe, Colors.orangeAccent),
          _summaryItem('Owed To You', owedToYou, Colors.lightGreen),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, double amount, Color color) {
    return Column(
      children: [
        Text('₹${amount.toStringAsFixed(0)}', style: GoogleFonts.nunito(color: color, fontSize: 18, fontWeight: FontWeight.w700)),
        Text(label, style: GoogleFonts.nunito(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  Widget _buildSearchAndFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          onChanged: (v)=> setState(()=> _query = v.trim()),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            hintText: 'Search person or note...',
            hintStyle: const TextStyle(color: Colors.white60),
            prefixIcon: const Icon(Icons.search, color: Colors.white70),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white24)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white24)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.green)),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            FilterChip(
              label: Text('Show Settled', style: GoogleFonts.nunito(color: Colors.white)),
              selected: _showSettled,
              onSelected: (v)=> setState(()=> _showSettled = v),
              backgroundColor: Colors.transparent,
              selectedColor: Colors.green.withOpacity(0.5),
              checkmarkColor: Colors.white,
              shape: const StadiumBorder(side: BorderSide(color: Colors.white24)),
              visualDensity: VisualDensity.compact,
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _showAddDialog,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Entry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green, 
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _tile(OweEntry e) {
    final color = e.direction == 'owe' ? Colors.orangeAccent : Colors.lightGreen;
    final isPending = e.syncStatus == 'pending';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05), 
        borderRadius: BorderRadius.circular(12), 
        border: Border.all(color: Colors.white.withOpacity(0.1))
      ),
      child: ListTile(
        title: Row(
          children: [
            Text('${e.counterparty} • ₹${e.amount.toStringAsFixed(0)}', 
              style: GoogleFonts.nunito(color: color, fontWeight: FontWeight.w700)),
            if (isPending) ...[
              const SizedBox(width: 8),
              const Icon(Icons.cloud_off, size: 14, color: Colors.orangeAccent),
            ],
          ],
        ),
        subtitle: Text(_subtitle(e), style: GoogleFonts.nunito(color: Colors.white70, fontSize: 12)),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white70),
          color: const Color(0xFF0E1F1F),
          onSelected: (v)=> _handleAction(v, e),
          itemBuilder: (ctx)=> [
            PopupMenuItem(value: 'toggle', child: Text(e.settled ? 'Mark as Open' : 'Mark as Settled', style: const TextStyle(color: Colors.white))),
            const PopupMenuItem(value: 'edit', child: Text('Edit', style: TextStyle(color: Colors.white))),
            PopupMenuItem(value: 'pay', child: Text(e.direction=='owned' ? 'Record received' : 'Record payment', style: const TextStyle(color: Colors.white))),
            const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
          ],
        ),
      ),
    );
  }

  String _subtitle(OweEntry e) {
    final dir = e.direction == 'owe' ? 'You owe' : 'Owed to you';
    final due = e.dueDate != null ? ' • Due ${e.dueDate!.day}/${e.dueDate!.month}' : '';
    final note = e.note.isNotEmpty ? ' • ${e.note}' : '';
    final status = e.settled ? ' • Settled' : '';
    return '$dir$due$note$status';
  }

  Future<void> _handleAction(String action, OweEntry e) async {
    if (action == 'toggle') {
      final updated = OweEntry(
        id: e.id,
        counterparty: e.counterparty,
        direction: e.direction,
        amount: e.amount,
        note: e.note,
        createdAt: e.createdAt,
        dueDate: e.dueDate,
        settled: !e.settled,
      );
      await OwesOwnsStorage.updateOwoEntry(updated.toMap());
      if (!e.settled && updated.settled) {
        final txn = {
          'transactionId': DateTime.now().microsecondsSinceEpoch.toString(),
          'description': 'Settled: ${e.counterparty}',
          'amount': e.amount,
          'type': e.direction == 'owned' ? 'Credit' : 'Debit',
          'date': DateTime.now().toIso8601String(),
          'category': e.direction == 'owned' ? '' : 'OWO',
          'status': 'Completed',
        };
        await HybridStorageService.addTransaction(txn);
      }
      await _load();
    } else if (action == 'edit') {
      _showAddDialog(existing: e);
    } else if (action == 'pay') {
      final c = TextEditingController();
      final ok = await showDialog<bool>(
        context: context, 
        builder: (ctx)=> AlertDialog(
          backgroundColor: const Color(0xFF0E1F1F),
          title: Text('Enter amount', style: GoogleFonts.nunito(color: Colors.white)), 
          content: TextField(
            controller: c, 
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.green)),
            ),
          ), 
          actions: [
            TextButton(onPressed: ()=> Navigator.pop(ctx, false), child: const Text('Cancel')), 
            TextButton(onPressed: ()=> Navigator.pop(ctx, true), child: const Text('Save'))
          ]
        )
      );
      if (ok == true) {
        final amt = double.tryParse(c.text.trim()) ?? 0.0;
        if (amt > 0) {
          final newAmt = (e.amount - amt).clamp(0, double.infinity).toDouble();
          final updated = OweEntry(id: e.id, counterparty: e.counterparty, direction: e.direction, amount: newAmt, note: e.note, createdAt: e.createdAt, dueDate: e.dueDate, settled: newAmt == 0.0 ? true : e.settled);
          await OwesOwnsStorage.updateOwoEntry(updated.toMap());
          final txn = {
            'transactionId': DateTime.now().microsecondsSinceEpoch.toString(),
            'description': (e.direction=='owned' ? 'Received from ' : 'Paid to ') + e.counterparty,
            'amount': amt,
            'type': e.direction=='owned' ? 'Credit' : 'Debit',
            'date': DateTime.now().toIso8601String(),
            'category': e.direction=='owned' ? '' : 'OWO',
            'status': 'Completed',
          };
          await HybridStorageService.addTransaction(txn);
          await _load();
        }
      }
    } else if (action == 'delete') {
      final ok = await showDialog<bool>(
        context: context, 
        builder: (ctx)=> AlertDialog(
          backgroundColor: const Color(0xFF0E1F1F),
          title: Text('Delete?', style: GoogleFonts.nunito(color: Colors.white)), 
          actions: [
            TextButton(onPressed: ()=> Navigator.pop(ctx, false), child: const Text('Cancel')), 
            TextButton(onPressed: ()=> Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red)))
          ]
        )
      );
      if (ok == true) {
        await OwesOwnsStorage.deleteOwoEntry(e.id);
        await _load();
      }
    }
  }

  Widget _emptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      child: Column(
        children: [
          const Icon(Icons.receipt_long, color: Colors.white24, size: 48),
          const SizedBox(height: 8),
          Text('No entries yet', style: GoogleFonts.nunito(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 4),
          Text('Tap "Add Entry" above to create one', style: GoogleFonts.nunito(color: Colors.white24, fontSize: 12)),
        ],
      ),
    );
  }

  Future<void> _showAddDialog({OweEntry? existing}) async {
    final nameC = TextEditingController(text: existing?.counterparty ?? '');
    final amountC = TextEditingController(text: existing?.amount.toStringAsFixed(0) ?? '');
    final noteC = TextEditingController(text: existing?.note ?? '');
    String dir = existing?.direction ?? 'owe';
    DateTime? due = existing?.dueDate;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx)=> StatefulBuilder(builder: (ctx, setSb){
        return AlertDialog(
          backgroundColor: const Color(0xFF0E1F1F),
          title: Text(existing==null? 'New Entry' : 'Edit Entry', style: GoogleFonts.nunito(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameC, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Person', labelStyle: TextStyle(color: Colors.white70))),
                TextField(controller: amountC, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Amount', labelStyle: TextStyle(color: Colors.white70))),
                TextField(controller: noteC, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Note (optional)', labelStyle: TextStyle(color: Colors.white70))),
                const SizedBox(height: 16),
                DropdownButton<String>(
                  value: dir, 
                  dropdownColor: const Color(0xFF0E1F1F),
                  style: const TextStyle(color: Colors.white),
                  items: const [
                    DropdownMenuItem(value: 'owe', child: Text('You owe')), 
                    DropdownMenuItem(value: 'owned', child: Text('Owed to you'))
                  ], 
                  onChanged: (v)=> setSb(()=> dir = v ?? 'owe')
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: Text(due==null? 'No due date' : 'Due: ${due!.day}/${due!.month}/${due!.year}', style: const TextStyle(color: Colors.white70, fontSize: 12))),
                  TextButton(onPressed: () async { final d = await showDatePicker(context: ctx, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 365*5)), initialDate: due ?? DateTime.now()); if (d!=null) setSb(()=> due = d); }, child: const Text('Pick due', style: TextStyle(color: Colors.green))),
                ]),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: ()=> Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: ()=> Navigator.pop(ctx, true), child: const Text('Save'))
          ],
        );
      }),
    );
    if (ok == true) {
      final amt = double.tryParse(amountC.text.trim()) ?? 0.0;
      final name = nameC.text.trim();
      if (existing == null) {
        final list = await OwesOwnsStorage.getOwoEntries();
        final idx = list.indexWhere((m)=> (m['counterparty'] ?? '').toString().toLowerCase() == name.toLowerCase() && (m['direction'] ?? 'owe').toString() == dir && (m['settled'] ?? false) == false);
        if (idx != -1) {
          final curr = OweEntry.fromMap(list[idx]);
          final merged = OweEntry(id: curr.id, counterparty: curr.counterparty, direction: curr.direction, amount: curr.amount + amt, note: (curr.note.isNotEmpty ? curr.note + '; ' : '') + noteC.text.trim(), createdAt: curr.createdAt, dueDate: due ?? curr.dueDate, settled: false);
          await OwesOwnsStorage.updateOwoEntry(merged.toMap());
        } else {
          final entry = OweEntry(id: DateTime.now().microsecondsSinceEpoch.toString(), counterparty: name, direction: dir, amount: amt, note: noteC.text.trim(), createdAt: DateTime.now(), dueDate: due, settled: false);
          await OwesOwnsStorage.addOwoEntry(entry.toMap());
        }
      } else {
        final entry = OweEntry(id: existing.id, counterparty: name, direction: dir, amount: amt, note: noteC.text.trim(), createdAt: existing.createdAt, dueDate: due, settled: existing.settled);
        await OwesOwnsStorage.updateOwoEntry(entry.toMap());
      }
      await _load();
    }
  }
}
