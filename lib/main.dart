import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const AuraApp());

class AuraApp extends StatelessWidget {
  const AuraApp({super.key});
  @override Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false, title: 'THE VAULT',
    theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: const Color(0xFF03030A), primaryColor: const Color(0xFFD4AF37)),
    home: const AuraHomeScreen());
}

class Vault {
  String id, name, country, currency; List<Item> items;
  Vault({required this.id, required this.name, required this.country, required this.currency, required this.items});
  Map<String, dynamic> toMap() => {'id': id, 'n': name, 'co': country, 'cu': currency, 'i': items.map((e) => e.toMap()).toList()};
  factory Vault.fromMap(Map<String, dynamic> m) => Vault(id: m['id'] ?? "", name: m['n'] ?? "", country: m['co'] ?? "", currency: m['cu'] ?? "", items: m['i'] != null ? (m['i'] as List).map((e) => Item.fromMap(e)).toList() : []);
  double get total => items.fold(0.0, (s, i) => s + (i.isPlus ? i.val : -i.val));
}
class Item {
  String text, cat; double val; bool isPlus; final DateTime d;
  Item({required this.text, required this.val, required this.isPlus, required this.cat, required this.d});
  Map<String, dynamic> toMap() => {'t': text, 'v': val, 'p': isPlus, 'c': cat, 'd': d.toIso8601String()};
  factory Item.fromMap(Map<String, dynamic> m) => Item(text: m['t'], val: m['v'], isPlus: m['p'], cat: m['c'], d: DateTime.parse(m['d']));
}

class AuraHomeScreen extends StatefulWidget {
  const AuraHomeScreen({super.key});
  @override State<AuraHomeScreen> createState() => _AuraHomeScreenState();
}

class _AuraHomeScreenState extends State<AuraHomeScreen> with SingleTickerProviderStateMixin {
  List<Vault> _vaults = []; Vault? _selVault; bool _isUnlocked = false, _successFlash = false;
  String _pin = "", _savedPin = ""; int _setupStep = 0;
  final _t = TextEditingController(), _v = TextEditingController(), _searchCon = TextEditingController(), _vNameCon = TextEditingController();
  final List<TextEditingController> _pCons = List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _fNodes = List.generate(4, (_) => FocusNode());
  bool _plus = true; String _cur = 'SYP', _co = 'Syria', _ln = 'EN', _selCat = 'Cash';
  List<String> _filteredCountries = []; AnimationController? _anim;

  final Map<String, String> _allCurs = {
    'Syria': 'SYP', 'Saudi Arabia': 'SAR', 'UAE': 'AED', 'Jordan': 'JOD', 'Egypt': 'EGP', 'Kuwait': 'KWD', 'Qatar': 'QAR', 'Lebanon': 'LBP', 'Iraq': 'IQD', 'Oman': 'OMR', 'Bahrain': 'BHD', 'Yemen': 'YER', 'Libya': 'LYD', 'Tunisia': 'TND', 'Algeria': 'DZD', 'Morocco': 'MAD', 'Palestine': 'ILS', 'Sudan': 'SDG', 'Mauritania': 'MRU', 'Somalia': 'SOS', 'Djibouti': 'DJF', 'Comoros': 'KMF', 'Germany': 'EUR', 'France': 'EUR', 'Italy': 'EUR', 'Spain': 'EUR', 'Netherlands': 'EUR', 'United Kingdom': 'GBP', 'Turkey': 'TRY', 'Switzerland': 'CHF', 'Sweden': 'SEK', 'Norway': 'NOK', 'Denmark': 'DKK', 'Russia': 'RUB', 'Ukraine': 'UAH', 'United States': '\$', 'Canada': 'CAD', 'Australia': 'AUD', 'New Zealand': 'NZD', 'Japan': 'JPY', 'China': 'CNY', 'South Korea': 'KRW', 'India': 'INR', 'South Africa': 'ZAR', 'Nigeria': 'NGN', 'Brazil': 'BRL', 'Argentina': 'ARS', 'Mexico': 'MXN', 'Singapore': 'SGD', 'Malaysia': 'MYR', 'Thailand': 'THB', 'Indonesia': 'IDR', 'Pakistan': 'PKR'
  };
  final Map<String, Map<String, String>> _dict = {
    'EN': {'name': 'THE VAULT', 'bal': 'Net Asset Value', 'log': 'Transaction Ledger', 'null': 'No Assets Logged', 'add': 'Authorize', 'edit': 'Edit', 'lbl': 'Label', 'val': 'Value', 'in': 'Deposit', 'out': 'Withdraw', 'btn': 'Execute', 'cat': 'Asset Type', 'c1': 'Cash', 'c2': 'Card', 'c3': 'Savings', 'del': 'Delete', 'set': 'Select Country', 'src': 'Type country name...', 'gate': 'Please enter security PIN to continue', 'room': 'Vaults Room', 'newV': 'Create Vault', 'vName': 'Vault Name', 'opt': 'Options', 'setup': 'Please setup your security PIN', 'confirm': 'Please re-enter to confirm PIN', 'match': 'PINs do not match!', 'secDel': 'Security check required to delete', 'backSetup': 'Change original PIN'},
    'AR': {'name': 'THE VAULT', 'bal': 'صافي قيمة الأصول', 'log': 'سجل القيود المالية', 'null': 'لا توجد أصول مسجلة حالياً', 'add': 'إضافة', 'edit': 'تعديل', 'lbl': 'الوصف', 'val': 'القيمة', 'in': 'إيداع أصول', 'out': 'سحب أصول', 'btn': 'تنفيذ العمل', 'cat': 'تصنيف الأصل', 'c1': 'نقد كاش', 'c2': 'بطاقة بنكية', 'c3': 'مدخرات', 'del': 'حذف', 'set': 'اختر الدولة والعملة', 'src': 'اكتب اسم الدولة هنا...', 'gate': 'يُرجى إدخال رمز الأمان للمتابعة', 'room': 'غرفة الخزنات والمشاريع', 'newV': 'إنشاء خزنة جديدة', 'vName': 'اسم الخزنة أو المشروع', 'opt': 'خيارات العملية', 'setup': 'يُرجى إنشاء رمز الأمان الخاص بك', 'confirm': 'يُرجى إعادة كتابة الرمز لتأكيده', 'match': 'الرموز غير متطابقة!', 'secDel': 'مطلب إدخال رمز الأمان لإتمام الحذف', 'backSetup': 'العودة لتعديل الرمز'}
  };

  @override void initState() {
    super.initState(); _load(); _filteredCountries = _allCurs.keys.toList()..sort();
    _anim = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat(reverse: true);
  }

  @override void dispose() { _anim?.dispose(); for (var f in _fNodes) { f.dispose(); } super.dispose(); }
  void _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      setState(() {
        _savedPin = p.getString('v_pin') ?? ""; if (_savedPin.isNotEmpty) { _setupStep = 2; }
        final s = p.getString('v_data');
        if (s != null) {
          _vaults = (json.decode(s) as List).map((e) => Vault.fromMap(e)).toList();
          if (_vaults.isNotEmpty) { _selVault = _vaults.first; _co = _selVault!.country; _cur = _selVault!.currency; }
        }
      });
      AppLifecycleListener(onShow: () { if (_savedPin.isNotEmpty) { setState(() { _isUnlocked = false; for (var c in _pCons) { c.clear(); } }); } });
    } catch (e) { debugPrint("Security Core: Data corruption prevented."); }
  }

  void _saveData() async {
    final p = await SharedPreferences.getInstance(); p.setString('v_pin', _savedPin);
    p.setString('v_data', json.encode(_vaults.map((e) => e.toMap()).toList()));
  }
  void _checkOtp(String v) {
    if (v.length < 4) return;
    if (_setupStep == 0) {
      setState(() { _pin = v; _setupStep = 1; for (var c in _pCons) { c.clear(); } _fNodes[0].requestFocus();}); 
                 

    } else if (_setupStep == 1) {
      if (v == _pin) {
        setState(() { _successFlash = true; });
        Future.delayed(const Duration(milliseconds: 600), () { setState(() { _savedPin = v; _setupStep = 2; _isUnlocked = true; _successFlash = false; for (var c in _pCons) { c.clear(); } }); _saveData(); });
      } else {
        for (var c in _pCons) { c.clear(); } _fNodes[0].requestFocus(); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_dict[_ln]!['match']!)));
      }
    } else {
      if (v == _savedPin) {
        setState(() { _successFlash = true; });
        Future.delayed(const Duration(milliseconds: 600), () { setState(() { _isUnlocked = true; _successFlash = false; for (var c in _pCons) { c.clear(); } }); });
      } else {
        setState(() { _successFlash = false; }); for (var c in _pCons) { c.clear(); } _fNodes[0].requestFocus();
      }
    }
  }

  double _catSum(String c) {
    if (_selVault == null) return 0.0;
    return _selVault!.items.where((i) => i.cat == c).fold(0.0, (s, i) => s + (i.isPlus ? i.val : -i.val));
  }
  void _addVault() {
    final name = _vNameCon.text; if (name.isEmpty) return;
    final newV = Vault(id: DateTime.now().millisecondsSinceEpoch.toString(), name: name, country: 'Syria', currency: 'SYP', items: []);
    setState(() { _vaults.add(newV); _selVault = newV; _co = 'Syria'; _cur = 'SYP'; });
    _vNameCon.clear(); _saveData(); Navigator.pop(context);
  }

  void _showCountrySearch() {
    _searchCon.clear(); _filteredCountries = _allCurs.keys.toList()..sort();
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (context, setModalState) => AlertDialog(backgroundColor: const Color(0xFF0A0A16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFFD4AF37), width: 0.8)), title: Text(_dict[_ln]!['set']!, style: const TextStyle(color: Color(0xFFD4AF37), fontSize: 16, fontWeight: FontWeight.bold)), content: SizedBox(width: double.maxFinite, height: 350, child: Column(children: [TextField(controller: _searchCon, onChanged: (v) { setModalState(() { _filteredCountries = _allCurs.keys.where((c) => c.toLowerCase().contains(v.toLowerCase())).toList()..sort(); }); }, decoration: InputDecoration(hintText: _dict[_ln]!['src']!, prefixIcon: const Icon(Icons.search, color: Color(0xFFD4AF37)), filled: true, fillColor: const Color(0xFF121224), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))), const SizedBox(height: 10), Expanded(child: ListView.builder(itemCount: _filteredCountries.length, itemBuilder: (context, idx) { final c = _filteredCountries[idx]; return ListTile(title: Text(c, style: const TextStyle(color: Colors.white)), trailing: Text(_allCurs[c]!, style: const TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold)), onTap: () { setState(() { if (_selVault != null) { _selVault!.country = c; _selVault!.currency = _allCurs[c]!; _co = c; _cur = _allCurs[c]!; } }); _saveData(); Navigator.pop(ctx); }); }))])))));
  }
  void _openSheet({int? index}) {
    if (_selVault == null) return;
    if (index != null) { _t.text = _selVault!.items[index].text; _v.text = _selVault!.items[index].val.toString(); _plus = _selVault!.items[index].isPlus; _selCat = _selVault!.items[index].cat; } else { _t.clear(); _v.clear(); _plus = true; _selCat = 'Cash'; }
    showDialog(context: context, builder: (_) => StatefulBuilder(builder: (ctx, setModalState) => AlertDialog(backgroundColor: const Color(0xFF0F0F1A), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFFD4AF37), width: 0.5)), title: Text(index == null ? _dict[_ln]!['add']! : _dict[_ln]!['edit']!, style: const TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold)), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [TextField(controller: _t, decoration: InputDecoration(labelText: _dict[_ln]!['lbl']!, labelStyle: const TextStyle(color: Colors.grey))), TextField(controller: _v, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: _dict[_ln]!['val']!, labelStyle: const TextStyle(color: Colors.grey))), const SizedBox(height: 15), DropdownButton<String>(value: _selCat, dropdownColor: const Color(0xFF151525), isExpanded: true, items: ['Cash', 'Card', 'Savings'].map((String v) { int idx = ['Cash', 'Card', 'Savings'].indexOf(v) + 1; return DropdownMenuItem<String>(value: v, child: Text(_dict[_ln]!['c$idx']!)); }).toList(), onChanged: (nv) => setModalState(() => _selCat = nv!)), const SizedBox(height: 20), Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: _plus ? Colors.green.shade700 : Colors.grey.shade800, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), onPressed: () => setModalState(() => _plus = true), child: Text(_dict[_ln]!['in']!)), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: !_plus ? Colors.red.shade700 : Colors.grey.shade800, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), onPressed: () => setModalState(() => _plus = false), child: Text(_dict[_ln]!['out']!))]), const SizedBox(height: 20), SizedBox(width: double.infinity, height: 45, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37), foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: () { final txt = _t.text, val = double.tryParse(_v.text) ?? 0.0; if (txt.isEmpty || val <= 0) return; setState(() { if (index == null) { _selVault!.items.add(Item(text: txt, val: val, isPlus: _plus, cat: _selCat, d: DateTime.now())); } else { _selVault!.items[index].text = txt; _selVault!.items[index].val = val; _selVault!.items[index].isPlus = _plus; _selVault!.items[index].cat = _selCat; } }); _t.clear(); _v.clear(); _saveData(); Navigator.pop(ctx); }, child: Text(_dict[_ln]!['btn']!, style: const TextStyle(fontWeight: FontWeight.bold))))])))));
  }

  void _showOptions(int index) {
    if (_selVault == null) return;
    showDialog(context: context, builder: (ctx) => AlertDialog(backgroundColor: const Color(0xFF0F0F1A), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: const BorderSide(color: Color(0xFFD4AF37), width: 0.5)), title: Text(_dict[_ln]!['opt']!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), content: Column(mainAxisSize: MainAxisSize.min, children: [ListTile(leading: const Icon(Icons.edit, color: Color(0xFFD4AF37)), title: Text(_dict[_ln]!['edit']!), onTap: () { Navigator.pop(ctx); _openSheet(index: index); }), ListTile(leading: const Icon(Icons.delete, color: Colors.redAccent), title: Text(_dict[_ln]!['del']!), onTap: () { setState(() { _selVault!.items.removeAt(index); }); _saveData(); Navigator.pop(ctx); })])));
  }
  void _confirmDeleteVault(int i, BuildContext roomCtx, VoidCallback refreshRoom) {
    final List<TextEditingController> delCons = List.generate(4, (_) => TextEditingController());
    final List<FocusNode> delNodes = List.generate(4, (_) => FocusNode()); bool flash = false;
    showDialog(context: context, barrierDismissible: false, builder: (ctx) => StatefulBuilder(builder: (context, setDelState) => AlertDialog(backgroundColor: const Color(0xFF06060F), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.redAccent, width: 0.5)), title: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: Text(_dict[_ln]!['secDel']!, style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold))), GestureDetector(onTap: () => Navigator.pop(ctx), child: const Icon(Icons.close, color: Colors.redAccent, size: 20))]), content: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: List.generate(4, (index) => SizedBox(width: 42, height: 48, child: TextField(controller: delCons[index], focusNode: delNodes[index], keyboardType: TextInputType.number, obscureText: true, textAlign: TextAlign.center, maxLength: 1, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: flash ? Colors.greenAccent : Colors.white), decoration: InputDecoration(counterText: "", filled: true, fillColor: const Color(0xFF121224), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: flash ? Colors.greenAccent : Colors.grey.withOpacity(0.2))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: flash ? Colors.greenAccent : const Color(0xFFD4AF37)))), onChanged: (v) { if (v.isNotEmpty && index < 3) { delNodes[index + 1].requestFocus(); } else if (v.isEmpty && index > 0) { delNodes[index - 1].requestFocus(); } final code = delCons.map((e) => e.text).join(); if (code.length == 4) { if (code == _savedPin) { setDelState(() { flash = true; }); Future.delayed(const Duration(milliseconds: 400), () { setState(() { _vaults.removeAt(i); if (_vaults.isNotEmpty) { _selVault = _vaults.first; _co = _selVault!.country; _cur = _selVault!.currency; } else { _selVault = null; } }); _saveData(); refreshRoom(); Navigator.pop(ctx); }); } else { for (var c in delCons) { c.clear(); } delNodes[0].requestFocus(); } } })))))));
  }

  void _openVaultRoom() {
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (context, setRoomState) => AlertDialog(backgroundColor: const Color(0xFF06060F), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFFD4AF37), width: 0.8)), title: Text(_dict[_ln]!['room']!, style: const TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold)), content: SizedBox(width: double.maxFinite, height: 350, child: Column(children: [TextField(controller: _vNameCon, decoration: InputDecoration(labelText: _dict[_ln]!['vName']!, suffixIcon: IconButton(icon: const Icon(Icons.add_box, color: Color(0xFFD4AF37)), onPressed: () { _addVault(); setRoomState(() {}); }))), const SizedBox(height: 15), Expanded(child: ListView.builder(itemCount: _vaults.length, itemBuilder: (context, i) { final v = _vaults[i]; final isSel = _selVault?.id == v.id; return ListTile(tileColor: isSel ? const Color(0xFF1D1B36) : Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), title: Text(v.name, style: TextStyle(fontWeight: isSel ? FontWeight.bold : FontWeight.normal, color: Colors.white)), trailing: Row(mainAxisSize: MainAxisSize.min, children: [Text('${v.currency} ${v.total.toStringAsFixed(0)}', style: const TextStyle(color: Color(0xFF00FFCC), fontSize: 11)), const SizedBox(width: 8), IconButton(icon: const Icon(Icons.delete_sweep, color: Colors.redAccent, size: 18), onPressed: () => _confirmDeleteVault(i, ctx, () => setRoomState(() {})))],), onTap: () { setState(() { _selVault = v; _co = v.country; _cur = v.currency; }); Navigator.pop(ctx); }); }))])))));
  }
  Widget _buildOtpField() {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: List.generate(4, (index) => SizedBox(width: 42, height: 48, child: TextField(controller: _pCons[index], focusNode: _fNodes[index], keyboardType: TextInputType.number, obscureText: true, textAlign: TextAlign.center, maxLength: 1, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _successFlash ? Colors.greenAccent : Colors.white), decoration: InputDecoration(counterText: "", filled: true, fillColor: const Color(0xFF121224), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _successFlash ? Colors.greenAccent : Colors.grey.withOpacity(0.2))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _successFlash ? Colors.greenAccent : const Color(0xFFD4AF37)))), onChanged: (v) { if (v.isNotEmpty && index < 3) { _fNodes[index + 1].requestFocus(); } else if (v.isEmpty && index > 0) { _fNodes[index - 1].requestFocus(); } final code = _pCons.map((e) => e.text).join(); if (code.length == 4) { _checkOtp(code); } }))));
  }

  @override Widget build(BuildContext context) {
    bool rtl = _ln == 'AR'; const gold = Color(0xFFD4AF37);
    if (!_isUnlocked) {
      String titleText = _setupStep == 0 ? _dict[_ln]!['setup']! : _setupStep == 1 ? _dict[_ln]!['confirm']! : _dict[_ln]!['gate']!;
      return Directionality(textDirection: rtl ? TextDirection.rtl : TextDirection.ltr, child: Scaffold(body: AnimatedBuilder(animation: _anim!, builder: (context, child) => Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [const Color(0xFF05050C), Color.lerp(const Color(0xFF05050C), const Color(0xFF22113A), _anim!.value)!, const Color(0xFF020205)])), child: Stack(children: [Positioned.fill(child: CustomPaint(painter: GridPainter(_anim!.value, _co))), Center(child: Container(margin: const EdgeInsets.all(30), padding: const EdgeInsets.all(25), decoration: BoxDecoration(color: const Color(0xFF06060F).withOpacity(0.8), borderRadius: BorderRadius.circular(24), border: Border.all(color: _successFlash ? Colors.greenAccent : gold.withOpacity(0.3))), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(_successFlash ? Icons.lock_open_outlined : Icons.lock_outline, size: 60, color: _successFlash ? Colors.greenAccent : gold), const SizedBox(height: 15), Text(titleText, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: _successFlash ? Colors.greenAccent : Colors.grey, fontWeight: FontWeight.bold)), const SizedBox(height: 25), _buildOtpField(), const SizedBox(height: 15), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [TextButton(onPressed: () => setState(() => _ln = _ln == 'EN' ? 'AR' : 'EN'), child: Text(_ln == 'EN' ? 'العربية' : 'English', style: const TextStyle(color: gold, fontSize: 12))), if (_setupStep == 1) TextButton(onPressed: () { setState(() { _setupStep = 0; _pin = ""; for (var c in _pCons) { c.clear(); } _fNodes[0].requestFocus(); }); }, child: Text(_dict[_ln]!['backSetup']!, style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)))])])))],),))));
    }
    if (_vaults.isEmpty) { _vaults.add(Vault(id: '1', name: 'Main Vault', country: 'Syria', currency: 'SYP', items: [])); _selVault = _vaults.first; }
    final currentItems = _selVault?.items ?? [];
    return Directionality(textDirection: rtl ? TextDirection.rtl : TextDirection.ltr, child: Scaffold(appBar: AppBar(title: Text(_selVault?.name ?? _dict[_ln]!['name']!, style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 3, color: gold)), backgroundColor: const Color(0xFF06060F), centerTitle: true, elevation: 0, leading: IconButton(icon: const Icon(Icons.folder_special, color: gold), onPressed: _openVaultRoom), actions: [PopupMenuButton<String>(icon: const Icon(Icons.translate, color: gold), onSelected: (l) => setState(() => _ln = l), itemBuilder: (_) => [const PopupMenuItem(value: 'EN', child: Text('English')), const PopupMenuItem(value: 'AR', child: Text('العربية'))]), IconButton(icon: const Icon(Icons.blur_circular, color: gold), onPressed: _showCountrySearch)]), body: AnimatedBuilder(animation: _anim!, builder: (context, child) => Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [const Color(0xFF05050C), Color.lerp(const Color(0xFF05050C), const Color(0xFF22113A), _anim!.value)!, const Color(0xFF020205)])), child: Stack(children: [Positioned.fill(child: CustomPaint(painter: GridPainter(_anim!.value, _co))), Column(children: [Container(width: double.infinity, margin: const EdgeInsets.all(20), padding: const EdgeInsets.all(25), decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), gradient: LinearGradient(colors: [const Color(0xFF1D1B36).withOpacity(0.8), const Color(0xFF0D0B1A).withOpacity(0.6)]), border: Border.all(color: gold.withOpacity(0.4), width: 1), boxShadow: [BoxShadow(color: Color.lerp(Colors.purple, gold, _anim!.value)!.withOpacity(0.1), blurRadius: 25, spreadRadius: 2)]), child: Column(children: [Text('${_dict[_ln]!['bal']!} ($_co)', style: const TextStyle(color: Colors.grey, fontSize: 12, letterSpacing: 1, fontWeight: FontWeight.w600)), const SizedBox(height: 10), Text('$_cur ${(_selVault?.total ?? 0.0).toStringAsFixed(2)}', style: TextStyle(color: (_selVault?.total ?? 0.0) >= 0 ? const Color(0xFF00FFCC) : Colors.redAccent, fontSize: 36, fontWeight: FontWeight.w900, shadows: [Shadow(color: const Color(0xFF00FFCC).withOpacity(0.3), blurRadius: 10)]))])), SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: ['Cash', 'Card', 'Savings'].map((c) { int idx = ['Cash', 'Card', 'Savings'].indexOf(c) + 1; List<Color> cardColors = c == 'Cash' ? [Color(0xFF0F3A20).withValues(alpha: 0.7), Color(0xFF051A0E).withValues(alpha: 0.7)] : c == 'Card' ? [Color(0xFF1F355E).withValues(alpha: 0.7), Color(0xFF0F1B33).withValues(alpha: 0.7)] : [Color(0xFF5E481F).withValues(alpha: 0.7), Color(0xFF33260F).withValues(alpha: 0.7)]; return Container(margin: const EdgeInsets.symmetric(horizontal: 6), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), decoration: BoxDecoration(gradient: LinearGradient(colors: cardColors), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.1)), boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 4))]), child: Row(children: [Text('${_dict[_ln]!['c$idx']!}: ', style: const TextStyle(color: Colors.white70, fontSize: 12)), Text('$_cur ${_catSum(c).toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900))])); }).toList())), Padding(padding: const EdgeInsets.all(15), child: Align(alignment: rtl ? Alignment.centerRight : Alignment.centerLeft, child: Text(_dict[_ln]!['log']!, style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 0.5)))), Expanded(child: currentItems.isEmpty ? Center(child: Text(_dict[_ln]!['null']!, style: const TextStyle(color: Colors.grey, fontSize: 12))) : ListView.builder(itemCount: currentItems.length, itemBuilder: (ctx, i) => Container(margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4), decoration: BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF121224).withValues(alpha: 0.6), Color(0xFF0A0A14).withValues(alpha: 0.6)]), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withValues(alpha: 0.05))), child: ListTile(leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: currentItems[i].isPlus ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(currentItems[i].isPlus ? Icons.arrow_upward : Icons.arrow_downward, size: 18, color: currentItems[i].isPlus ? Colors.greenAccent : Colors.redAccent)), title: Text(currentItems[i].text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)), subtitle: Text('${currentItems[i].cat} | ${currentItems[i].d.day}/${currentItems[i].d.month}', style: const TextStyle(fontSize: 11, color: Colors.grey)), trailing: SizedBox(width: 140, child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [Text('${currentItems[i].isPlus ? "+" : "-"}$_cur ${currentItems[i].val.toStringAsFixed(2)}', style: TextStyle(color: currentItems[i].isPlus ? const Color(0xFF00FFCC) : Colors.redAccent, fontWeight: FontWeight.w900)), IconButton(icon: const Icon(Icons.more_vert, color: Colors.grey), onPressed: () => _showOptions(i))])),))))],)],),),), floatingActionButton: FloatingActionButton(backgroundColor: gold, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.add, color: Colors.black, size: 28), onPressed: () => _openSheet())));
  }
}

class GridPainter extends CustomPainter {
  final double animValue; final String country; GridPainter(this.animValue, this.country);
  @override void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFD4AF37).withValues(alpha: 0.01 + (animValue * 0.02))..strokeWidth = 0.5;
    for (double i = 0; i < size.width; i += 35) { canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint); }
    for (double i = 0; i < size.height; i += 35) { canvas.drawLine(Offset(0, i), Offset(size.width, i), paint); }
  }
  @override bool shouldRepaint(covariant GridPainter oldDelegate) => oldDelegate.animValue != animValue || oldDelegate.country != country;
}  
