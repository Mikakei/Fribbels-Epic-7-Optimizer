# 维护说明

这份文档写给想从源码运行、修改或发布这个维护版本的人。只想使用配装器的玩家，请到 [Releases](https://github.com/Mikakei/Fribbels-Epic-7-Optimizer/releases) 下载压缩包，使用方法见 [中文 README](README.zh-CN.md)。

本仓库是 [fribbels/Fribbels-Epic-7-Optimizer](https://github.com/fribbels/Fribbels-Epic-7-Optimizer) 的维护版本，所有改动都在 `maintenance` 分支上，基于原仓库 main 的 2026-10-12 版本（#263）。

## 为什么要维护

原仓库最后一个正式版是 v1.10.0（2025-09-12）。之后社区贡献者陆续把新套装写进了源码，但一直没人重新编译后端，也没有发布新版本：

- 战意 Warfare、追击 Pursuit（2026-01，#242）
- 弱化 Weakening、热忱 Fervor（2026-06，#256）

结果是 v1.10.0 用不了这 4 个套装。直接用原仓库的 main 也不行：前端认识这些套装，但仓库里的 `data/jar/backend.jar` 还是旧的。

## 和原版的区别

**修复**

| 改动 | 文件 |
|---|---|
| 用当前源码重新编译 `backend.jar`，4 个新套装能参与计算 | `data/jar/backend.jar` |
| pom 增加打包配置，`mvn package` 直接产出可用的 `backend.jar` | `backend/pom.xml` |
| 删掉写死的 `global.TEST = true`。有这一行时，程序只读自带的数据，不从服务器拉取最新的英雄和神器数据 | `app/js/lib/heroData.js` |
| 数据兜底：服务器连不上，或者服务器上的数据比 GitHub 上的旧超过 10 分钟时，改用 GitHub 上的数据 | `app/js/lib/heroData.js` |
| 修复：在装备页删除已穿戴的装备后，再删除、卸下或锁定该英雄时后端报错（NullPointerException） | `backend/.../ItemsRequestHandler.java`、`HeroesRequestHandler.java` |
| 修复：界面翻译偶尔整页不生效、显示英文。原因是一个元素出错会中断整个翻译过程（`tmpText.push` 写错，且没有逐个元素的错误处理） | `app/js/lib/i18n/i18n.js` |

**更新和发布**

| 改动 | 文件 |
|---|---|
| 关闭原版的自动更新，避免维护版被官方版本覆盖。"检查更新"改为：便携版查询本仓库的 Releases；源码版运行更新脚本 | `app/main.dev.js` |
| 便携压缩包：自带 Java 8 运行环境，玩家不需要另外安装 Java | `scripts/package-release.ps1` |
| 一键更新脚本：合并原仓库的更新，并按需重新编译 | `scripts/update-optimizer.ps1` |
| 版本号 1.11.0 | `app/package.json`、`app/js/lib/updater.js` |

**界面和工具**

| 改动 | 文件 |
|---|---|
| 去掉 Donate、Discord 选项卡和赞助图标；"信息"页改为维护说明，附原项目和 Discord 链接，感谢原作者，保留并重新整理原有致谢 | `app/app.html`、`data/locales/zh*/translation.json` |
| 窗口标题显示版本号；新增"工具"菜单：检查更新、检测导入环境、加速器网络诊断 | `app/main.dev.js` |
| 导入环境检测、加速器网络诊断，以及给玩家用的诊断包 | `data/py/check_importer.py`、`data/py/diagnose_capture.py`、`tools/` |
| 中文 README | `README.zh-CN.md` |
| 去掉用不到的 node-sass（项目里没有 .scss，而且 4.x 无法在 Node 16 上安装） | `package.json`、`yarn.lock` |

## 已验证

- 程序启动后会联网拉取英雄和神器数据，共 391 个英雄、288 个神器，包括 Mei Lin、Haru、Renoa、Lisette、Aube 和神器 Flame Dragon's Jewel。
- 弱化 4 件套：Mei Lin 基础速度 121，套装加速度 +18，正好是 15%。
- 实际跑了一次优化（12 件装备、64 种组合）：带 4 件及以上战意的组合生命 +1036，等于基础生命 5178 的 20%；追击套的件数统计也正确。
- 先删除已穿戴的装备、再删除英雄，现在可以正常完成。
- 数据兜底：模拟了四种情况（正常、服务器数据过期、服务器连不上、GitHub API 返回 403），每种都能加载到全部英雄。
- 便携压缩包：解压到包含中文和空格的路径、电脑上没有安装 Java 时，能正常启动，后端用的是包内的 Java；连续 4 次全新解压后首次启动，界面都是中文。
- 自动导入：维护者在 MuMu 模拟器上实测，成功读取到数据。

**没有验证：** 导入后 4 个新套装的名称是否正确；STOVE 官方 PC 客户端能否导入。

## 从源码运行

只支持 64 位 Windows 10/11。需要先装好 Git。

### 1. 获取代码

```bash
git clone -b maintenance https://github.com/Mikakei/Fribbels-Epic-7-Optimizer.git
```

### 2. 准备工具链

工具都放在仓库里的 `.toolchain\` 文件夹，不需要装到系统里，这个文件夹也不进 git。脚本按下面的文件夹名查找工具，请保持一致：

| 工具 | 解压后的文件夹 | 下载 |
|---|---|---|
| Eclipse Temurin JDK 8u504-b01（x64 zip） | `.toolchain\jdk8u504-b01` | [Adoptium](https://github.com/adoptium/temurin8-binaries/releases/tag/jdk8u504-b01) |
| Apache Maven 3.9.9 | `.toolchain\apache-maven-3.9.9` | [apache.org](https://archive.apache.org/dist/maven/maven-3/3.9.9/binaries/) |
| Node.js 16.20.2（win-x64 zip） | `.toolchain\node-v16.20.2-win-x64` | [nodejs.org](https://nodejs.org/dist/v16.20.2/) |

必须用 Node 16：这是 Electron 16 的老项目，用新版 Node 编译不了。下载后请用官方提供的 SHA256/SHA512 校验值核对。

然后把 yarn 装进便携版 Node，并安装依赖、编译前端：

```powershell
$env:PATH = "$PWD\.toolchain\node-v16.20.2-win-x64;$env:PATH"
npm install -g yarn@1.22.22
yarn install
yarn build
```

`data\jar\backend.jar` 已经提交在仓库里，只有改了 `backend\` 的代码才需要重新编译，见"[跟进原仓库](#跟进原仓库)"一节。

### 3. 启动

```powershell
powershell -ExecutionPolicy Bypass -File scripts\create-shortcuts.ps1
```

这个命令会在仓库根目录生成三个快捷方式：**Fribbels 配装器**、**更新配装器**、**检测导入环境**。加上 `-Desktop`、`-StartMenu` 参数，会同时放到桌面和开始菜单。快捷方式里是本机的绝对路径，所以不进 git，挪动文件夹后要重新生成。

也可以直接运行 `scripts\start-optimizer.cmd`。

程序启动时会自己准备运行环境：
- 把 `.toolchain\jdk*\bin` 加进 PATH，不需要系统里装 Java；
- 如果有 `.toolchain\python-version` 这个文件（内容例如 `3.14`），会用它设置 `PY_PYTHON`，让自动导入固定使用这个版本的 Python。电脑上装了 Python 预览版时，`py` 默认可能会选中预览版，这时就用得上。

存档在 `文档\FribbelsOptimizerSaves\`，和官方版本共用。

## 入口和工具

程序菜单栏的 **工具**：

| 菜单项 | 源码版 | 便携版 |
|---|---|---|
| 检查更新… | 确认后关闭配装器，运行更新脚本，完成后自动重新打开 | 查询本仓库最新的 Release，有新版本时打开下载页面 |
| 检测导入环境 | 运行 `scripts\check-importer.cmd` | 同左 |
| 加速器网络诊断 | 运行 `scripts\diagnose-importer.cmd` | 同左 |
| 打开维护说明 / 使用说明 | 打开本文件 | 打开 GitHub 上的中文 README |
| 打开程序文件夹 | ✓ | ✓ |

"信息"页的"检查更新"按钮和菜单走同一个流程。

`scripts\` 里的脚本：

| 脚本 | 作用 |
|---|---|
| `start-optimizer.cmd` | 启动源码版 |
| `update-optimizer.cmd` / `.ps1` | 合并原仓库的更新并按需重新编译 |
| `check-importer.cmd` | 检测自动导入环境 |
| `diagnose-importer.cmd` | 加速器网络诊断 |
| `create-shortcuts.ps1` | 生成快捷方式 |
| `package-release.ps1` | 打包便携压缩包 |

## 打包发布

```powershell
powershell -ExecutionPolicy Bypass -File scripts\package-release.ps1
```

脚本会依次完成：
1. 运行 `yarn build`（加 `-SkipBuild` 可以跳过）；
2. 用 electron-builder 打包，直接使用 `node_modules` 里的 Electron，不会重新下载；第一次运行会下载 electron-builder 用来设置 exe 图标的 winCodeSign（约 5.6 MB）；
3. 放入 `.toolchain\jdk*\jre`（Java 8 运行环境）、`check-importer.cmd`、`diagnose-importer.cmd`，以及给玩家的 `README.txt`（源文件在 `tools/release-package/`）；
4. 去掉原作者已经停用的 OCR 模型（`data/tessdata`）和 Python 缓存；
5. 生成 `release\FribbelsE7Optimizer-<版本>-win-x64.zip`，并输出 SHA256。

压缩包约 240 MB，解压后约 540 MB。`release\` 不进 git。

发布新版本的步骤：
1. 修改 `app/package.json` 的 `version` 和 `app/js/lib/updater.js` 的 `currentVersion`，并更新同一文件里的"新功能"说明；
2. 运行打包脚本；
3. 提交、推送，然后用 `gh release create v<版本> release\FribbelsE7Optimizer-<版本>-win-x64.zip --target maintenance` 发布。

便携版的"检查更新"比较的是 Release 的 tag，例如 `v1.11.0`，和程序里的版本号。

## 跟进原仓库

社区一般在游戏补丁后一两周内把新数据合并进原仓库。

### 英雄和神器数据：自动，重启程序即可

程序每次启动时按下面的顺序取数据：

1. 下载服务器上的 `herodata.json` 和 `artifactdata.json`（原作者的 S3；S3 不可用时换成 Azure 镜像），同时记下文件的 `Last-Modified` 时间；
2. 查询原仓库里这两个文件最后一次提交的时间（`api.github.com`）；
3. 如果服务器连不上，或者 GitHub 上的提交比服务器上的文件新 10 分钟以上，说明原作者那边的同步停了，就改用 `raw.githubusercontent.com` 上原仓库 main 分支的版本；
4. 都失败时，用程序自带的 `data/cache/` 里的副本。

查不到 GitHub 的时间时（网络问题或超出频率限制），照常使用服务器上的数据。每个请求 15 秒超时，不会卡住启动。

所以无论是源码版还是便携版，只要社区还在往原仓库合并数据，玩家重启程序就能拿到。

### 代码更新：更新脚本

工具菜单 → 检查更新，或者双击"更新配装器"。从菜单启动时，程序会先自己关闭，更新完再重新打开；直接运行脚本时，要先关掉配装器。

更新来源：有名为 `upstream` 的远程仓库时用 `upstream/main`，否则用 `origin/main`，也可以用 `-Remote` 指定。

脚本会：
1. 在程序还开着，或者有未提交的改动时拒绝运行；
2. 拉取原仓库的 main，列出新提交，然后合并；
3. 按改动的文件决定后面的步骤：
   - `package.json` 或 `yarn.lock` 变了：重新安装依赖，并重新编译前端；
   - `backend/src`、`backend/pom.xml` 或 `backend.jar` 变了：重新编译 jar，并单独提交一次；
   - `app/`、`configs/`、`internals/` 里除 `app/js`、`assets`、`css`、`locales` 以外的文件变了：运行 `yarn build`（`app/js` 是直接加载的，不需要编译）；
   - 只有 `data/` 变了：什么都不用做；
4. 如果只有 `backend.jar` 冲突（原仓库也提交了一份 jar），会自动用合并后的源码重新编译来解决；其他冲突会撤销这次合并，并列出冲突的文件，需要手动处理；
5. 某一步失败时，会把没完成的步骤记在 `.git/fribbels-update-pending` 里，下次运行先补做；
6. 最后检查原仓库有没有把 `global.TEST = true` 或 `allowDowngrade = true` 加回来，有就给出警告。

这些情况都用伪造的上游提交测过：无更新、后端改动、jar 冲突、编译失败后补做、有未提交改动时拒绝运行、程序开着时拒绝运行。

合并后用 `git push` 推到自己的 fork。

### 手动更新

```bash
git fetch upstream
git merge upstream/main
```

如果 `backend/src` 有变化，重新编译 jar（在仓库根目录运行）：

```powershell
$env:JAVA_HOME = "$PWD\.toolchain\jdk8u504-b01"
.\.toolchain\apache-maven-3.9.9\bin\mvn.cmd -B -f backend\pom.xml package "-Dmaven.repo.local=$PWD\.toolchain\m2"
Copy-Item backend\target\backend.jar data\jar\backend.jar
```

如果 `app/` 或 `package.json` 有变化，在仓库根目录重新安装依赖并编译：

```powershell
$env:PATH = "$PWD\.toolchain\node-v16.20.2-win-x64;$env:PATH"
yarn install
yarn build
```

## 自动导入

### 工作原理

1. 程序运行 `data/py/scanner.py`，用自带的 scapy 2.5.0 和 Npcap，被动抓取本机所有网卡上 TCP 端口 5222 和 3333 的流量。它不读游戏内存，也不碰游戏进程。
2. 按"停止扫描"后，抓到的原始数据包会**上传到原作者的服务器**（`krivpfvxi0.execute-api.us-west-2.amazonaws.com/dev/getItems`）解码，返回装备和英雄列表。解码程序不开源，这一点和官方版本一样。
3. 所以导入功能依赖这台服务器。

用法：先关掉游戏，在"导入"页点"开始扫描"，再打开游戏进到大厅，然后点"停止扫描"。它抓的是登录时服务器发下来的数据。

需要另外安装 Python 3（安装时勾选 "Add Python to PATH"）和 [Npcap](https://npcap.com/#download)（需要管理员权限）。装好后用"检测导入环境"检查。

### 支持哪些客户端

只要游戏流量经过这台电脑的网卡就能抓到：

- **模拟器**（MuMu、BlueStacks 等）：原 README 正式列出支持，维护者在 MuMu 上实测可用。
- **Google Play Games 电脑版**：原 README 正式列出支持。
- **手机**：连接电脑开的热点即可，原 README 正式列出支持。
- **STOVE 官方 PC 客户端**：原 README 没写。issue #233 里有用户说可以用，没有验证过。

开着 VPN、代理或加速器时可能抓不到。

### 开着加速器抓不到数据时

可能的原因有三种，对应的解决办法不同：

| 情况 | 现象 | 能不能修 |
|---|---|---|
| A. 加速器用虚拟网卡（TUN/TAP），而且网卡是开始扫描后才创建的 | 端口 3333 的流量出现在一块新网卡上 | 能：让扫描器随时接管新出现的网卡 |
| B. 加速器在本机开代理，把游戏连接转到回环地址的其他端口 | 回环上出现大量非 HTTP/TLS 的 TCP 流量，端口不是 3333 | 能，但需要先弄清游戏协议的特征，才能不靠端口认出游戏流量 |
| C. 加速器在驱动层把数据加密封装进 UDP 隧道 | 只有发往加速节点的大量 UDP | 在电脑上抓不到明文。只能在模拟器内部抓，或者扫描时暂停加速 |

模拟器里运行的加速器（安卓 VPN 应用）属于 C 类：数据在模拟器内部就加密了。可以改用电脑版加速器的"模拟器加速"，或者扫描的那几十秒暂停加速。

"加速器网络诊断"用来判断是哪种情况：

1. 运行后，打开加速器，打开游戏并进到大厅，然后按回车；
2. 它会抓取所有网卡（包括回环）上的 TCP 和 UDP，运行期间新出现的网卡也会自动加进来；
3. 报告保存在 `文档\FribbelsOptimizerSaves\importer-diagnose-时间.txt`，开头的 Hints 段给出判断。

报告里只有连接的地址、端口、流量大小，以及每个 TCP 连接前 3 个数据包各自的前 16 个字节，不会上传任何东西。不过里面有这台电脑其他连接的信息，发给别人之前先看一遍。三种提示都用模拟流量验证过；"运行中新出现的网卡"这一点没有测过。

**给玩家的诊断包：** 运行 `powershell -ExecutionPolicy Bypass -File tools\package-diagnose.ps1`，会生成 `release\FribbelsImporterDiagnose-日期.zip`（约 1.4 MB）。包里只有 `run-diagnose.cmd`、`diagnose_capture.py`、自带的 scapy、中文 `README.txt` 和 scapy 的许可证。玩家电脑上需要装有 Python 3 和 Npcap。源文件在 `tools/diagnose-package/`。

## 仓库与分支

| 远程仓库 | 地址 | 用途 |
|---|---|---|
| `origin` | [Mikakei/Fribbels-Epic-7-Optimizer](https://github.com/Mikakei/Fribbels-Epic-7-Optimizer) | 维护版。`maintenance` 分支是默认分支，Releases 也在这里 |
| `upstream` | [fribbels/Fribbels-Epic-7-Optimizer](https://github.com/fribbels/Fribbels-Epic-7-Optimizer) | 原仓库。更新脚本从它的 main 拉取 |

本仓库里的 `main` 是 fork 时原仓库 main 的副本，只有在 GitHub 上点 Sync fork 才会更新。从本仓库 clone 时，`origin` 指向本仓库，需要自己添加 `upstream`：

```bash
git remote add upstream https://github.com/fribbels/Fribbels-Epic-7-Optimizer.git
```

## 已知但未处理的上游问题

- #234：导入器只导入装备齐全的英雄。需要真实抓包数据才能复现和测试。
- #235：macOS 上抓包选错网卡，只影响 Mac。
