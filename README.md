# 小皇冠（cami）

二年级每日打卡：作业、积分、兑换、家长批改，支持手机与 Web。

## 免费 Web 版

**https://xtyzmnchen.github.io/cami/**

## 电脑端：一键启动（推荐）

需要本机已有：

- Flutter / Dart（或 fvm）
- 已登录的 cpolar（默认 `~/cpolar`）
- 能 `git push` 到本仓库（用来发布最新同步地址）

在项目根目录执行：

```bash
chmod +x tool/*.sh
tool/watch_sync.sh
```

推荐用守护模式（`watch_sync.sh`），它会：

1. 启动本地同步服务 `tool/server.dart`（端口 **8787**，口令 **cami-home**）
2. 启动 cpolar 公网隧道并推送到 GitHub
3. **持续监听**：公网 health 连续失败时自动重启 cpolar，并再次推送新地址

只要开一次、保持终端即可。结束：

```bash
tool/stop_all.sh
```

也可以用前台一次性启动（不自动重连）：

```bash
tool/start_all.sh
```

### 分开启动（可选）

```bash
# 终端 1：只开本地同步
dart run tool/server.dart

# 终端 2：只开隧道并推送地址
tool/start_cpolar.sh
```

只更新 GitHub 上的地址、不重启隧道：

```bash
tool/publish_sync_url.sh https://你的新地址.r6.cpolar.cn
```

## 同步地址自动发现

免费 cpolar 域名会变。电脑端发布到：

[`web/sync-endpoint.json`](web/sync-endpoint.json)

手机 App 同步失败 / 打开登录页时会按顺序拉取（**不以 jsDelivr `@main` 为准**，它有 CDN 延迟）：

1. GitHub Contents API（即时，无 CDN 缓存）
2. jsDelivr **按 commit sha**（国内快，且不会吃到旧 `@main`）
3. raw.githubusercontent.com
4. GitHub Pages
5. jsDelivr `@main`（仅兜底）

家长设置里也可手动点「从云端刷新同步地址」。

> 若要永久固定域名，可升级 cpolar 保留域名。

## 本地开发 App

```bash
flutter pub get
flutter run
```
