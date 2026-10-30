# 小皇冠（cami）

二年级每日打卡：作业、积分、兑换、家长批改，支持手机与 Web。

## 免费 Web 版（GitHub Pages）

发布后访问：

**https://xtyzmnchen.github.io/cami/**

手机浏览器打开即可。家长设置里仍需填写同步电脑地址（`dart run tool/server.dart` + cpolar），才能和家里数据互通。

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

再用 cpolar 映射 `8787`，把公网地址填进 App / Web 的家长设置。
