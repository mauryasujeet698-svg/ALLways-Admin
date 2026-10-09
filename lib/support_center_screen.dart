import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminSupportCenterScreen extends StatefulWidget {
  final String role;
  final Color accent;
  final String adminUid;
  const AdminSupportCenterScreen({super.key, required this.role, required this.accent, required this.adminUid});
  @override State<AdminSupportCenterScreen> createState() => _AdminSupportCenterScreenState();
}

class _AdminSupportCenterScreenState extends State<AdminSupportCenterScreen> {
  String queue = 'Customer Support';
  String status = 'open';
  String area = 'all';
  String search = '';
  final searchController = TextEditingController();
  @override void dispose(){searchController.dispose();super.dispose();}
  Stream<QuerySnapshot<Map<String, dynamic>>> _stream() {
    final tickets = FirebaseFirestore.instance.collection('supportTickets');
    if (queue == 'Service Support') {
      // Include older delivery tickets created before the queue name was normalized.
      return tickets.where('queue', whereIn: const ['Service Support', 'Delivery Service Support']).limit(100).snapshots();
    }
    return tickets.where('queue', isEqualTo: queue).limit(100).snapshots();
  }
  Future<void> _edit(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final d = doc.data() ?? {};
    String s = (d['status'] ?? 'open').toString();
    String p = (d['priority'] ?? 'normal').toString();
    final note = TextEditingController();
    final reply = TextEditingController(text: (d['adminReply'] ?? '').toString());
    await showModalBottomSheet(context: context, isScrollControlled: true, showDragHandle: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) => SafeArea(child: Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text((d['subject'] ?? 'Support request').toString(), style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
          const SizedBox(height: 5), Text('Ticket #${doc.id}'),
          const SizedBox(height: 12), Text('Category: ${d['category'] ?? 'General'} / ${d['subcategory'] ?? ''}'),
          Text('Requester: ${d['customerName'] ?? d['requesterName'] ?? d['requesterId'] ?? 'Unknown'}'),
          if ((d['orderId'] ?? '').toString().isNotEmpty) Text('Order: ${d['orderId']}'),
          if ((d['rideId'] ?? '').toString().isNotEmpty) Text('Ride: ${d['rideId']}'),
          const SizedBox(height: 8), Text((d['message'] ?? '').toString()),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(value: p, decoration: const InputDecoration(labelText: 'Priority'),
            items: const [DropdownMenuItem(value:'normal',child:Text('Normal')),DropdownMenuItem(value:'high',child:Text('High')),DropdownMenuItem(value:'urgent',child:Text('Urgent'))],
            onChanged:(v)=>setSheet(()=>p=v??p)),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(value: s, decoration: const InputDecoration(labelText: 'Status'),
            items: const [DropdownMenuItem(value:'open',child:Text('Open')),DropdownMenuItem(value:'assigned',child:Text('Assigned')),DropdownMenuItem(value:'waiting_customer',child:Text('Waiting for customer')),DropdownMenuItem(value:'resolved',child:Text('Resolved')),DropdownMenuItem(value:'closed',child:Text('Closed')),DropdownMenuItem(value:'escalated',child:Text('Escalated'))],
            onChanged:(v)=>setSheet(()=>s=v??s)),
          const SizedBox(height: 10),
          TextField(controller: reply, maxLines: 4, decoration: const InputDecoration(labelText:'Reply to requester')),
          const SizedBox(height: 10),
          TextField(controller: note, maxLines: 3, decoration: const InputDecoration(labelText:'Internal note')),
          const SizedBox(height: 12),
          SizedBox(width:double.infinity,child:FilledButton(
            style:FilledButton.styleFrom(backgroundColor:widget.accent),
            onPressed:() async {
              final patch=<String,dynamic>{'status':s,'priority':p,'updatedAt':FieldValue.serverTimestamp(),'updatedBy':widget.adminUid};
              if(note.text.trim().isNotEmpty)patch['lastAdminNote']=note.text.trim();
              if(reply.text.trim().isNotEmpty) { patch['adminReply']=reply.text.trim(); patch['lastAdminReplyAt']=FieldValue.serverTimestamp(); patch['lastAdminReplyBy']=widget.adminUid; }
              await doc.reference.update(patch);
              if(ctx.mounted)Navigator.pop(ctx);
            }, child:const Text('Save ticket'))),
        ]))))));
  }

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Support Center')),
    body: Column(children:[
      Padding(padding:const EdgeInsets.fromLTRB(16,12,16,8),child:SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[
        ChoiceChip(label:const Text('Customer Support'),selected:queue=='Customer Support',onSelected:(_)=>setState(()=>queue='Customer Support')),
        const SizedBox(width:8),
        ChoiceChip(label:const Text('Service Support'),selected:queue=='Service Support',onSelected:(_)=>setState(()=>queue='Service Support')),
        const SizedBox(width:8),
        for(final x in const ['Item','Ride','General']) ...[
          const SizedBox(width:8),
          ChoiceChip(label:Text(x),selected:area==x,onSelected:(_)=>setState(()=>area=area==x?'all':x)),
        ],
      ]))),
      Padding(padding:const EdgeInsets.fromLTRB(16,0,16,10),child:TextField(controller:searchController,decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'Search ticket, customer, ride or order',border:OutlineInputBorder()),onChanged:(v)=>setState(()=>search=v.trim().toLowerCase()))),
      Padding(padding:const EdgeInsets.fromLTRB(16,0,16,10),child:SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[
        for(final x in const ['open','assigned','waiting_customer','resolved','closed','escalated','all'])
          Padding(padding:const EdgeInsets.only(right:6),child:ChoiceChip(label:Text(x.replaceAll('_',' ')),selected:status==x,onSelected:(_)=>setState(()=>status=x))),
      ]))),
      Expanded(child:StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
        stream:_stream(),builder:(context,snap){
          if(snap.hasError)return Center(child:Text('Support query failed: ${snap.error}'));
          if(!snap.hasData)return const Center(child:CircularProgressIndicator());
          final docs=snap.data!.docs.where((d){final x=d.data();final s=(x['status']??'open').toString();final raw=(x['area']??x['category']??'General').toString();final a=raw=='Order'?'Item':raw=='Account'?'General':raw;final hay=[x['subject'],x['message'],x['customerName'],x['customerEmail'],x['rideId'],x['orderId'],x['subcategory']].map((v)=>(v??'').toString().toLowerCase()).join(' ');return (status=='all'||s==status)&&(area=='all'||a==area)&&(search.isEmpty||hay.contains(search));}).toList();
          if(docs.isEmpty)return const Center(child:Text('No support tickets in this queue.'));
          return ListView.builder(padding:const EdgeInsets.all(16),itemCount:docs.length,itemBuilder:(_,i){
            final d=docs[i],x=d.data(),p=(x['priority']??'normal').toString();
            return Card(elevation:0,child:ListTile(onTap:()=>_edit(d),
              leading:CircleAvatar(backgroundColor:widget.accent.withOpacity(.1),child:Icon(p=='urgent'?Icons.priority_high:Icons.support_agent,color:widget.accent)),
              title:Text((x['subject']??'Support request').toString(),style:const TextStyle(fontWeight:FontWeight.w800)),
              subtitle:Text('${x['category']??'General'} • ${x['requesterRole']??'customer'} • ${x['status']??'open'}'),
              trailing:Text(p.toUpperCase(),style:TextStyle(fontSize:10,fontWeight:FontWeight.w900,color:p=='urgent'?Colors.red:widget.accent))));
          });
        },
      )),
    ]),
  );
}
