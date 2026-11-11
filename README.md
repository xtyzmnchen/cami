# 小皇冠（cami）

二年级每日打卡：作业、积分、兑换、家长批改，支持手机与 Web。

## 免费 Web 版（GitHub Pages）

发布后访问：

**https://xtyzmnchen.github.io/cami/**

手机浏览器打开即可。家长设置里仍需填写同步电脑地址（`dart run tool/server.dart` + cpolar），才能和家里数据互通。

## 同步地址自动发现（推荐）

免费 cpolar 每次重启公网域名都会变。做法是：

1. 电脑端启动隧道后，把最新地址写进 GitHub 仓库文件  
   [`web/sync-endpoint.json`](web/sync-endpoint.json)
2. 手机 App 同步失败时，自动去 GitHub 拉这个文件并替换本地同步地址

发现接口（固定不变，App 会按顺序尝试）：

- https://cdn.jsdelivr.net/gh/xtyzmnchen/cami@main/web/sync-endpoint.json（国内优先）
- https://raw.githubusercontent.com/xtyzmnchen/cami/main/web/sync-endpoint.json
- https://xtyzmnchen.github.io/cami/sync-endpoint.json（Pages 部署后可用）

### 电脑一键启动

先开同步服务，再开隧道（会自动推送地址到 GitHub）：

```bash
# 终端 1
dart run tool/server.dart

# 终端 2（需要本机已登录 git / gh，能 push）
chmod +x tool/start_cpolar.sh tool/publish_sync_url.sh
tool/start_cpolar.sh
```

只更新地址、不重启隧道：

```bash
tool/publish_sync_url.sh https://你的新地址.r6.cpolar.cn
```

家长设置里也可手动点「从云端刷新同步地址」。

> 若要永久固定域名，可升级 cpolar 保留域名；上面这套发现机制是免费替代方案。

## 本地开发

```bash
flutter pub get
flutter run
```

## 同步服务（电脑）

```bash
dart run tool/server.dart
# 默认端口 8787，口令 cami-home
```
