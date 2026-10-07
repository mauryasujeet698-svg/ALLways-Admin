import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminAnalyticsScreen extends StatelessWidget {
  final Color accent;
  const AdminAnalyticsScreen({super.key,required this.accent});
  double n(dynamic v)=>v is num?v.toDouble():double.tryParse((v??'').toString())??0;
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Reports & Analytics')),
    body:StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(stream:FirebaseFirestore.instance.collection('orders').snapshots(),builder:(c,os)=>
      StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(stream:FirebaseFirestore.instance.collection('autoRideRequests').snapshots(),builder:(c,rs)=>
        StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(stream:FirebaseFirestore.instance.collection('customers').snapshots(),builder:(c,cs){
          if(!os.hasData||!rs.hasData||!cs.hasData)return const Center(child:CircularProgressIndicator());
          final orders=os.data!.docs.map((d)=>d.data()).toList(),rides=rs.data!.docs.map((d)=>d.data()).toList();
          final counts=<String,int>{};for(final o in orders){final id=(o['customerId']??o['uid']??o['userId']??'').toString();if(id.isNotEmpty)counts[id]=(counts[id]??0)+1;}
          final completed=orders.where((o)=>{'delivered','completed'}.contains((o['status']??'').toString().toLowerCase())).toList();
          final cancelled=orders.where((o)=>(o['status']??'').toString().toLowerCase()=='cancelled').length;
          final revenue=completed.fold<double>(0,(s,o)=>s+n(o['total']));
          final repeat=counts.values.where((x)=>x>=2).length;
          final top=counts.entries.toList()..sort((a,b)=>b.value.compareTo(a.value));
          final active=rides.where((r)=>{'searching','accepted','arrived','started'}.contains((r['status']??'').toString().toLowerCase())).length;
          return ListView(padding:const EdgeInsets.all(16),children:[
            Row(children:[_m(completed.length.toString(),'Completed orders',Icons.check_circle),const SizedBox(width:8),_m('₹${revenue.toStringAsFixed(0)}','Completed value',Icons.currency_rupee)]),
            const SizedBox(height:8),Row(children:[_m(repeat.toString(),'Repeat customers',Icons.repeat),const SizedBox(width:8),_m(active.toString(),'Active rides',Icons.two_wheeler)]),
            const SizedBox(height:14),
            Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              const Text('Customer behaviour',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900)),const SizedBox(height:8),
              Text('Registered customers: ${cs.data!.docs.length}'),Text('Customers with 2+ orders: ${repeat}'),
              Text('Cancellation rate: ' + (orders.isEmpty ? '0' : (cancelled * 100 / orders.length).toStringAsFixed(1)) + '%'),
              Text('Average completed order value: ' + (completed.isEmpty ? '₹0' : '₹' + (revenue / completed.length).toStringAsFixed(0))),
            ]))),
            const SizedBox(height:10),
            Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              const Text('Most active customers',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900)),const SizedBox(height:5),
              if(top.isEmpty)const Text('No order history yet.') else ...top.take(10).map((e)=>ListTile(dense:true,contentPadding:EdgeInsets.zero,leading:CircleAvatar(backgroundColor:accent.withOpacity(.1),child:Text(e.value.toString())),title:Text(e.key),subtitle:Text('${e.value} orders'))),
            ]))),
            const SizedBox(height:10),
            Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              const Text('Ride activity',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900)),const SizedBox(height:5),
              Text('Total ride requests: ${rides.length}'),Text('Active rides: ${active}'),
              Text('Completed rides: ${rides.where((r)=>(r['status']??'').toString().toLowerCase()=='completed').length}'),
              Text('Cancelled rides: ${rides.where((r)=>(r['status']??'').toString().toLowerCase()=='cancelled').length}'),
            ]))),
          ]);
        })));
  Widget _m(String v,String l,IconData i)=>Expanded(child:Card(elevation:0,child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(i,color:accent),const SizedBox(height:5),Text(v,style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900)),Text(l,style:const TextStyle(fontSize:10,color:Colors.grey))]))));
}
