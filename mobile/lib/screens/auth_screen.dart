import 'package:flutter/material.dart';
import '../services/auth_api.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.onAuthenticated});
  final VoidCallback onAuthenticated;
  @override State<AuthScreen> createState() => _AuthScreenState();
}
class _AuthScreenState extends State<AuthScreen> {
  final email = TextEditingController(), password = TextEditingController(), confirm = TextEditingController();
  final uid = TextEditingController(), token = TextEditingController(), code = TextEditingController();
  String mode = 'login', notice = '';
  bool busy = false, showPassword = false;
  @override void initState() {
    super.initState();
    final url = Uri.base;
    final action = url.pathSegments.isEmpty ? '' : url.pathSegments.last;
    if (action == 'verify-email' || action == 'reset-password') {
      mode = action == 'verify-email' ? 'verify' : 'reset';
      uid.text = url.queryParameters['uid'] ?? '';
      token.text = url.queryParameters['token'] ?? '';
    }
  }
  @override void dispose() { for (final c in [email,password,confirm,uid,token,code]) { c.dispose(); } super.dispose(); }
  bool get passwordValid => password.text.length >= 10 && RegExp(r'[A-Z]').hasMatch(password.text) && RegExp(r'[a-z]').hasMatch(password.text) && RegExp(r'[0-9]').hasMatch(password.text) && RegExp(r'[^A-Za-z0-9]').hasMatch(password.text);
  void switchTo(String next) => setState(() { mode=next; notice=''; password.clear(); confirm.clear(); });
  Future<void> submit() async {
    if (busy) return;
    if ((mode=='register' || mode=='reset') && !passwordValid) {setState(()=>notice='Use 10+ characters with uppercase, lowercase, a number and a symbol.');return;}
    if ((mode=='register'||mode=='reset') && password.text!=confirm.text) {setState(()=>notice='Passwords do not match.');return;}
    setState(() {busy=true;notice='';});
    try {
      String message='';
      switch (mode) {
        case 'login': await AuthApi.login(email.text.trim(),password.text); if(mounted)widget.onAuthenticated(); return;
        case 'register': message=await AuthApi.register(email.text.trim(),password.text); break;
        case 'verify': message=await AuthApi.verifyCode(email.text.trim(),code.text.trim()); break;
        case 'resend': message=await AuthApi.resend(email.text.trim()); break;
        case 'forgot': message=await AuthApi.resetRequest(email.text.trim()); break;
        case 'reset': message=await AuthApi.resetConfirm(uid.text.trim(),token.text.trim(),password.text); break;
      }
      if (mounted) setState(() {notice=message; if(mode=='register') {mode='verify';} else if(mode=='reset'||mode=='verify') {mode='login';}});
    } catch(e) {if(mounted)setState(()=>notice=e.toString().replaceFirst('Exception: ',''));}
    finally {if(mounted)setState(()=>busy=false);}
  }
  Widget field(TextEditingController controller, String label, {bool secret=false,TextInputType? keyboard}) => Padding(padding:const EdgeInsets.only(bottom:14),child:TextField(controller:controller,keyboardType:keyboard,obscureText:secret&&!showPassword,onChanged:(_)=>setState((){}),decoration:InputDecoration(labelText:label,border:OutlineInputBorder(borderRadius:BorderRadius.circular(16)),filled:true,fillColor:const Color(0xFF29243B))));
  @override Widget build(BuildContext context) {
    final registration=mode=='register', login=mode=='login', reset=mode=='reset';
    final needsEmail=login||registration||mode=='resend'||mode=='forgot';
    final needsToken=reset;
    final title={'login':'Welcome back','register':'Create your account','verify':'Verify your email','resend':'Resend verification','forgot':'Forgot password?','reset':'Choose a new password'}[mode]!;
    final subtitle={'login':'Continue your academic journey.','register':'Build better study habits with CampusOS.','verify':'Enter the 6-digit code we sent to your email.','resend':'We will send a fresh six-digit code.','forgot':'We will send you a password reset link.','reset':'Secure your account with a new password.'}[mode]!;
    return Scaffold(backgroundColor:const Color(0xFF14111F),body:SafeArea(child:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:460),child:SingleChildScrollView(padding:const EdgeInsets.symmetric(horizontal:26,vertical:35),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      const Image(image: AssetImage('assets/branding/campusos_icon_transparent.png'),height:74,fit:BoxFit.contain),
      const SizedBox(height:10),const Text('CampusOS',textAlign:TextAlign.center,style:TextStyle(fontSize:32,fontWeight:FontWeight.w800,color:Colors.white)),
      const SizedBox(height:6),const Text("Don't just read. Remember what you study.",textAlign:TextAlign.center,style:TextStyle(color:Color(0xFFBAB3CE))),
      const SizedBox(height:44),Text(title,style:const TextStyle(fontSize:26,fontWeight:FontWeight.w700,color:Colors.white)),
      const SizedBox(height:6),Text(subtitle,style:const TextStyle(color:Color(0xFFBAB3CE))),const SizedBox(height:28),
      if(needsEmail||mode=='verify')field(email,'Email address',keyboard:TextInputType.emailAddress),
      if(mode=='verify')field(code,'6-digit verification code',keyboard:TextInputType.number),
      if(needsToken)...[field(uid,'Verification UID'),field(token,'Verification token')],
      if(login||registration||reset)field(password,reset?'New password':'Password',secret:true),
      if(registration||reset)...[field(confirm,'Confirm password',secret:true),
        Text(passwordValid?'Password requirements satisfied':'10+ characters · uppercase · lowercase · number · symbol',style:TextStyle(fontSize:12,color:passwordValid?const Color(0xFF91E0B5):const Color(0xFFC6B9D9))),const SizedBox(height:12)],
      if(login)Align(alignment:Alignment.centerRight,child:TextButton(onPressed:()=>switchTo('forgot'),child:const Text('Forgot password?'))),
      if(registration||reset)CheckboxListTile(contentPadding:EdgeInsets.zero,controlAffinity:ListTileControlAffinity.leading,title:const Text('Show passwords',style:TextStyle(fontSize:13)),value:showPassword,onChanged:(v)=>setState(()=>showPassword=v??false)),
      const SizedBox(height:12),SizedBox(height:54,child:FilledButton(onPressed:busy?null:submit,style:FilledButton.styleFrom(backgroundColor:const Color(0xFFC5A5FF),foregroundColor:const Color(0xFF1D1331),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16))),child:Text(busy?'Please wait…':{'login':'Log in','register':'Create account','verify':'Verify email','resend':'Resend email','forgot':'Send reset link','reset':'Reset password'}[mode]!,style:const TextStyle(fontWeight:FontWeight.bold,fontSize:16)))),
      if(notice.isNotEmpty)Padding(padding:const EdgeInsets.only(top:16),child:SelectableText(notice,style:const TextStyle(color:Color(0xFFFFC7A7)))),
      const SizedBox(height:20),if(login)Center(child:TextButton(onPressed:()=>switchTo('register'),child:const Text('New to CampusOS? Create an account'))),
      if(registration)Center(child:TextButton(onPressed:()=>switchTo('login'),child:const Text('Already registered? Log in'))),
      if(!login&&!registration)Center(child:TextButton(onPressed:()=>switchTo('login'),child:const Text('Back to login'))),
      if(mode=='verify')Center(child:TextButton(onPressed:()=>switchTo('resend'),child:const Text('Resend verification email'))),
      if(reset)const Padding(padding:EdgeInsets.only(top:12),child:Text('Password reset links are sent to your email.',textAlign:TextAlign.center,style:TextStyle(color:Color(0xFFBAB3CE),fontSize:12))),
    ]))))));
  }
}
