import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminPlatformOperationsScreen extends StatefulWidget{
  final String module; final Color accent; final String adminUid;
  const AdminPlatformOperationsScreen({super.key,required this.module,required this.accent,required this.adminUid});
  @override State<AdminPlatformOperationsScreen> createState()=>_AdminPlatformOperationsScreenState();
}
class _AdminPlatformOperationsScreenState extends State<AdminPlatformOperationsScreen>{
  late String module;
  @override void initState(){super.initState();module=widget.module;}
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:Text(module)),
    body:module=='Customers'?const _Customers():module=='Service Areas'?_Areas(widget.accent,widget.adminUid):module=='Marketing'?_Marketing(widget.accent,widget.adminUid):module=='Finance'?_Finance():module=='Business Purchases'?_Purchases(widget.accent,widget.adminUid):_GlobalSearch(widget.accent),
  );
}

class _Customers extends StatelessWidget{
  const _Customers();
  @override Widget build(BuildContext context)=>StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(stream:FirebaseFirestore.instance.collection('customers').limit(300).snapshots(),builder:(c,s){
    if(!s.hasData)return const Center(child:CircularProgressIndicator());
    return StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(stream:FirebaseFirestore.instance.collection('orders').limit(1000).snapshots(),builder:(c,o){
      if(!o.hasData)return const Center(child:CircularProgressIndicator());
      final counts=<String,int>{};for(final d in o.data!.docs){final x=d.data();final id=(x['customerId']??x['uid']??x['userId']??'').toString();if(id.isNotEmpty)counts[id]=(counts[id]??0)+1;}
      final docs=s.data!.docs.toList()..sort((a,b)=>(counts[b.id]??0).compareTo(counts[a.id]??0));
      return ListView(padding:const EdgeInsets.all(16),children:[
        Text('Customers: ${docs.length}',style:const TextStyle(fontSize:22,fontWeight:FontWeight.w900)),const SizedBox(height:10),
        ...docs.map((d){final x=d.data();final n=counts[d.id]??0;final segment=n>=5?'Loyal':n>=2?'Repeat':'New';return Card(elevation:0,child:ListTile(
          leading:CircleAvatar(child:Text(((x['name']??x['displayName']??x['email']??'C').toString().substring(0,1)).toUpperCase())),
          title:Text((x['name']??x['displayName']??x['email']??d.id).toString(),style:const TextStyle(fontWeight:FontWeight.w800)),
          subtitle:Text('$segment • $n orders • ${x['phone'] ?? x['mobileNumber'] ?? ''}'),
          trailing:Text(n.toString(),style:const TextStyle(fontWeight:FontWeight.w900)),
        ));})
      ]);
    });
  });
}

class _Areas extends StatelessWidget{
  final Color accent;final String adminUid;const _Areas(this.accent,this.adminUid);
  Future<void> _add(BuildContext context)async{
    final name=TextEditingController(),pin=TextEditingController();
    final ok=await showDialog<bool>(context:context,builder:(d)=>AlertDialog(title:const Text('Add service area'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:name,decoration:const InputDecoration(labelText:'Area name')),TextField(controller:pin,decoration:const InputDecoration(labelText:'PIN codes / coverage'))]),actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(d,true),child:const Text('Add'))]));
    if(ok==true&&name.text.trim().isNotEmpty)await FirebaseFirestore.instance.collection('serviceAreas').add({'name':name.text.trim(),'coverage':pin.text.trim(),'active':true,'deliveryAvailable':true,'rideAvailable':true,'updatedBy':adminUid,'createdAt':FieldValue.serverTimestamp(),'updatedAt':FieldValue.serverTimestamp()});
  }
  @override Widget build(BuildContext context)=>StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(stream:FirebaseFirestore.instance.collection('serviceAreas').limit(200).snapshots(),builder:(c,s){
    if(!s.hasData)return const Center(child:CircularProgressIndicator());
    return ListView(padding:const EdgeInsets.all(16),children:[Row(children:[const Expanded(child:Text('Service Areas',style:TextStyle(fontSize:22,fontWeight:FontWeight.w900))),FilledButton.icon(onPressed:()=>_add(context),icon:const Icon(Icons.add),label:const Text('Add'))]),const SizedBox(height:10),
      if(s.data!.docs.isEmpty)const Text('No service areas configured yet.'),
      ...s.data!.docs.map((d){final x=d.data();return Card(child:SwitchListTile(title:Text((x['name']??'Area').toString()),subtitle:Text((x['coverage']??'').toString()),value:x['active']!=false,onChanged:(v)=>d.reference.update({'active':v,'updatedAt':FieldValue.serverTimestamp(),'updatedBy':adminUid})));})
    ]);
  });
}

class _Marketing extends StatelessWidget {
  final Color accent;
  final String adminUid;
  const _Marketing(this.accent, this.adminUid);

  Future<void> _send(BuildContext context) async {
    final title = TextEditingController();
    final body = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Send notification'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
              TextField(controller: body, maxLines: 4, decoration: const InputDecoration(labelText: 'Message')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
          FilledButton.icon(
            onPressed: () => Navigator.pop(d, true),
            icon: const Icon(Icons.send_outlined),
            label: const Text('Queue for delivery'),
          ),
        ],
      ),
    );
    if (ok != true || title.text.trim().isEmpty) return;

    try {
      await FirebaseFirestore.instance.collection('announcements').add({
        'title': title.text.trim(),
        'body': body.text.trim(),
        'topic': 'all_users',
        'type': 'announcement',
        'status': 'queued',
        'createdBy': adminUid,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification queued. Delivery is not confirmed until its status becomes sent.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not queue notification: ' + error.toString())),
        );
      }
    } finally {
      title.dispose();
      body.dispose();
    }
  }

  Future<void> _retry(BuildContext context, QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final original = doc.data();
    final status = (original['status'] ?? 'queued').toString().toLowerCase();
    if (status == 'sent') return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Retry notification?'),
        content: const Text('This creates a new delivery attempt. If the previous attempt was actually delivered but its status was not updated, recipients could receive the message twice.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
          FilledButton.icon(
            onPressed: () => Navigator.pop(d, true),
            icon: const Icon(Icons.refresh),
            label: const Text('Create retry'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await FirebaseFirestore.instance.collection('announcements').add({
        'title': (original['title'] ?? 'ALLways').toString(),
        'body': (original['body'] ?? '').toString(),
        'topic': (original['topic'] ?? original['targetAudience'] ?? 'all_users').toString(),
        'type': (original['type'] ?? 'announcement').toString(),
        'status': 'queued',
        'createdBy': adminUid,
        'createdAt': FieldValue.serverTimestamp(),
        'retryOf': doc.id,
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A new attempt was queued. Wait for backend confirmation before retrying again.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not queue retry: ' + error.toString())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('announcements').limit(50).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Could not load notifications: ' + snapshot.error.toString()));
          }
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs.toList()
            ..sort((a, b) {
              final av = a.data()['createdAt'];
              final bv = b.data()['createdAt'];
              final at = av is Timestamp ? av.millisecondsSinceEpoch : 0;
              final bt = bv is Timestamp ? bv.millisecondsSinceEpoch : 0;
              return bt.compareTo(at);
            });

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('Marketing & Messaging', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                  ),
                  FilledButton.icon(
                    onPressed: () => _send(context),
                    icon: const Icon(Icons.send_outlined),
                    label: const Text('Send notification'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Queued means waiting for the server. Sent means FCM accepted the request; it does not guarantee Android displayed it on the device.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 10),
              if (docs.isEmpty) const Text('No notifications yet.'),
              ...docs.map((doc) {
                final data = doc.data();
                final status = (data['status'] ?? 'queued').toString();
                final normalized = status.toLowerCase();
                final sent = normalized == 'sent';
                final failed = normalized == 'failed';
                final statusColor = sent ? Colors.green : failed ? Colors.red : Colors.orange;
                final error = (data['error'] ?? '').toString();
                return Card(
                  child: ListTile(
                    isThreeLine: error.isNotEmpty,
                    title: Text((data['title'] ?? 'Announcement').toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text((data['body'] ?? '').toString()),
                        const SizedBox(height: 4),
                        Text(error.isEmpty ? 'Status: ' + status : 'Status: ' + status + ' • ' + error,
                          style: TextStyle(color: failed ? Colors.red : Colors.grey.shade700)),
                      ],
                    ),
                    trailing: SizedBox(
                      width: 105,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontWeight: FontWeight.w800, fontSize: 11)),
                          if (!sent)
                            IconButton(
                              tooltip: 'Retry delivery',
                              visualDensity: VisualDensity.compact,
                              onPressed: () => _retry(context, doc),
                              icon: const Icon(Icons.refresh),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          );
        },
      );
}

class _Finance extends StatelessWidget{
  double n(dynamic v)=>v is num?v.toDouble():double.tryParse((v??'').toString())??0;
  @override Widget build(BuildContext context)=>StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(stream:FirebaseFirestore.instance.collection('orders').limit(1000).snapshots(),builder:(c,s){
    if(!s.hasData)return const Center(child:CircularProgressIndicator());final docs=s.data!.docs.map((d)=>d.data()).toList();final done=docs.where((x)=>{'delivered','completed'}.contains((x['status']??'').toString().toLowerCase())).toList();final gross=done.fold<double>(0,(a,x)=>a+n(x['total']));
    return ListView(padding:const EdgeInsets.all(16),children:[const Text('Finance',style:TextStyle(fontSize:22,fontWeight:FontWeight.w900)),const SizedBox(height:12),_box('Completed sales','₹'+gross.toStringAsFixed(0)),_box('Completed orders',done.length.toString()),_box('Average order value',done.isEmpty?'₹0':'₹'+(gross/done.length).toStringAsFixed(0)),const SizedBox(height:10),const Text('Payouts should be generated from server-side payout rules; no payout formula is hard-coded in the client.',style:TextStyle(color:Colors.grey))]);
  });
  Widget _box(String a,String b)=>Card(child:ListTile(title:Text(a),trailing:Text(b,style:const TextStyle(fontSize:19,fontWeight:FontWeight.w900))));
}

class _Purchases extends StatelessWidget{
  final Color accent;final String adminUid;const _Purchases(this.accent,this.adminUid);
  Future<void> _add(BuildContext context)async{
    final item=TextEditingController(),supplier=TextEditingController(),qty=TextEditingController(text:'1'),price=TextEditingController();
    final ok=await showDialog<bool>(context:context,builder:(d)=>AlertDialog(title:const Text('Record business purchase'),content:SingleChildScrollView(child:Column(children:[TextField(controller:item,decoration:const InputDecoration(labelText:'Item')),TextField(controller:supplier,decoration:const InputDecoration(labelText:'Supplier')),TextField(controller:qty,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Quantity')),TextField(controller:price,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Unit cost'))])),actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(d,true),child:const Text('Save'))]));
    if(ok==true&&item.text.trim().isNotEmpty)await FirebaseFirestore.instance.collection('businessPurchases').add({'item':item.text.trim(),'supplier':supplier.text.trim(),'quantity':double.tryParse(qty.text)??1,'unitCost':double.tryParse(price.text)??0,'createdBy':adminUid,'createdAt':FieldValue.serverTimestamp()});
  }
  @override Widget build(BuildContext context)=>StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(stream:FirebaseFirestore.instance.collection('businessPurchases').limit(200).snapshots(),builder:(c,s){
    if(!s.hasData)return const Center(child:CircularProgressIndicator());return ListView(padding:const EdgeInsets.all(16),children:[Row(children:[const Expanded(child:Text('Business Purchases',style:TextStyle(fontSize:22,fontWeight:FontWeight.w900))),FilledButton.icon(onPressed:()=>_add(context),icon:const Icon(Icons.add),label:const Text('Record'))]),const SizedBox(height:10),...s.data!.docs.map((d){final x=d.data();final total=(x['quantity'] is num&&x['unitCost'] is num)?(x['quantity'] as num)*(x['unitCost'] as num):0;return Card(child:ListTile(title:Text((x['item']??'Item').toString()),subtitle:Text((x['supplier']??'').toString()),trailing:Text('₹'+total.toStringAsFixed(0),style:const TextStyle(fontWeight:FontWeight.w900))));})]);
  });
}

class _GlobalSearch extends StatefulWidget{final Color accent;const _GlobalSearch(this.accent);@override State<_GlobalSearch> createState()=>_GlobalSearchState();}
class _GlobalSearchState extends State<_GlobalSearch>{
  final q=TextEditingController();String term='';
  @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(16),children:[TextField(controller:q,decoration:InputDecoration(labelText:'Search customer, order or ride',suffixIcon:IconButton(icon:const Icon(Icons.search),onPressed:()=>setState(()=>term=q.text.trim()))),onSubmitted:(v)=>setState(()=>term=v.trim())),const SizedBox(height:12),if(term.isNotEmpty)_results()]);
  Widget _results() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('orders').limit(500).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const CircularProgressIndicator();
        final termLower = term.toLowerCase();
        final docs = snap.data!.docs.where((doc) {
          final data = doc.data();
          return doc.id.toLowerCase().contains(termLower) ||
              (data['customerName'] ?? '').toString().toLowerCase().contains(termLower) ||
              (data['customerId'] ?? '').toString().toLowerCase().contains(termLower);
        }).take(30).toList();
        final widgets = <Widget>[];
        for (final doc in docs) {
          final data = doc.data();
          widgets.add(Card(
            child: ListTile(
              title: Text('#' + doc.id),
              subtitle: Text((data['customerName'] ?? 'Customer').toString() + ' • ' + (data['status'] ?? '').toString()),
            ),
          ));
        }
        return Column(children: widgets);
      },
    );
  }
}
