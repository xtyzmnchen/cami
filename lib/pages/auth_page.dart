import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final server = TextEditingController();
  final token = TextEditingController(text: 'cami-home');
  final phone = TextEditingController();
  final password = TextEditingController();
  final name = TextEditingController();
  final age = TextEditingController();
  final interests = TextEditingController();

  var step = 0; // 0 地址+手机 1 登录 2 注册
  var busy = false;
  String? error;
  String grade = '二年级';
  final interestChips = ['画画', '阅读', '运动', '音乐', '乐高', '英语'];
  final selectedInterests = <String>{};

  @override
  void initState() {
    super.initState();
    final store = context.read<Store>();
    server.text = store.serverUrl;
    token.text = store.serverToken;
  }

  @override
  void dispose() {
    server.dispose();
    token.dispose();
    phone.dispose();
    password.dispose();
    name.dispose();
    age.dispose();
    interests.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    setState(() {
      busy = true;
      error = null;
    });
    final store = context.read<Store>();
    try {
      await store.setServer(server.text, token.text);
      final exists = await store.checkPhoneExists(phone.text);
      if (!mounted) return;
      setState(() => step = exists ? 1 : 2);
    } catch (e) {
      if (!mounted) return;
      setState(() => error = '$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _login() async {
    setState(() {
      busy = true;
      error = null;
    });
    final err = await context.read<Store>().login(rawPhone: phone.text, password: password.text);
    if (!mounted) return;
    setState(() {
      busy = false;
      error = err;
    });
  }

  Future<void> _register() async {
    setState(() {
      busy = true;
      error = null;
    });
    final merged = {
      ...selectedInterests,
      if (interests.text.trim().isNotEmpty) interests.text.trim(),
    }.join('、');
    final err = await context.read<Store>().register(
          rawPhone: phone.text,
          password: password.text,
          name: name.text,
          age: int.tryParse(age.text.trim()) ?? 0,
          grade: grade,
          interests: merged,
        );
    if (!mounted) return;
    setState(() {
      busy = false;
      error = err;
    });
  }

  @override
  Widget build(BuildContext context) {
    return RoseBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            children: [
              const Text('萱萱小皇冠', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(
                step == 0
                    ? '用手机号登录，每个人的作业分开存'
                    : step == 1
                        ? '欢迎回来，输入密码'
                        : '新号码，填写孩子资料完成注册',
                style: const TextStyle(color: CamiColors.muted, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 20),
              if (step == 0) ...[
                GlassPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: server,
                        decoration: const InputDecoration(
                          labelText: '同步电脑地址',
                          hintText: 'https://xxxx.cpolar.top',
                        ),
                      ),
                      TextField(
                        controller: token,
                        decoration: const InputDecoration(labelText: '同步口令'),
                      ),
                      TextField(
                        controller: phone,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        maxLength: 11,
                        decoration: const InputDecoration(labelText: '手机号'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                RoseButton(label: busy ? '查询中…' : '下一步', onPressed: busy ? null : _next),
              ],
              if (step == 1) ...[
                GlassPanel(
                  child: Column(
                    children: [
                      Text('手机号 ${phone.text}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      TextField(
                        controller: password,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: '密码'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                RoseButton(label: busy ? '登录中…' : '登录', onPressed: busy ? null : _login),
                TextButton(
                  onPressed: busy ? null : () => setState(() => step = 0),
                  child: const Text('换一个手机号'),
                ),
              ],
              if (step == 2) ...[
                GlassPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('注册 ${phone.text}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      TextField(controller: name, decoration: const InputDecoration(labelText: '孩子的名字')),
                      TextField(
                        controller: age,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(labelText: '年龄'),
                      ),
                      const SizedBox(height: 8),
                      const Text('年级', style: TextStyle(color: CamiColors.muted)),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final g in ['一年级', '二年级', '三年级', '四年级', '五年级', '六年级'])
                            ChoiceChip(
                              label: Text(g),
                              selected: grade == g,
                              onSelected: (_) => setState(() => grade = g),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text('兴趣', style: TextStyle(color: CamiColors.muted)),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final item in interestChips)
                            FilterChip(
                              label: Text(item),
                              selected: selectedInterests.contains(item),
                              onSelected: (on) => setState(() {
                                if (on) {
                                  selectedInterests.add(item);
                                } else {
                                  selectedInterests.remove(item);
                                }
                              }),
                            ),
                        ],
                      ),
                      TextField(controller: interests, decoration: const InputDecoration(labelText: '其他兴趣（可空）')),
                      TextField(
                        controller: password,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: '设置密码（至少 4 位）'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                RoseButton(label: busy ? '注册中…' : '注册并进入', onPressed: busy ? null : _register),
                TextButton(
                  onPressed: busy ? null : () => setState(() => step = 0),
                  child: const Text('返回'),
                ),
              ],
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(error!, style: const TextStyle(color: CamiColors.red, fontWeight: FontWeight.w700)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
