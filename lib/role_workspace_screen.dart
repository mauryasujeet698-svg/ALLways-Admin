import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'admin_cms_screen.dart';
import 'catalog_sync_screen.dart';
import 'ride_pricing_screen.dart';
import 'live_tracking_screen.dart';

class RoleFeatureScreen extends StatelessWidget {
  final String role, feature;
  final User user;
  final Color accent;
  const RoleFeatureScreen({super.key,required this.role,required this.feature,required this.user,required this.accent});

  IconData get icon => const {
    'Manage Sellers':Icons.storefront,'Manage Carriers':Icons.two_wheeler,'Manage Delivery Partners':Icons.delivery_dining,
    'Manage Orders':Icons.receipt_long,'Live Tracking':Icons.gps_fixed,'Catalog Sync':Icons.sync,'Manage Banners':Icons.view_carousel,'Homepage & Content':Icons.home_work,
    'Send Notifications':Icons.campaign,'Users & Roles':Icons.manage_accounts,'Reports & Analytics':Icons.analytics,'App Settings':Icons.settings,
    'Products':Icons.inventory_2,'Orders':Icons.receipt_long,'Shop Profile':Icons.storefront,'Offers':Icons.local_offer,'Inventory':Icons.fact_check,'Sales Analytics':Icons.bar_chart,'Payouts':Icons.account_balance_wallet,
    'Delivery Requests':Icons.local_shipping,'My Deliveries':Icons.assignment_turned_in,'Earnings':Icons.currency_rupee,'Incentives':Icons.card_giftcard,'Performance':Icons.bar_chart,'Documents':Icons.description,'Safety & SOS':Icons.shield,'Help & Support':Icons.support_agent,
    'Ride Requests':Icons.two_wheeler,'Ride Pricing':Icons.payments_outlined,'My Rides':Icons.route,'Ratings':Icons.star,'Ride History':Icons.history,'Vehicle & Documents':Icons.description,'Profile & Settings':Icons.person,
  }[feature] ?? Icons.dashboard;

  @override Widget build(BuildContext context){
    if(feature=='Manage Banners'||feature=='Homepage & Content'||feature=='App Settings'){
      return AdminCmsScreen(section:feature);
    }
    return Scaffold(
      backgroundColor:const Color(0xFFF8F8F8),
      appBar:AppBar(title:Text(feature),backgroundColor:Colors.white,elevation:.3),
      body:SafeArea(child:_content(context)),
    );
  }

  Widget _content(BuildContext context){
    if(feature=='Live Tracking')return AdminLiveTrackingScreen(accent:accent);
    if(feature=='Catalog Sync')return const CatalogSyncScreen();
    if(feature=='Delivery & Pricing')return const AdminCmsScreen(section:'Delivery Settings');
    if(feature=='Ride Pricing')return RidePricingScreen(user:user);
    if(feature=='Manage Orders'||feature=='Orders'||feature=='My Deliveries'||feature=='My Rides'||feature=='Ride History')return _orders(context);
    if(feature=='Ride Requests')return RideRequestsScreen(user:user,accent:accent);
    if(feature=='Delivery Requests')return _requests(context,true);
    if(feature=='Products'||feature=='Inventory')return _products(context);
    if(feature=='Shop Profile')return _shopProfile(context);
    if(feature=='Offers')return _offers(context);
    if(feature=='Manage Sellers')return _people('sellers','Seller');
    if(feature=='Manage Carriers')return _people('ridePartners','Rider');
    if(feature=='Manage Delivery Partners')return _people('deliveryPartners','Delivery Partner',roleFilter:'delivery_partner');
    if(feature=='Users & Roles')return _users(context);
    if(feature=='Earnings'||feature=='Payouts')return _earnings();
    if(feature=='Sales Analytics'||feature=='Reports & Analytics'||feature=='Performance'||feature=='Ratings')return _analytics();
    if(feature=='Documents'||feature=='Vehicle & Documents')return _documents();
    if(feature=='Safety & SOS')return _safety(context);
    if(feature=='Help & Support')return _support(context);
    if(feature=='Send Notifications')return _announcement(context);
    return _account(context);
  }

  Widget _page(List<Widget> children)=>ListView(padding:const EdgeInsets.fromLTRB(16,14,16,28),children:children);
  Widget _hero(String title,String subtitle)=>Card(elevation:0,color:accent.withOpacity(.08),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(20)),child:Padding(padding:const EdgeInsets.all(16),child:Row(children:[CircleAvatar(radius:28,backgroundColor:accent.withOpacity(.14),child:Icon(icon,color:accent,size:28)),const SizedBox(width:13),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontSize:19,fontWeight:FontWeight.w900)),const SizedBox(height:4),Text(subtitle,style:const TextStyle(color:Colors.black54))]))])));
  Widget _metric(String value,String label,IconData i)=>Expanded(child:Card(elevation:0,child:Padding(padding:const EdgeInsets.all(13),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(i,color:accent,size:20),const SizedBox(height:7),Text(value,style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900)),Text(label,style:const TextStyle(fontSize:10.5,color:Colors.grey))]))));

  Widget _orders(BuildContext context)=>_AdminOrdersFilterView(
    role:role,feature:feature,user:user,accent:accent,
    onAssign:_assignDeliveryPartner,
  );

  Future<void> _assignDeliveryPartner(BuildContext context,QueryDocumentSnapshot<Map<String,dynamic>> order) async {
    try{
      final snap=await FirebaseFirestore.instance.collection('deliveryPartners').get();
      var partners=snap.docs.where((d){
        final x=d.data();
        return (x['approvalStatus']??'').toString().toLowerCase()=='approved';
      }).toList();

      if(partners.isEmpty){
        if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content:Text('No approved delivery partners are available yet.')),
        );
        return;
      }

      partners.sort((a,b){
        final ao=(a.data()['status']??a.data()['dutyStatus']??'offline').toString().toLowerCase()=='online';
        final bo=(b.data()['status']??b.data()['dutyStatus']??'offline').toString().toLowerCase()=='online';
        return bo==ao ? 0 : (bo ? 1 : -1);
      });

      if(!context.mounted)return;

      final chosen=await showDialog<QueryDocumentSnapshot<Map<String,dynamic>>>(
        context:context,
        builder:(dialogContext)=>AlertDialog(
          title:Text((order.data()['carrierUid']??'').toString().isEmpty
              ? 'Assign delivery partner'
              : 'Reassign delivery partner'),
          content:SizedBox(
            width:420,
            child:ListView(
              shrinkWrap:true,
              children:partners.map((d){
                final x=d.data();
                final name=(x['name']??x['displayName']??x['email']??d.id).toString();
                final status=(x['status']??x['dutyStatus']??'offline').toString();
                final vehicle=(x['vehicleType']??'bike').toString();
                final available =
                    (x['approvalStatus']??'').toString().toLowerCase()=='approved' &&
                    (x['status']??x['dutyStatus']??'').toString().toLowerCase()=='online' &&
                    x['availableForDeliveries'] != false &&
                    (x['currentOrderId']??'').toString().trim().isEmpty &&
                    (x['pendingOrderId']??'').toString().trim().isEmpty;
                return ListTile(
                  leading:Stack(
                    clipBehavior:Clip.none,
                    children:[
                      const CircleAvatar(child:Icon(Icons.local_shipping_outlined)),
                      if(available)Positioned(
                        right:-1,bottom:-1,
                        child:Container(
                          width:12,height:12,
                          decoration:BoxDecoration(
                            color:Colors.green,
                            shape:BoxShape.circle,
                            border:Border.all(color:Colors.white,width:2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  title:Text(name,style:const TextStyle(fontWeight:FontWeight.w800)),
                  subtitle:Text(status+' • '+vehicle+' • '+(x['phone']??x['mobileNumber']??'').toString()),
                  trailing:const Icon(Icons.chevron_right),
                  onTap:()=>Navigator.pop(dialogContext,d),
                );
              }).toList(),
            ),
          ),
          actions:[
            TextButton(onPressed:()=>Navigator.pop(dialogContext),child:const Text('Cancel')),
          ],
        ),
      );
      if(chosen==null)return;

      final p=chosen.data();
      final uid=chosen.id;
      final name=(p['name']??p['displayName']??p['email']??uid).toString();
      final phone=(p['phone']??p['mobileNumber']??'').toString();
      final vehicle=(p['vehicleType']??'bike').toString();

      await order.reference.update({
        'carrierUid':uid,
        'deliveryPartnerUid':uid,
        'assignedPartnerId':uid,
        'carrierName':name,
        'carrierPhone':phone,
        'carrierVehicleType':vehicle,
        'carrierAccepted':true,
        'assignmentRejected':false,
        'assignmentMethod':'admin',
        'assignedBy':user.uid,
        'assignedAt':FieldValue.serverTimestamp(),
        'status':'Assigned',
        'statusNote':'Delivery partner assigned',
        'customerMessage':'A delivery partner has been assigned to your order.',
        'updatedAt':FieldValue.serverTimestamp(),
      });

      if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content:Text('Order assigned to '+name+'.')),
      );
    }catch(e){
      if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content:Text('Assignment failed: '+e.toString())),
      );
    }
  }

  Widget _requests(BuildContext context,bool delivery)=>StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
    stream:FirebaseFirestore.instance.collection(delivery?'orders':'autoRideRequests').snapshots(),
    builder:(context,snap){
      if(snap.hasError)return _page([_hero(feature,'Live request queue'),_error(snap.error.toString())]);
      if(!snap.hasData)return const Center(child:CircularProgressIndicator());
      final docs=snap.data!.docs.where((d){
        final o=d.data();final s=(o['status']??'').toString().toLowerCase();
        if(delivery)return (o['carrierUid']??'').toString().isEmpty&&s!='delivered'&&s!='cancelled';
        return s=='searching'&&!(o['rejectedBy'] is List&&List.from(o['rejectedBy']).contains(user.uid));
      }).toList();
      return _page([_hero(feature,delivery?'Review nearby delivery assignments.':'Review ride requests within your operating radius.'),const SizedBox(height:12),
        if(docs.isEmpty)_empty('No requests right now','Stay online and new requests will appear here.')
        else ...docs.map((d){
          final o=d.data();final id=(o['id']??d.id).toString();
          return Card(elevation:0,child:Padding(padding:const EdgeInsets.all(13),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Row(children:[CircleAvatar(backgroundColor:accent.withOpacity(.1),child:Icon(delivery?Icons.local_shipping:Icons.two_wheeler,color:accent)),const SizedBox(width:10),Expanded(child:Text('#'+id,style:const TextStyle(fontWeight:FontWeight.w900))),Text('₹'+_num(o['total']??o['estimatedFare']).toStringAsFixed(0),style:const TextStyle(fontWeight:FontWeight.w900))]),
            const SizedBox(height:8),Text((o['address']??o['pickupAddress']??'Pickup location').toString(),maxLines:2,overflow:TextOverflow.ellipsis),
            const SizedBox(height:10),Row(children:[
              Expanded(child:OutlinedButton(onPressed:()=>_details(context,o),child:const Text('Details'))),
              const SizedBox(width:8),
              if(!delivery&&role=='carrier')Expanded(child:OutlinedButton(onPressed:()=>_reject(d),child:const Text('Reject'))),
              if(!delivery&&role=='carrier')const SizedBox(width:8),
              Expanded(child:FilledButton(onPressed:()=>_accept(context,d,delivery),style:FilledButton.styleFrom(backgroundColor:accent),child:const Text('Accept'))),
            ]),
          ])));
        }),
      ]);
    },
  );

  Future<void> _accept(BuildContext context,QueryDocumentSnapshot<Map<String,dynamic>> d,bool delivery)async{
    try{
      if(delivery){
        await d.reference.update({'carrierUid':user.uid,'status':'Assigned','carrierAccepted':true,'assignedAt':FieldValue.serverTimestamp(),'updatedAt':FieldValue.serverTimestamp()});
      }else{
        await d.reference.update({'driverUid':user.uid,'status':'accepted','driverName':user.displayName??'ALLways Rider','driverPhone':user.phoneNumber??'','acceptedAt':FieldValue.serverTimestamp(),'updatedAt':FieldValue.serverTimestamp()});
      }
      if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Request accepted.')));
    }catch(e){if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Could not accept: '+e.toString())));}
  }
  Future<void> _reject(QueryDocumentSnapshot<Map<String,dynamic>> d)async{try{await d.reference.update({'rejectedBy':FieldValue.arrayUnion([user.uid]),'updatedAt':FieldValue.serverTimestamp()});}catch(_){}}
  void _details(BuildContext context,Map<String,dynamic> o)=>showModalBottomSheet(context:context,showDragHandle:true,builder:(_)=>SafeArea(child:Padding(padding:const EdgeInsets.fromLTRB(20,8,20,24),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Request details',style:const TextStyle(fontSize:20,fontWeight:FontWeight.w900)),const SizedBox(height:10),Text((o['name']??o['customerName']??'Customer').toString()),Text((o['phone']??o['customerPhone']??'').toString()),Text((o['address']??o['pickupAddress']??'').toString()),Text('Fare: ₹'+_num(o['total']??o['estimatedFare']).toStringAsFixed(0))]))));

  Widget _products(BuildContext context)=>StreamBuilder<DocumentSnapshot<Map<String,dynamic>>>(
    stream:FirebaseFirestore.instance.collection('sellers').doc(user.uid).snapshots(),
    builder:(context,snap){
      if(!snap.hasData)return const Center(child:CircularProgressIndicator());
      final data=snap.data!.data()??{};final raw=data['items'];final items=raw is List?raw.whereType<Map>().map((x)=>Map<String,dynamic>.from(x)).toList():<Map<String,dynamic>>[];
      return _page([_hero(feature,'Manage products, pricing and stock in one place.'),const SizedBox(height:12),
        Row(children:[_metric(items.length.toString(),'Products',Icons.inventory_2),_metric(items.where((x)=>_num(x['stock'])>0).length.toString(),'In stock',Icons.check_circle)]),
        const SizedBox(height:12),
        FilledButton.icon(onPressed:()=>_addProduct(context,data),icon:const Icon(Icons.add),label:const Text('Add product')),
        const SizedBox(height:10),
        if(items.isEmpty)_empty('No products','Add your first product to start selling.')
        else ...items.asMap().entries.map((entry){
          final i=entry.key,x=entry.value;final stock=_num(x['stock']);
          return Card(elevation:0,child:ListTile(
            leading:CircleAvatar(backgroundColor:accent.withOpacity(.1),child:Icon(Icons.inventory_2,color:accent)),
            title:Text((x['name']??'Product').toString(),style:const TextStyle(fontWeight:FontWeight.w800)),
            subtitle:Text('₹'+_num(x['price']).toStringAsFixed(0)+' • Stock '+stock.toStringAsFixed(0)+' • '+(x['category']??'Other').toString()),
            trailing:PopupMenuButton<String>(onSelected:(v)=>_productAction(v,i,data,items),itemBuilder:(_)=>const[PopupMenuItem(value:'plus',child:Text('Add stock')),PopupMenuItem(value:'minus',child:Text('Remove stock')),PopupMenuItem(value:'delete',child:Text('Delete'))]),
          ));
        }),
      ]);
    },
  );

  Future<void> _addProduct(BuildContext context,Map<String,dynamic> data)async{
    final name=TextEditingController(),price=TextEditingController(),stock=TextEditingController(text:'10'),category=TextEditingController();
    final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('Add product'),content:SingleChildScrollView(child:Column(children:[
      TextField(controller:name,decoration:const InputDecoration(labelText:'Product name')),TextField(controller:category,decoration:const InputDecoration(labelText:'Category')),
      TextField(controller:price,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Price')),TextField(controller:stock,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Stock')),
    ])),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Add'))]));
    if(ok!=true)return;
    final item={'id':'seller_'+DateTime.now().millisecondsSinceEpoch.toString(),'name':name.text.trim(),'category':category.text.trim().isEmpty?'Other':category.text.trim(),'price':double.tryParse(price.text.trim())??0,'stock':double.tryParse(stock.text.trim())??0};
    final items=(data['items'] is List)?List<Map<String,dynamic>>.from((data['items'] as List).whereType<Map>().map((x)=>Map<String,dynamic>.from(x))):<Map<String,dynamic>>[];
    items.add(item);
    await FirebaseFirestore.instance.collection('sellers').doc(user.uid).set({'items':items,'updatedAt':FieldValue.serverTimestamp()},SetOptions(merge:true));
  }
  Future<void> _productAction(String action,int index,Map<String,dynamic> data,List<Map<String,dynamic>> items)async{
    if(index<0||index>=items.length)return;final x=Map<String,dynamic>.from(items[index]);var stock=_num(x['stock']);
    if(action=='plus')stock+=1;else if(action=='minus')stock=stock>0?stock-1:0;else if(action=='delete'){items.removeAt(index);await FirebaseFirestore.instance.collection('sellers').doc(user.uid).set({'items':items},SetOptions(merge:true));return;}
    x['stock']=stock;items[index]=x;await FirebaseFirestore.instance.collection('sellers').doc(user.uid).set({'items':items},SetOptions(merge:true));
  }

  Widget _shopProfile(BuildContext context)=>StreamBuilder<DocumentSnapshot<Map<String,dynamic>>>(
    stream:FirebaseFirestore.instance.collection('sellers').doc(user.uid).snapshots(),
    builder:(context,snap){final d=snap.data?.data()??{};return _page([_hero('Shop Profile','Control the information customers see.'),const SizedBox(height:12),
      _editable(context,'Business name',(d['businessName']??d['name']??'').toString(),'businessName'),
      _editable(context,'Description',(d['description']??'').toString(),'description',maxLines:3),
      _editable(context,'About',(d['about']??'').toString(),'about',maxLines:4),
      _editable(context,'Opening hours',(d['openingHours']??'').toString(),'openingHours'),
      Card(child:SwitchListTile(title:const Text('Shop open now'),value:d['isOpen']==true,onChanged:(v)=>FirebaseFirestore.instance.collection('sellers').doc(user.uid).set({'isOpen':v},SetOptions(merge:true)))),
    ]);});
  Widget _editable(BuildContext context,String label,String value,String field,{int maxLines=1})=>Card(elevation:0,child:ListTile(title:Text(label,style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text(value.isEmpty?'Not set':value),trailing:const Icon(Icons.edit_outlined),onTap:()async{
    final c=TextEditingController(text:value);final ok=await showDialog<bool>(context:context,builder:(d)=>AlertDialog(title:Text('Edit '+label),content:TextField(controller:c,maxLines:maxLines,decoration:InputDecoration(labelText:label)),actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(d,true),child:const Text('Save'))]));if(ok==true)await FirebaseFirestore.instance.collection('sellers').doc(user.uid).set({field:c.text.trim()},SetOptions(merge:true));
  }));

  Widget _offers(BuildContext context)=>_page([_hero('Offers','Create and review shop offers.'),const SizedBox(height:12),FilledButton.icon(onPressed:()=>_createOffer(context),icon:const Icon(Icons.add),label:const Text('Create offer')),const SizedBox(height:10),
    StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(stream:FirebaseFirestore.instance.collection('sellers').doc(user.uid).collection('offers').orderBy('createdAt',descending:true).snapshots(),builder:(context,s){if(!s.hasData)return const Center(child:CircularProgressIndicator());if(s.data!.docs.isEmpty)return _empty('No offers','Create an offer and it will be saved to your seller account.');return Column(children:s.data!.docs.map((d)=>Card(child:ListTile(title:Text((d.data()['title']??'Offer').toString(),style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text((d.data()['details']??'').toString()),trailing:Switch(value:d.data()['active']!=false,onChanged:(v)=>d.reference.update({'active':v}) )))).toList());})
  ]);
  Future<void> _createOffer(BuildContext context)async{
    final t=TextEditingController(),d=TextEditingController();final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('Create offer'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:t,decoration:const InputDecoration(labelText:'Offer title')),TextField(controller:d,decoration:const InputDecoration(labelText:'Details'))]),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Create'))]));if(ok==true)await FirebaseFirestore.instance.collection('sellers').doc(user.uid).collection('offers').add({'title':t.text.trim(),'details':d.text.trim(),'active':true,'createdAt':FieldValue.serverTimestamp()});
  }

  Widget _people(String collection,String label,{String? roleFilter}) =>
      StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
        stream: FirebaseFirestore.instance.collection(collection).snapshots(),
        builder: (context,snap) {
          if (snap.hasError) return _page([_error(snap.error.toString())]);
          if (!snap.hasData) return const Center(child:CircularProgressIndicator());

          var docs = snap.data!.docs;
          if (roleFilter != null) {
            docs = docs.where((d) =>
                (d.data()['role'] ?? '').toString().toLowerCase() ==
                roleFilter.toLowerCase()).toList();
          }

          final partnerCollection =
              collection == 'deliveryPartners' || collection == 'ridePartners';

          return _page([
            _hero(feature, 'Review ${label.toLowerCase()} accounts and approval status.'),
            _metricRow(docs.length.toString(), label),
            ...docs.map((d) {
              final x = d.data();
              final name = (x['businessName'] ??
                      x['shopName'] ??
                      x['name'] ??
                      x['displayName'] ??
                      x['email'] ??
                      d.id)
                  .toString();
              final status = (x['approvalStatus'] ??
                      x['status'] ??
                      x['dutyStatus'] ??
                      'active')
                  .toString();
              final available = partnerCollection &&
                  (x['approvalStatus'] ?? '').toString().toLowerCase() == 'approved' &&
                  (x['status'] ?? x['dutyStatus'] ?? '').toString().toLowerCase() == 'online' &&
                  x['availableForDeliveries'] != false &&
                  (x['currentOrderId'] ?? '').toString().trim().isEmpty &&
                  (x['pendingOrderId'] ?? '').toString().trim().isEmpty;

              return Card(
                child: ListTile(
                  leading: partnerCollection
                      ? Stack(
                          clipBehavior: Clip.none,
                          children: [
                            const CircleAvatar(child: Icon(Icons.local_shipping_outlined)),
                            if (available)
                              Positioned(right: -1, bottom: -1, child: Container(
                                width: 12, height: 12,
                                decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                              )),
                          ],
                        )
                      : null,
                  title: Text(name,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(
                      '$status • ${(x['email'] ?? '').toString()}'),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (!partnerCollection) {
                        await d.reference.set(
                          {'status': value},
                          SetOptions(merge: true),
                        );
                        return;
                      }

                      if (value == 'reject') {
                        final reason = TextEditingController();
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Rejection reason'),
                            content: TextField(
                              controller: reason,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                  hintText: 'Reason'),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Reject'),
                              ),
                            ],
                          ),
                        );
                        if (ok == true) {
                          await d.reference.set({
                            'approvalStatus': 'rejected',
                            'status': 'rejected',
                            'rejectionReason': reason.text.trim(),
                            'rejectedAt': FieldValue.serverTimestamp(),
                            'rejectedBy': user.uid,
                            'availableForDeliveries': false,
                            'availableForRides': false,
                            'isOnline': false,
                          }, SetOptions(merge: true));
                        }
                        return;
                      }

                      if (value == 'approved') {
                        await d.reference.set({
                          'approvalStatus': 'approved',
                          'status': 'approved',
                          'approvedAt': FieldValue.serverTimestamp(),
                          'approvedBy': user.uid,
                        }, SetOptions(merge: true));
                      } else if (value == 'suspended') {
                        await d.reference.set({
                          'approvalStatus': 'suspended',
                          'status': 'suspended',
                          'availableForDeliveries': false,
                          'availableForRides': false,
                          'isOnline': false,
                          'suspendedAt': FieldValue.serverTimestamp(),
                          'suspendedBy': user.uid,
                        }, SetOptions(merge: true));
                      } else if (value == 'offline') {
                        await d.reference.set({
                          'status': 'approved',
                          'isOnline': false,
                          'availableForDeliveries': false,
                          'availableForRides': false,
                        }, SetOptions(merge: true));
                      }
                    },
                    itemBuilder: (_) => partnerCollection
                        ? const [
                            PopupMenuItem(
                                value: 'approved', child: Text('Approve')),
                            PopupMenuItem(
                                value: 'reject', child: Text('Reject')),
                            PopupMenuItem(
                                value: 'suspended', child: Text('Suspend')),
                            PopupMenuItem(
                                value: 'offline', child: Text('Offline')),
                          ]
                        : const [
                            PopupMenuItem(
                                value: 'approved', child: Text('Approve')),
                            PopupMenuItem(
                                value: 'suspended', child: Text('Suspend')),
                            PopupMenuItem(
                                value: 'offline', child: Text('Offline')),
                          ],
                  ),
                ),
              );
            }),
          ]);
        },
      );

  Widget _metricRow(String v,String l)=>Card(elevation:0,color:accent.withOpacity(.06),child:Padding(padding:const EdgeInsets.all(14),child:Row(children:[Icon(Icons.people_outline,color:accent),const SizedBox(width:10),Text(v,style:const TextStyle(fontSize:22,fontWeight:FontWeight.w900)),const SizedBox(width:8),Text(l)])));

  Widget _users(BuildContext context)=>StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(stream:FirebaseFirestore.instance.collection('customers').snapshots(),builder:(context,s){if(!s.hasData)return const Center(child:CircularProgressIndicator());final docs=s.data!.docs;return _page([_hero('Users & Roles','Manage access without leaving the app.'),_metricRow(docs.length.toString(),'Accounts'),...docs.map((d){final x=d.data();final role=(x['role']??'customer').toString();return Card(child:ListTile(title:Text((x['displayName']??x['email']??d.id).toString(),style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text((x['email']??'').toString()),trailing:DropdownButton<String>(value:['customer','seller','delivery_partner','carrier','admin'].contains(role)?role:'customer',items:const['customer','seller','delivery_partner','carrier','admin'].map((r)=>DropdownMenuItem(value:r,child:Text(r))).toList(),onChanged:(v)=>v==null?null:d.reference.update({'role':v}) )));})]);});

  Widget _earnings()=>StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(stream:FirebaseFirestore.instance.collection('orders').where('carrierUid',isEqualTo:user.uid).snapshots(),builder:(context,s){num total=0;int done=0;for(final d in s.data?.docs??const <QueryDocumentSnapshot<Map<String,dynamic>>>[]){if(_isDone(d.data()['status'])){done++;total+=_num(d.data()['deliveryFee']??d.data()['partnerEarning']??d.data()['total']);}}return _page([_hero(feature,'Live earnings from completed work.'),const SizedBox(height:12),Row(children:[_metric('₹'+total.toStringAsFixed(0),'Completed earnings',Icons.currency_rupee),_metric(done.toString(),'Completed',Icons.check_circle)]),const SizedBox(height:12),_empty(done==0?'No completed work':'Earnings updated','Completed deliveries and rides are counted automatically.')]);});

  Widget _analytics()=>StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(stream:FirebaseFirestore.instance.collection('orders').snapshots(),builder:(context,s){final docs=s.data?.docs??const <QueryDocumentSnapshot<Map<String,dynamic>>>[];final done=docs.where((d)=>_isDone(d.data()['status'])).length;num value=0;for(final d in docs)value+=_num(d.data()['total']);return _page([_hero(feature,'Simple live performance metrics.'),const SizedBox(height:12),Row(children:[_metric(docs.length.toString(),'Orders',Icons.receipt_long),_metric(done.toString(),'Completed',Icons.check_circle),_metric('₹'+value.toStringAsFixed(0),'Order value',Icons.currency_rupee)]),const SizedBox(height:12),Card(child:ListTile(leading:Icon(Icons.insights,color:accent),title:const Text('Live data'),subtitle:const Text('Metrics update automatically from Firestore as orders change.')))]);});

  Widget _documents()=>_page([_hero(feature,'Keep verification and vehicle information easy to review.'),_infoTile('Verification status','Your approved role remains linked to your account.'),_infoTile('Documents','Vehicle and identity documents submitted during onboarding are kept with the role profile.'),_infoTile('Update details','Use Profile & Settings or contact ALLways support when a document needs replacement.')]);
  Widget _infoTile(String a,String b)=>Card(child:ListTile(leading:Icon(Icons.verified_user_outlined,color:accent),title:Text(a,style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text(b),trailing:const Icon(Icons.chevron_right)));

  Widget _safety(BuildContext context)=>_page([_hero('Safety & SOS','Emergency tools stay one tap away.'),Card(child:ListTile(leading:const Icon(Icons.sos,color:Colors.red),title:const Text('SOS / Emergency alert',style:TextStyle(fontWeight:FontWeight.w800)),subtitle:const Text('Send an alert to the ALLways operations team.'),onTap:()async{final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('Send SOS?'),content:const Text('Use this only for a genuine emergency.'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Send SOS'))]));if(ok==true){await FirebaseFirestore.instance.collection('sosAlerts').add({'uid':user.uid,'role':role,'createdAt':FieldValue.serverTimestamp(),'status':'open'});if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('SOS alert sent to ALLways operations.')));}})),_infoTile('Emergency contact','Keep a trusted contact ready for active trips.'),_infoTile('Trip safety','Live tracking and calling are available during active work.')]);

  Widget _support(BuildContext context)=>_page([_hero('Help & Support','Create a support request and keep it attached to your account.'),FilledButton.icon(onPressed:()=>_createTicket(context),icon:const Icon(Icons.support_agent),label:const Text('Contact ALLways support')),const SizedBox(height:12),_infoTile('Order issue','Report a delivery, customer or order problem.'),_infoTile('Account help','Get help with profile, verification or access.')]);
  Future<void> _createTicket(BuildContext context)async{final c=TextEditingController();final ok=await showDialog<bool>(context:context,builder:(d)=>AlertDialog(title:const Text('Support request'),content:TextField(controller:c,maxLines:4,decoration:const InputDecoration(hintText:'Describe the issue')),actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(d,true),child:const Text('Send'))]));if(ok==true&&c.text.trim().isNotEmpty){await FirebaseFirestore.instance.collection('support_tickets').add({'uid':user.uid,'role':role,'message':c.text.trim(),'status':'open','createdAt':FieldValue.serverTimestamp()});if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Support request submitted.')));}}

  Widget _announcement(BuildContext context){
    final title=TextEditingController();
    final body=TextEditingController();
    String audience='all_users';

    return StatefulBuilder(
      builder:(context,setLocalState)=>_page([
        _hero('Send Notifications','Create an announcement and route it to the selected ALLways audience.'),
        TextField(controller:title,decoration:const InputDecoration(labelText:'Title')),
        const SizedBox(height:10),
        TextField(controller:body,maxLines:4,decoration:const InputDecoration(labelText:'Message')),
        const SizedBox(height:10),
        DropdownButtonFormField<String>(
          value:audience,
          decoration:const InputDecoration(labelText:'Audience'),
          items:const [
            DropdownMenuItem(value:'all_users',child:Text('All users')),
            DropdownMenuItem(value:'admins',child:Text('Admins')),
            DropdownMenuItem(value:'carriers',child:Text('Carriers')),
            DropdownMenuItem(value:'delivery_partners',child:Text('Delivery partners')),
            DropdownMenuItem(value:'customers',child:Text('Customers')),
          ],
          onChanged:(value){
            if(value!=null)setLocalState(()=>audience=value);
          },
        ),
        const SizedBox(height:12),
        FilledButton.icon(
          onPressed:()async{
            if(title.text.trim().isEmpty||body.text.trim().isEmpty)return;
            await FirebaseFirestore.instance.collection('announcements').add({
              'title':title.text.trim(),
              'body':body.text.trim(),
              'type':'announcement',
              'topic':audience,
              'targetAudience':audience,
              'createdAt':FieldValue.serverTimestamp(),
              'createdBy':user.uid,
              'status':'queued',
            });
            if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content:Text('Announcement queued for notification delivery.')),
            );
          },
          icon:const Icon(Icons.campaign),
          label:const Text('Publish announcement'),
        ),
      ]),
    );
  }

  Widget _account(BuildContext context)=>_page([_hero(feature,'Account controls for this role.'),Card(child:ListTile(leading:const Icon(Icons.email_outlined),title:const Text('Approved email'),subtitle:Text(user.email??'Not available'))),Card(child:ListTile(leading:const Icon(Icons.logout),title:const Text('Sign out'),onTap:()=>FirebaseAuth.instance.signOut()))]);

  Widget _empty(String title,String message)=>Card(elevation:0,child:Padding(padding:const EdgeInsets.all(24),child:Column(children:[Icon(icon,color:accent,size:38),const SizedBox(height:10),Text(title,style:const TextStyle(fontWeight:FontWeight.w900)),const SizedBox(height:5),Text(message,textAlign:TextAlign.center,style:const TextStyle(color:Colors.grey))])));
  Widget _error(String message)=>Card(child:Padding(padding:const EdgeInsets.all(14),child:Text(message,style:const TextStyle(color:Colors.red))));
  num _num(dynamic v)=>v is num?v:num.tryParse((v??'').toString().replaceAll(',',''))??0;
  bool _isDone(dynamic v){final s=(v??'').toString().toLowerCase();return s=='delivered'||s=='completed'||s=='cancelled';}
}


class RideRequestsScreen extends StatefulWidget {
  final User user;
  final Color accent;
  const RideRequestsScreen({super.key,required this.user,required this.accent});
  @override State<RideRequestsScreen> createState()=>_RideRequestsScreenState();
}

class _RideRequestsScreenState extends State<RideRequestsScreen> {
  static const radiusKm=7.0;
  Position? position;
  Map<String,double> distances={};
  bool online=false,loading=true;
  String vehicle='bike';
  Stream<QuerySnapshot<Map<String,dynamic>>> get stream=>FirebaseFirestore.instance.collection('autoRideRequests').where('status',isEqualTo:'searching').snapshots();

  @override void initState(){super.initState();_load();}
  Future<void> _load()async{
    final snap=await FirebaseFirestore.instance.collection('ridePartners').doc(widget.user.uid).get();
    online=(snap.data()?['status']??'offline').toString().toLowerCase()=='online';
    final rawVehicle=(snap.data()?['vehicleType']??'bike').toString().toLowerCase();
    vehicle=rawVehicle=='two_wheeler'?'bike':rawVehicle;
    await _locate();
    if(mounted)setState(()=>loading=false);
  }
  Future<void> _locate()async{
    try{
      if(!await Geolocator.isLocationServiceEnabled())return;
      var p=await Geolocator.checkPermission();
      if(p==LocationPermission.denied)p=await Geolocator.requestPermission();
      if(p==LocationPermission.denied||p==LocationPermission.deniedForever)return;
      position=await Geolocator.getCurrentPosition(locationSettings:const LocationSettings(accuracy:LocationAccuracy.high,distanceFilter:10));
    }catch(_){}
  }
  Future<void> _toggle(bool value)async{
    try{
      if(value)await _locate();
      if(value&&position==null){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Turn on location permission before going online.')));return;}
      await FirebaseFirestore.instance.collection('ridePartners').doc(widget.user.uid).set({'status':value?'online':'offline','availableForRides':value,'carrierLat':position?.latitude,'carrierLng':position?.longitude,'statusUpdatedAt':FieldValue.serverTimestamp()},SetOptions(merge:true));
      if(mounted)setState(()=>online=value);
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Could not change duty status: '+e.toString())));}
  }
  Future<void> _reject(QueryDocumentSnapshot<Map<String,dynamic>> d)async{await d.reference.update({'rejectedBy':FieldValue.arrayUnion([widget.user.uid]),'updatedAt':FieldValue.serverTimestamp()});}
  Future<void> _accept(QueryDocumentSnapshot<Map<String,dynamic>> d)async{
    try{
      await FirebaseFirestore.instance.runTransaction((tx)async{
        final latest=await tx.get(d.reference);
        final p=await tx.get(FirebaseFirestore.instance.collection('ridePartners').doc(widget.user.uid));
        final o=latest.data()??{},profile=p.data()??{};
        if((o['status']??'').toString().toLowerCase()!='searching')throw Exception('Ride already accepted by another rider.');
        final type=(o['rideType']??'bike').toString().toLowerCase();
        final vehicle=(profile['vehicleType']??'bike').toString().toLowerCase();
        final normalized=vehicle=='two_wheeler'?'bike':vehicle;
        if(type!=normalized)throw Exception('This request is for a different vehicle type.');
        tx.update(d.reference,{'status':'accepted','driverUid':widget.user.uid,'driverName':profile['name']??widget.user.displayName??'ALLways Rider','driverPhone':profile['mobileNumber']??widget.user.phoneNumber??'','driverVehicleType':normalized,'acceptedAt':FieldValue.serverTimestamp(),'updatedAt':FieldValue.serverTimestamp()});
        tx.set(p.reference,{'status':'offline','availableForRides':false,'activeRideId':d.id,'statusUpdatedAt':FieldValue.serverTimestamp()},SetOptions(merge:true));
      });
      if(mounted){setState(()=>online=false);ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Ride accepted. Open My Rides for tracking and completion.')));}
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));}
  }
  double _num(dynamic v)=>v is num?v.toDouble():double.tryParse((v??'').toString())??0;
  @override Widget build(BuildContext context){
    return Column(children:[
      Container(padding:const EdgeInsets.fromLTRB(16,14,16,14),color:Colors.white,child:Row(children:[
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Uber-style rider queue',style:TextStyle(fontSize:20,fontWeight:FontWeight.w900)),Text(online?'Online • accepting requests within 7 km':'Offline • go online to receive rides',style:TextStyle(color:widget.accent,fontWeight:FontWeight.w700))])),
        Switch(value:online,onChanged:loading?null:_toggle),
      ])),
      Expanded(child:StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(stream:stream,builder:(context,snap){
        if(loading)return const Center(child:CircularProgressIndicator());
        if(!online)return const Center(child:Padding(padding:EdgeInsets.all(28),child:Text('You are offline. Turn on duty status to receive nearby ride requests.',textAlign:TextAlign.center)));
        if(position==null)return const Center(child:Padding(padding:EdgeInsets.all(28),child:Text('Live location is required to show the 7 km request radius.',textAlign:TextAlign.center)));
        final list=<QueryDocumentSnapshot<Map<String,dynamic>>>[];distances={};
        for(final d in snap.data?.docs??const <QueryDocumentSnapshot<Map<String,dynamic>>>[]){
          final o=d.data();final rejected=o['rejectedBy'] is List?List.from(o['rejectedBy']):<dynamic>[];
          if(rejected.contains(widget.user.uid))continue;
          final type=(o['rideType']??'bike').toString().toLowerCase();
          if(type!=vehicle)continue;
          final lat=_num(o['pickupLatitude']),lng=_num(o['pickupLongitude']);
          final km=Geolocator.distanceBetween(position!.latitude,position!.longitude,lat,lng)/1000;
          if(km<=radiusKm){distances[d.id]=km;list.add(d);}
        }
        list.sort((a,b)=>(distances[a.id]??99).compareTo(distances[b.id]??99));
        if(list.isEmpty)return const Center(child:Padding(padding:EdgeInsets.all(28),child:Text('No ride requests within 7 km right now.',textAlign:TextAlign.center)));
        return ListView(padding:const EdgeInsets.fromLTRB(16,14,16,28),children:list.map((d){
          final o=d.data();final type=(o['rideType']??'bike').toString();final km=distances[d.id]??0;
          return Card(elevation:0,margin:const EdgeInsets.only(bottom:12),child:Padding(padding:const EdgeInsets.all(15),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Row(children:[CircleAvatar(backgroundColor:widget.accent.withOpacity(.1),child:Icon(type=='auto'?Icons.local_taxi_outlined:Icons.two_wheeler,color:widget.accent)),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(type.toUpperCase()+' RIDE',style:const TextStyle(fontWeight:FontWeight.w900)),Text(km.toStringAsFixed(1)+' km away',style:TextStyle(color:widget.accent,fontWeight:FontWeight.w700))])),Text('₹'+_num(o['estimatedFare']??o['fare']??o['total']).toStringAsFixed(0),style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900))]),
            const SizedBox(height:10),Text((o['pickupAddress']??o['address']??'Pickup location').toString(),maxLines:2,overflow:TextOverflow.ellipsis),Text((o['destinationAddress']??o['destination']??'Destination').toString(),maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(color:Colors.grey)),
            const SizedBox(height:12),Row(children:[Expanded(child:OutlinedButton(onPressed:()=>_reject(d),child:const Text('Reject'))),const SizedBox(width:10),Expanded(child:FilledButton(onPressed:()=>_accept(d),style:FilledButton.styleFrom(backgroundColor:widget.accent),child:const Text('Accept')))]),
          ])));
        }).toList());
      })),
    ]);
  }
}


class _AdminOrdersFilterView extends StatefulWidget{
  final String role,feature; final User user; final Color accent;
  final Future<void> Function(BuildContext,QueryDocumentSnapshot<Map<String,dynamic>>) onAssign;
  const _AdminOrdersFilterView({required this.role,required this.feature,required this.user,required this.accent,required this.onAssign});
  @override State<_AdminOrdersFilterView> createState()=>_AdminOrdersFilterViewState();
}
class _AdminOrdersFilterViewState extends State<_AdminOrdersFilterView>{
  String statusFilter='All',dateFilter='All time';
  DateTime? customStart,customEnd;
  DateTime _time(dynamic v)=>v is Timestamp?v.toDate():v is DateTime?v:DateTime.fromMillisecondsSinceEpoch(v is num?v.toInt():0);
  num _num(dynamic v)=>v is num?v:num.tryParse((v??'').toString())??0;
  bool _done(dynamic v){final s=(v??'').toString().toLowerCase();return s=='delivered'||s=='completed';}
  Widget _empty(String a,String b)=>Card(child:Padding(padding:const EdgeInsets.all(20),child:Column(children:[const Icon(Icons.inbox_outlined,size:42),const SizedBox(height:8),Text(a,style:const TextStyle(fontWeight:FontWeight.w800)),Text(b,style:const TextStyle(color:Colors.grey))])));
  bool _inDate(DateTime dt){
    final now=DateTime.now();
    final day=DateTime(dt.year,dt.month,dt.day);
    final today=DateTime(now.year,now.month,now.day);
    if(dateFilter=='Today')return day==today;
    if(dateFilter=='Yesterday')return day==today.subtract(const Duration(days:1));
    if(dateFilter=='Last 7 days')return !day.isBefore(today.subtract(const Duration(days:6)))&&!day.isAfter(today);
    if(dateFilter=='Last week'){
      final monday=today.subtract(Duration(days:today.weekday-1));
      final start=monday.subtract(const Duration(days:7));
      final end=monday.subtract(const Duration(days:1));
      return !day.isBefore(start)&&!day.isAfter(end);
    }
    if(dateFilter=='This month')return dt.year==now.year&&dt.month==now.month;
    if(dateFilter=='Last month'){
      final firstThis=DateTime(now.year,now.month,1);
      final lastPrevious=firstThis.subtract(const Duration(days:1));
      return dt.year==lastPrevious.year&&dt.month==lastPrevious.month;
    }
    if(dateFilter=='This year')return dt.year==now.year;
    if(dateFilter=='Custom'&&customStart!=null&&customEnd!=null){
      final start=DateTime(customStart!.year,customStart!.month,customStart!.day);
      final end=DateTime(customEnd!.year,customEnd!.month,customEnd!.day,23,59,59);
      return !dt.isBefore(start)&&!dt.isAfter(end);
    }
    return true;
  }
  Future<void> _pickCustomRange() async{
    final now=DateTime.now();
    final picked=await showDateRangePicker(
      context:context,
      firstDate:DateTime(2020),
      lastDate:DateTime(now.year,now.month,now.day),
      initialDateRange:customStart!=null&&customEnd!=null?DateTimeRange(start:customStart!,end:customEnd!):DateTimeRange(start:todayMinus(now,7),end:now),
    );
    if(picked==null||!mounted)return;
    setState((){customStart=picked.start;customEnd=picked.end;dateFilter='Custom';});
  }
  DateTime todayMinus(DateTime d,int days)=>DateTime(d.year,d.month,d.day).subtract(Duration(days:days));
  void _showItems(BuildContext context,Map<String,dynamic> o){
    final raw=o['items'];final items=raw is List?raw.whereType<Map>().map((x)=>Map<String,dynamic>.from(x)).toList():<Map<String,dynamic>>[];
    showModalBottomSheet(context:context,showDragHandle:true,builder:(_)=>SafeArea(child:Padding(padding:const EdgeInsets.fromLTRB(20,8,20,24),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('Order items',style:TextStyle(fontSize:20,fontWeight:FontWeight.w900)),const SizedBox(height:10),
      if(items.isEmpty)const Text('No item details were saved with this order.'),
      ...items.map((x)=>ListTile(dense:true,leading:const Icon(Icons.inventory_2_outlined),title:Text((x['name']??x['title']??'Item').toString(),style:const TextStyle(fontWeight:FontWeight.w700)),subtitle:Text('Qty: '+(x['qty']??x['quantity']??1).toString()),trailing:Text('₹'+_num(x['price']).toStringAsFixed(0)))),
      const Divider(),Align(alignment:Alignment.centerRight,child:Text('Total: ₹'+_num(o['total']).toStringAsFixed(0),style:const TextStyle(fontWeight:FontWeight.w900))),
    ]))));
  }
  @override Widget build(BuildContext context)=>StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
    stream:FirebaseFirestore.instance.collection('orders').snapshots(),
    builder:(context,snap){
      if(snap.hasError)return const Center(child:Text('Could not load orders.'));
      if(!snap.hasData)return const Center(child:CircularProgressIndicator());
      var docs=snap.data!.docs.where((d){
        final o=d.data();final s=(o['status']??'').toString().toLowerCase();
        if(widget.role=='seller')return (o['sellerId']??o['sellerUid']??'').toString()==widget.user.uid;
        if(widget.role=='delivery_partner'||widget.role=='carrier')return (o['carrierUid']??'').toString()==widget.user.uid;
        if(widget.feature=='Ride History')return s=='completed'||s=='delivered';
        return true;
      }).toList();
      docs.sort((a,b)=>_time(b.data()['createdAt']).compareTo(_time(a.data()['createdAt'])));
      final dateDocs=docs.where((d)=>_inDate(_time(d.data()['createdAt']))).toList();
      final filtered=dateDocs.where((d){
        final s=(d.data()['status']??'').toString().toLowerCase();
        if(statusFilter=='New Order')return s=='new order'||s=='new'||s=='pending';
        if(statusFilter=='Confirmed')return s.contains('confirm');
        if(statusFilter=='Preparing')return s.contains('prepar');
        if(statusFilter=='Assigned')return s=='assigned';
        if(statusFilter=='Out for delivery')return s=='out for delivery'||s=='out_for_delivery';
        if(statusFilter=='Delivered')return s=='delivered'||s=='completed';
        if(statusFilter=='Cancelled')return s=='cancelled';
        return true;
      }).toList();
      const statuses=['All','New Order','Confirmed','Preparing','Assigned','Out for delivery','Delivered','Cancelled'];
      const dates=['All time','Today','Yesterday','Last 7 days','Last week','This month','Last month','This year','Custom'];
      final attention=dateDocs.where((d)=>['new order','pending','pending_acceptance','confirmed'].contains((d.data()['status']??'').toString().toLowerCase())).length;
      final completed=dateDocs.where((d)=>_done(d.data()['status'])).length;
      return ListView(padding:const EdgeInsets.fromLTRB(16,14,16,28),children:[
        Card(elevation:0,color:widget.accent.withOpacity(.08),child:Padding(padding:const EdgeInsets.all(16),child:Row(children:[CircleAvatar(backgroundColor:widget.accent.withOpacity(.14),child:Icon(Icons.receipt_long,color:widget.accent)),const SizedBox(width:12),const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Manage Orders',style:TextStyle(fontSize:19,fontWeight:FontWeight.w900)),Text('Filter orders by status, date, and open item details.',style:TextStyle(color:Colors.black54))]))]))),
        const SizedBox(height:12),
        StreamBuilder<DocumentSnapshot<Map<String,dynamic>>>(
          stream:FirebaseFirestore.instance.collection('settings').doc('deliveryAssignment').snapshots(),
          builder:(context,assignmentSnap){
            final mode=(assignmentSnap.data?.data()?['mode']??'manual').toString().toLowerCase();
            final automatic=mode=='automatic';
            return Card(
              elevation:0,
              child:SwitchListTile(
                contentPadding:const EdgeInsets.symmetric(horizontal:14,vertical:2),
                secondary:Icon(automatic?Icons.auto_awesome:Icons.touch_app_outlined,color:widget.accent),
                title:const Text('Delivery assignment',style:TextStyle(fontWeight:FontWeight.w800)),
                subtitle:Text(automatic
                    ? 'Automatic: assign new orders to an available delivery partner.'
                    : 'Manual: Admin assigns each delivery partner.'),
                value:automatic,
                onChanged:(value)async{
                  await FirebaseFirestore.instance.collection('settings').doc('deliveryAssignment').set({
                    'mode':value?'automatic':'manual',
                    'updatedAt':FieldValue.serverTimestamp(),
                    'updatedBy':widget.user.uid,
                  },SetOptions(merge:true));
                },
              ),
            );
          },
        ),
        const SizedBox(height:12),
        const Text('Order status',style:TextStyle(fontWeight:FontWeight.w800)),
        const SizedBox(height:6),
        SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:statuses.map((s)=>Padding(padding:const EdgeInsets.only(right:8),child:ChoiceChip(label:Text(s),selected:statusFilter==s,onSelected:(_){setState(()=>statusFilter=s);})) ).toList())),
        const SizedBox(height:10),
        Row(children:[const Icon(Icons.date_range_outlined,size:19),const SizedBox(width:7),const Text('Date range',style:TextStyle(fontWeight:FontWeight.w800)),const Spacer(),if(dateFilter=='Custom')TextButton(onPressed:_pickCustomRange,child:const Text('Change'))]),
        const SizedBox(height:6),
        SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:dates.map((s)=>Padding(padding:const EdgeInsets.only(right:8),child:ChoiceChip(label:Text(s),selected:dateFilter==s,onSelected:(_){if(s=='Custom'){_pickCustomRange();}else{setState(()=>dateFilter=s);}}))).toList())),
        const SizedBox(height:12),
        Row(children:[
          Expanded(child:Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Icon(Icons.receipt_long),const SizedBox(height:5),Text(filtered.length.toString(),style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900)),const Text('Showing',style:TextStyle(fontSize:11,color:Colors.grey))])))),
          Expanded(child:Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Icon(Icons.priority_high),const SizedBox(height:5),Text(attention.toString(),style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900)),const Text('Needs attention',style:TextStyle(fontSize:11,color:Colors.grey))])))),
          Expanded(child:Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Icon(Icons.check_circle),const SizedBox(height:5),Text(completed.toString(),style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900)),const Text('Completed',style:TextStyle(fontSize:11,color:Colors.grey))])))),
        ]),
        const SizedBox(height:12),
        if(filtered.isEmpty)_empty('Nothing here yet','No orders match these filters.')
        else ...filtered.map((d){final o=d.data();final id=(o['id']??d.id).toString();final status=(o['status']??'New Order').toString();final assigned=(o['carrierName']??'').toString().trim();final raw=o['items'];final count=raw is List?raw.length:0;
          return Card(elevation:0,child:ListTile(
            leading:CircleAvatar(backgroundColor:widget.accent.withOpacity(.1),child:Icon(Icons.receipt_long,color:widget.accent)),
            title:Text('#'+id,style:const TextStyle(fontWeight:FontWeight.w800)),
            subtitle:Text((o['name']??o['customerName']??'Customer').toString()+' • '+status+(count>0?' • '+count.toString()+' item'+(count==1?'':'s'):'')+(assigned.isEmpty?'':' • Assigned: '+assigned)),
            trailing:Column(mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.end,children:[Text('₹'+_num(o['total']).toStringAsFixed(0),style:const TextStyle(fontWeight:FontWeight.w900)),if(widget.role=='admin'&&status.toLowerCase()!='cancelled'&&status.toLowerCase()!='delivered')TextButton(onPressed:()=>widget.onAssign(context,d),child:Text(assigned.isEmpty?'Assign':'Reassign'))]),
            onTap:()=>_showItems(context,o),
          ));
        }),
      ]);
    },
  );
}
