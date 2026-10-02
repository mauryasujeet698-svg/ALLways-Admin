import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

class AdminCmsScreen extends StatefulWidget {
  final String section;
  const AdminCmsScreen({super.key, required this.section});
  @override State<AdminCmsScreen> createState() => _AdminCmsScreenState();
}

class _AdminCmsScreenState extends State<AdminCmsScreen> {
  static const cloudName = 'busdtvia';
  static const uploadPreset = 'allways_preset';
  final bannerUrl = TextEditingController();
  final heroTitle = TextEditingController();
  final heroSubtitle = TextEditingController();
  final deliveryText = TextEditingController();
  List<String> banners = [];
  int rotationSeconds = 4;
  bool showCategories = true, showOffers = true, showPopular = true, showLocalSellers = true, showTravel = true;
  bool codEnabled = true, loading = true, saving = false;
  final freeThreshold = TextEditingController(text: '499');
  final scheduledPerKm = TextEditingController(text: '11');
  final instantBaseFee = TextEditingController(text: '35');
  final instantPerKm = TextEditingController(text: '11');
  final pilotRadiusKm = TextEditingController(text: '4');
  final pilotCenterLat = TextEditingController(text: '');
  final pilotCenterLng = TextEditingController(text: '');
  final scheduledStart = TextEditingController(text: '09:00');
  final scheduledCutoff = TextEditingController(text: '13:30');
  final serviceablePincodes = TextEditingController(text: '230502');
  final specialOfferTitle = TextEditingController(text: 'Just for you');
  final specialOfferMessage = TextEditingController(text: 'More scheduled delivery slots are available today.');
  bool instantEnabled = true, scheduledEnabled = true, specialOfferEnabled = false;

  @override void initState() { super.initState(); _load(); }
  @override void dispose() { bannerUrl.dispose(); heroTitle.dispose(); heroSubtitle.dispose(); deliveryText.dispose(); freeThreshold.dispose(); scheduledPerKm.dispose(); instantBaseFee.dispose(); instantPerKm.dispose(); pilotRadiusKm.dispose(); pilotCenterLat.dispose(); pilotCenterLng.dispose(); scheduledStart.dispose(); scheduledCutoff.dispose(); serviceablePincodes.dispose(); specialOfferTitle.dispose(); specialOfferMessage.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final b = await FirebaseFirestore.instance.collection('settings').doc('banners').get();
      final h = await FirebaseFirestore.instance.collection('settings').doc('homepage').get();
      final s = await FirebaseFirestore.instance.collection('settings').doc('app').get();
      final d = await FirebaseFirestore.instance.collection('settings').doc('delivery').get();
      final zones = await FirebaseFirestore.instance.collection('serviceableZones').where('status', isEqualTo: 'serviceable').get();
      final bd = b.data() ?? {}, hd = h.data() ?? {}, sd = s.data() ?? {}, dd = d.data() ?? {};
      final raw = bd['imageUrls'];
      banners = raw is List ? raw.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).take(7).toList() : <String>[];
      rotationSeconds = ((bd['rotationSeconds'] is num ? (bd['rotationSeconds'] as num).toInt() : int.tryParse((bd['rotationSeconds'] ?? 4).toString()) ?? 4)).clamp(2, 20).toInt();
      heroTitle.text = (hd['heroTitle'] ?? 'Closer to You, Always').toString();
      heroSubtitle.text = (hd['heroSubtitle'] ?? 'Everything you need, delivered locally.').toString();
      deliveryText.text = (hd['deliveryText'] ?? 'Fast local delivery').toString();
      showCategories = hd['showCategories'] != false;
      showOffers = hd['showOffers'] != false;
      showPopular = hd['showPopular'] != false;
      showLocalSellers = hd['showLocalSellers'] != false;
      showTravel = hd['showTravel'] != false;
      codEnabled = sd['codEnabled'] != false;
      freeThreshold.text = (dd['freeScheduledThreshold'] ?? 499).toString();
      scheduledPerKm.text = (dd['scheduledPerKm'] ?? 11).toString();
      instantBaseFee.text = (dd['instantBaseFee'] ?? 35).toString();
      instantPerKm.text = (dd['instantPerKm'] ?? 11).toString();
      pilotRadiusKm.text = (dd['pilotRadiusKm'] ?? 4).toString();
      pilotCenterLat.text = (dd['pilotCenterLat'] ?? '').toString();
      pilotCenterLng.text = (dd['pilotCenterLng'] ?? '').toString();
      final cutoffH = (dd['scheduledCutoffHour'] ?? 13).toString().padLeft(2,'0');
      final cutoffM = (dd['scheduledCutoffMinute'] ?? 30).toString().padLeft(2,'0');
      scheduledStart.text = ((dd['scheduledStartHour'] ?? 9).toString().padLeft(2,'0'))+':'+((dd['scheduledStartMinute'] ?? 0).toString().padLeft(2,'0'));
      scheduledCutoff.text = cutoffH+':'+cutoffM;
      final zonePins = zones.docs.map((x)=>x.id).where((x)=>RegExp(r'^\d{6}$').hasMatch(x)).toList()..sort();
      serviceablePincodes.text = zonePins.isEmpty ? '230502' : zonePins.join(', ');
      instantEnabled = dd['instantEnabled'] != false;
      scheduledEnabled = dd['scheduledEnabled'] != false;
      specialOfferEnabled = dd['specialOfferEnabled'] == true;
      specialOfferTitle.text = (dd['specialOfferTitle'] ?? 'Just for you').toString();
      specialOfferMessage.text = (dd['specialOfferMessage'] ?? 'More scheduled delivery slots are available today.').toString();
    } catch (_) {}
    if (mounted) setState(() => loading = false);
  }

  Future<void> _save(String label) async {
    setState(() => saving = true);
    try {
      await FirebaseFirestore.instance.collection('settings').doc('banners').set({
        'imageUrls': banners.take(7).toList(), 'rotationSeconds': rotationSeconds, 'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await FirebaseFirestore.instance.collection('settings').doc('homepage').set({
        'heroTitle': heroTitle.text.trim(), 'heroSubtitle': heroSubtitle.text.trim(), 'deliveryText': deliveryText.text.trim(),
        'showCategories': showCategories, 'showOffers': showOffers, 'showPopular': showPopular,
        'showLocalSellers': showLocalSellers, 'showTravel': showTravel, 'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await FirebaseFirestore.instance.collection('settings').doc('app').set({'codEnabled': codEnabled, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      final startParts=scheduledStart.text.trim().split(':');
      final startHour=int.tryParse(startParts.isNotEmpty?startParts[0]:'09')??9;
      final startMinute=int.tryParse(startParts.length>1?startParts[1]:'00')??0;
      final cutoffParts=scheduledCutoff.text.trim().split(':');
      final cutoffHour=int.tryParse(cutoffParts.isNotEmpty?cutoffParts[0]:'13')??13;
      final cutoffMinute=int.tryParse(cutoffParts.length>1?cutoffParts[1]:'30')??30;
      await FirebaseFirestore.instance.collection('settings').doc('delivery').set({
        'deliveryEnabled': true,
        'instantEnabled': instantEnabled,
        'scheduledEnabled': scheduledEnabled,
        'freeScheduledThreshold': double.tryParse(freeThreshold.text.trim())??499,
        'scheduledPerKm': double.tryParse(scheduledPerKm.text.trim())??11,
        'instantBaseFee': double.tryParse(instantBaseFee.text.trim())??35,
        'instantPerKm': double.tryParse(instantPerKm.text.trim())??11,
        'scheduledStartHour': startHour.clamp(0,23),
        'scheduledStartMinute': startMinute.clamp(0,59),
        'scheduledEndHour': cutoffHour.clamp(0,23),
        'scheduledEndMinute': cutoffMinute.clamp(0,59),
        'scheduledCutoffHour': cutoffHour.clamp(0,23),
        'scheduledCutoffMinute': cutoffMinute.clamp(0,59),
        'pilotRadiusKm': double.tryParse(pilotRadiusKm.text.trim())??4,
        'pilotCenterLat': double.tryParse(pilotCenterLat.text.trim())??0,
        'pilotCenterLng': double.tryParse(pilotCenterLng.text.trim())??0,
        'specialOfferEnabled': specialOfferEnabled,
        'specialOfferTitle': specialOfferTitle.text.trim(),
        'specialOfferMessage': specialOfferMessage.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      final pins=serviceablePincodes.text.split(RegExp(r'[,\s]+')).map((x)=>x.trim()).where((x)=>RegExp(r'^\d{6}$').hasMatch(x)).toSet();
      final existing=await FirebaseFirestore.instance.collection('serviceableZones').get();
      final batch=FirebaseFirestore.instance.batch();
      for(final doc in existing.docs){
        if(!pins.contains(doc.id))batch.delete(doc.reference);
      }
      for(final pin in pins){
        batch.set(FirebaseFirestore.instance.collection('serviceableZones').doc(pin),{
          'pincode':pin,'status':'serviceable','updatedAt':FieldValue.serverTimestamp(),
        },SetOptions(merge:true));
      }
      await batch.commit();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save: ' + e.toString())));
    } finally { if (mounted) setState(() => saving = false); }
  }

  Future<void> _addUrl() async {
    final url = bannerUrl.text.trim();
    if (url.isEmpty || banners.length >= 7) return;
    if (!url.startsWith('http')) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid image URL.'))); return; }
    setState(() { banners.add(url); bannerUrl.clear(); });
  }

  Future<void> _uploadBanner() async {
    if (banners.length >= 7) return;
    final image = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 65, maxWidth: 1200);
    if (image == null) return;
    try {
      final request = http.MultipartRequest('POST', Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload'));
      request.fields['upload_preset'] = uploadPreset;
      request.fields['folder'] = 'admin/banners';
      request.files.add(await http.MultipartFile.fromPath('file', image.path));
      final response = await request.send();
      final data = jsonDecode(await response.stream.bytesToString());
      final url = (data['secure_url'] ?? '').toString();
      if (url.isEmpty) throw Exception('Cloudinary did not return secure_url.');
      if (mounted) setState(() => banners.add(url));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Banner upload failed: ' + e.toString())));
    }
  }

  Widget _card(String title, String subtitle, Widget child) => Card(
    margin: const EdgeInsets.only(bottom: 14), elevation: 0,
    child: Padding(padding: const EdgeInsets.fromLTRB(16,16,16,10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
      const SizedBox(height: 4), Text(subtitle, style: const TextStyle(color: Colors.grey)),
      const SizedBox(height: 12), child,
    ])),
  );

  Widget _banners() => _card('Banner Manager','Maximum 7 banners. Changes are stored in Firestore and do not require a new APK.',Column(children:[
    ...List.generate(banners.length,(i)=>ListTile(
      contentPadding: EdgeInsets.zero,
      leading: ClipRRect(borderRadius: BorderRadius.circular(10),child:Image.network(banners[i],width:70,height:45,fit:BoxFit.cover,errorBuilder:(_,__,___)=>const SizedBox(width:70,height:45,child:Icon(Icons.broken_image)))),
      title: Text('Banner '+(i+1).toString(),style:const TextStyle(fontWeight:FontWeight.w800)),
      subtitle: Text(banners[i],maxLines:1,overflow:TextOverflow.ellipsis),
      trailing: IconButton(icon:const Icon(Icons.delete_outline),onPressed:()=>setState(()=>banners.removeAt(i))),
    )),
    if(banners.isEmpty) const Align(alignment:Alignment.centerLeft,child:Text('No banners configured yet.')),
    const SizedBox(height:6),
    Row(children:[Expanded(child:TextField(controller:bannerUrl,decoration:const InputDecoration(labelText:'Cloudinary image URL',prefixIcon:Icon(Icons.link)))),IconButton(onPressed:_addUrl,icon:const Icon(Icons.add_circle))]),
    const SizedBox(height:8),
    Row(children:[
      Expanded(child:OutlinedButton.icon(onPressed:_uploadBanner,icon:const Icon(Icons.upload),label:const Text('Upload banner'))),
      const SizedBox(width:8),
      Expanded(child:DropdownButtonFormField<int>(initialValue:[2,3,4,5,6,8,10].contains(rotationSeconds)?rotationSeconds:4,decoration:const InputDecoration(labelText:'Rotation'),items:[2,3,4,5,6,8,10].map((x)=>DropdownMenuItem(value:x,child:Text(x.toString()+' sec'))).toList(),onChanged:(v)=>setState(()=>rotationSeconds=v??4))),
    ]),
  ]));

  Widget _homepage() => _card('Homepage content','Control customer-facing sections without shipping another APK.',Column(children:[
    TextField(controller:heroTitle,decoration:const InputDecoration(labelText:'Hero title')),
    const SizedBox(height:10),TextField(controller:heroSubtitle,maxLines:2,decoration:const InputDecoration(labelText:'Hero subtitle')),
    const SizedBox(height:10),TextField(controller:deliveryText,decoration:const InputDecoration(labelText:'Delivery message')),
    const Divider(height:26),
    SwitchListTile(title:const Text('Categories'),value:showCategories,onChanged:(v)=>setState(()=>showCategories=v)),
    SwitchListTile(title:const Text('Top offers'),value:showOffers,onChanged:(v)=>setState(()=>showOffers=v)),
    SwitchListTile(title:const Text('Popular products'),value:showPopular,onChanged:(v)=>setState(()=>showPopular=v)),
    SwitchListTile(title:const Text('Local sellers shortcut'),value:showLocalSellers,onChanged:(v)=>setState(()=>showLocalSellers=v)),
    SwitchListTile(title:const Text('Travel shortcut'),value:showTravel,onChanged:(v)=>setState(()=>showTravel=v)),
  ]));

  Widget _deliverySettings() => _card('Delivery & Scheduling','Control pilot-zone distance pricing, free scheduled delivery and the scheduled-order cutoff without shipping a new APK.',Column(children:[
    Row(children:[
      Expanded(child:TextField(controller:freeThreshold,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Free scheduled threshold (₹)'))),
      const SizedBox(width:10),
      Expanded(child:TextField(controller:pilotRadiusKm,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Pilot radius (km)'))),
    ]),
    const SizedBox(height:10),
    Row(children:[
      Expanded(child:TextField(controller:scheduledPerKm,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Scheduled ₹ / km'))),
      const SizedBox(width:10),
      Expanded(child:TextField(controller:instantBaseFee,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Instant base fee (₹)'))),
    ]),
    const SizedBox(height:10),
    TextField(controller:instantPerKm,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Instant ₹ / km')),
    const SizedBox(height:10),
    Row(children:[
      Expanded(child:TextField(controller:scheduledStart,keyboardType:TextInputType.datetime,decoration:const InputDecoration(labelText:'Scheduled start (HH:MM)'))),
      const SizedBox(width:10),
      Expanded(child:TextField(controller:scheduledCutoff,keyboardType:TextInputType.datetime,decoration:const InputDecoration(labelText:'Scheduled end (HH:MM)'))),
    ]),
    const SizedBox(height:6),
    const Text('After the scheduled end time, customers can choose the next day. Admin controls this window here.',style:TextStyle(color:Colors.grey,fontSize:12)),
    const SizedBox(height:12),
    TextField(controller:serviceablePincodes,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Serviceable PIN codes',hintText:'230502, 230501, 230503',helperText:'Separate multiple PIN codes with commas.')),
    const Divider(height:26),
    const Align(alignment:Alignment.centerLeft,child:Text('Pilot market center',style:TextStyle(fontWeight:FontWeight.w900))),
    const SizedBox(height:4),
    const Align(alignment:Alignment.centerLeft,child:Text('Enter the market latitude and longitude used as the 4 km pilot-zone center.',style:TextStyle(color:Colors.grey,fontSize:12))),
    const SizedBox(height:10),
    Row(children:[
      Expanded(child:TextField(controller:pilotCenterLat,keyboardType:const TextInputType.numberWithOptions(decimal:true,signed:true),decoration:const InputDecoration(labelText:'Market latitude'))),
      const SizedBox(width:10),
      Expanded(child:TextField(controller:pilotCenterLng,keyboardType:const TextInputType.numberWithOptions(decimal:true,signed:true),decoration:const InputDecoration(labelText:'Market longitude'))),
    ]),
    const Divider(height:26),
    SwitchListTile(title:const Text('Instant delivery'),subtitle:const Text('Base ₹35 + per-km charge.'),value:instantEnabled,onChanged:(v)=>setState(()=>instantEnabled=v)),
    SwitchListTile(title:const Text('Scheduled delivery'),subtitle:const Text('Free when the item total reaches the threshold.'),value:scheduledEnabled,onChanged:(v)=>setState(()=>scheduledEnabled=v)),
    SwitchListTile(title:const Text('Special scheduled-delivery offer'),subtitle:const Text('Show a customer-facing message when you want to encourage scheduled orders.'),value:specialOfferEnabled,onChanged:(v)=>setState(()=>specialOfferEnabled=v)),
    TextField(controller:specialOfferTitle,decoration:const InputDecoration(labelText:'Special offer title')),
    const SizedBox(height:10),
    TextField(controller:specialOfferMessage,maxLines:2,decoration:const InputDecoration(labelText:'Special offer message')),
  ]));

  @override Widget build(BuildContext context){
    if(loading)return const Scaffold(body:Center(child:CircularProgressIndicator()));
    final section=widget.section;
    return Scaffold(
      appBar:AppBar(title:Text(section)),
      body:ListView(padding:const EdgeInsets.fromLTRB(16,14,16,28),children:[
        if(section=='Manage Banners')_banners(),
        if(section=='Homepage & Content')_homepage(),
        if(section=='Delivery Settings')_deliverySettings(),
        if(section=='App Settings')...[_banners(),_homepage(),_deliverySettings(),_card('Order settings','Platform-level defaults.',SwitchListTile(title:const Text('Cash on Delivery'),subtitle:const Text('Keep COD enabled for ALLways managed shopping.'),value:codEnabled,onChanged:(v)=>setState(()=>codEnabled=v)))],
        FilledButton.icon(onPressed:saving?null:()=>_save(section),icon:const Icon(Icons.save_outlined),label:Text(saving?'Saving…':'Save changes')),
      ]),
    );
  }
}