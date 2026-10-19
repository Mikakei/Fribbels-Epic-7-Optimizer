# 本地维护版说明（v1.11.0）

本目录是 [fribbels/Fribbels-Epic-7-Optimizer](https://github.com/fribbels/Fribbels-Epic-7-Optimizer) 的维护分支 `maintenance`，基于上游 main（2026-10-12，#263）。

## 仓库与分支

| 远程仓库 | 地址 | 用途 |
|---|---|---|
| `origin` | [Mikakei/Fribbels-Epic-7-Optimizer](https://github.com/Mikakei/Fribbels-Epic-7-Optimizer) | 你的 fork。`maintenance` 分支推送到这里 |
| `upstream` | [fribbels/Fribbels-Epic-7-Optimizer](https://github.com/fribbels/Fribbels-Epic-7-Optimizer) | 原仓库。更新脚本从它的 main 拉取 |

- 本仓库的提交身份是 `Mikakei <65083444+Mikakei@users.noreply.github.com>`（GitHub 隐私邮箱）。
- 本地有改动时提交，然后运行 `git push`。
- 合并了原仓库的更新后，同样运行 `git push`，把这些提交同步到 fork。
- fork 的默认分支仍然是 `main`，内容和原仓库一致。改动都在 `maintenance` 分支上。

## 为什么要维护

上游最后一个正式版是 v1.10.0（2025-09-12）。之后社区陆续把新套装写进了源码，但一直没人重新编译后端 jar，也没有发布新版本：

- 战意 Warfare、追击 Pursuit（2026-01，#242）
- 弱化 Weakening、热忱 Fervor（2026-06，#256）

结果是 v1.10.0 用不了这 4 个套装；直接用 main 分支也不行，因为前端认识这些套装，`data/jar/backend.jar` 却还是旧的。

## 本分支的改动

| 改动 | 文件 |
|---|---|
| 用当前源码重新编译 `backend.jar`，补上 4 个新套装的计算 | `data/jar/backend.jar` |
| pom 增加打包配置，`mvn package` 直接产出可用的 `backend.jar` | `backend/pom.xml` |
| 删掉写死的 `global.TEST = true`。有这一行时程序只读自带数据，不再从服务器拉最新的英雄和神器数据 | `app/js/lib/heroData.js` |
| 自动更新改成不允许降级。否则自编的版本一启动就会被"更新"回官方 v1.10.0 | `app/main.dev.js` |
| 修复：在装备页删除已穿戴的装备后，英雄仍然引用这件装备，之后删除、卸下或锁定这个英雄时后端报错（NullPointerException） | `backend/.../ItemsRequestHandler.java`、`HeroesRequestHandler.java` |
| 去掉用不到的 node-sass（项目里没有 .scss，而且 4.x 无法在 Node 16 上安装） | `package.json`、`yarn.lock` |
| 版本号改为 1.11.0，更新"新功能"说明 | `app/package.json`、`app/js/lib/updater.js` |
| 数据兜底：服务器连不上，或者服务器上的数据比 GitHub 上的旧超过 10 分钟时，改用 GitHub 上的数据（见下文） | `app/js/lib/heroData.js` |
| 一键更新脚本 | `scripts/update-optimizer.cmd`、`scripts/update-optimizer.ps1` |
| 去掉 Donate、Discord 选项卡和赞助图标；重写"信息"页：说明这是自行维护的版本，附原项目和 Discord 链接，感谢原作者，保留并重新整理原有致谢（中文和繁体中文翻译） | `app/app.html`、`data/locales/zh*/translation.json` |
| 快捷方式入口、"工具"菜单，程序自己准备运行环境 | `app/main.dev.js`、`scripts/` |

## 已验证（2026-10-19，在本机）

- 程序启动后会从 S3 拉取 herodata.json 和 artifactdata.json，共 391 个英雄、288 个神器，Mei Lin、Haru、Renoa、Lisette、Aube 和神器 Flame Dragon's Jewel 都在。
- 弱化 4 件套：Mei Lin 基础速度 121，套装加速度 +18，正好是 15%。
- 实际跑了一次优化（12 件装备、64 种组合）：带 4 件及以上战意的组合生命 +1036，等于基础生命 5178 的 20%；追击套的件数统计也正确。
- 先删除已穿戴的装备、再删除英雄，现在可以正常完成。

- 装备导入（抓包扫描）：用户在本机 MuMu 模拟器上实测，成功读取到数据。

**没有验证：** 导入后 4 个新套装的名称是否正确，以及 STOVE 官方 PC 客户端能不能导入。

## 日常使用

### 入口

程序根目录下有三个快捷方式，都用配装器的图标：

| 快捷方式 | 作用 |
|---|---|
| **Fribbels 配装器** | 直接启动程序，不弹黑色命令行窗口 |
| **更新配装器** | 合并原仓库的更新，并按需重新编译（见下文） |
| **检测导入环境** | 检查自动导入需要的 Python、Npcap、网卡和解码服务器 |

快捷方式由 `scripts\create-shortcuts.ps1` 生成。里面是本机的绝对路径，所以不进 git；挪动程序文件夹后需要重新生成。

想放到桌面或开始菜单，就加上参数运行：

```powershell
powershell -ExecutionPolicy Bypass -File scripts\create-shortcuts.ps1 -Desktop -StartMenu
```

程序菜单栏的 **工具** 里也有这些入口：

- 检查更新…：确认后关闭配装器，在单独的窗口里更新，完成后自动重新打开
- 检测导入环境
- 加速器网络诊断
- 打开维护说明
- 打开程序文件夹

"信息"页的"检查更新"按钮走同样的更新流程。官方 Release 无法更新这个本地版本。

所有脚本都在 `scripts\` 里：`start-optimizer.cmd`、`update-optimizer.cmd/.ps1`、`check-importer.cmd`、`diagnose-importer.cmd`、`create-shortcuts.ps1`。

### 程序自己准备运行环境

本地版本启动时会自动做两件事，所以快捷方式能直接启动 `electron.exe app`，不需要中间脚本：

- 把 `.toolchain\jdk*\bin` 加进 PATH；
- 读取 `.toolchain\python-version`（内容是 `3.14`），设置 `PY_PYTHON`。

窗口标题显示 `Fribbels E7 Optimizer v1.11.0`，不再显示 "Electron"。

存档位置：`文档\FribbelsOptimizerSaves\`。

## 装备导入需要的额外软件

### 导入器怎么工作

1. 程序运行 `data/py/scanner.py`，用自带的 scapy 2.5.0 和 Npcap，被动抓取本机所有网卡上 TCP 端口 5222 和 3333 的流量。它不读游戏内存，也不碰游戏进程。
2. 按"停止扫描"后，抓到的原始数据包（十六进制）会**上传到原作者的 AWS 服务器**（`krivpfvxi0.execute-api.us-west-2.amazonaws.com/dev/getItems`）解码，返回装备和英雄列表。解码程序不开源。
3. 所以导入功能依赖这台服务器。2026-10-19 检查时它还能正常响应。

用法是先关掉游戏，点"开始扫描"，再打开游戏进到大厅，然后点"停止扫描"。它抓的是登录时服务器发下来的数据。

### 本机环境（2026-10-19）

| 项目 | 状态 |
|---|---|
| Python 3.14.7 | 已安装。程序和检测脚本都读取 `.toolchain\python-version`，把 `PY_PYTHON` 设成 3.14，因为 `py` 默认会选 3.15 rc1 |
| 自带 scapy 2.5.0 | 在 3.14 上导入正常；在没有 Npcap 时，scanner.py 也能正常启动和结束 |
| Npcap | 已由用户安装（2026-10-19）。重装时从 [npcap.com/#download](https://npcap.com/#download) 下载，需要管理员权限；"Support raw 802.11 traffic" 只有用无线网卡时才需要勾选 |
| 解码服务器 | 可以访问 |

装好 Npcap 后运行"检测导入环境"（快捷方式或工具菜单），它会列出 scapy 能用的网卡，并检查解码服务器能不能访问。

### 支持哪些客户端

只要游戏流量经过这台电脑的网卡就能抓到：

- **模拟器**（MuMu、BlueStacks 等）：README 正式列出支持。本机 MuMu 已实测可用（2026-10-19）。导入时要重启游戏，所以先暂停 Orange。
- **Google Play Games 电脑版**：README 正式列出支持。
- **手机**：连接电脑开的热点即可。README 正式列出支持。
- **STOVE 官方 PC 客户端**：README 没写。issue #233（2025-09）里有两位用户说可以用，作者没有回复，我也没有验证过。

开着 VPN 或代理时可能抓不到，README 建议关掉 VPN。

### 开着加速器抓不到数据时

玩家反馈开着加速器会抓不到数据。可能的原因有三种，对应的解决办法不同：

| 情况 | 现象 | 能不能修 |
|---|---|---|
| A. 加速器用虚拟网卡（TUN/TAP），而且网卡是开始扫描后才创建的 | 端口 3333 的流量出现在一块新网卡上 | 能：让扫描器随时接管新出现的网卡 |
| B. 加速器在本机开代理，把游戏连接转到回环地址的其他端口 | 回环上出现大量非 HTTP/TLS 的 TCP 流量，端口不是 3333 | 能，但需要先弄清游戏协议的特征，才能不靠端口认出游戏流量 |
| C. 加速器在驱动层直接把数据加密封装进 UDP 隧道 | 只有发往加速节点的大量 UDP | 在电脑上抓不到明文。只能在模拟器内部抓，或者扫描时暂停加速 |

"加速器网络诊断"（工具菜单，或 `scripts\diagnose-importer.cmd`）用来判断是哪种情况：

1. 双击运行。它会抓取所有网卡（包括回环）上的 TCP 和 UDP，运行期间新出现的网卡也会自动加进来。
2. 打开加速器，打开游戏并进到大厅，然后按回车。
3. 报告保存在 `文档\FribbelsOptimizerSaves\importer-diagnose-时间.txt`，开头的 Hints 段给出判断。

报告里只有连接的地址、端口、流量大小，以及每个 TCP 连接前 3 个数据包各自的前 16 个字节，不包含完整数据，也不会上传任何东西。不过里面有这台电脑的其他连接信息，发给别人之前先看一遍。

已在本机用模拟流量验证过三种提示：游戏端口有流量、回环代理、UDP 隧道。"运行中新出现的网卡"这一点没有测过，因为本机没有能临时创建网卡的加速器。

**发给玩家的诊断包：** 运行 `powershell -ExecutionPolicy Bypass -File tools\package-diagnose.ps1`，会生成 `release\FribbelsImporterDiagnose-日期.zip`，约 1.4 MB，不进 git。包里只有以下文件：

- `run-diagnose.cmd`：自动找 `py -3` 或 `python`，报告写到包内的 `reports` 文件夹
- `diagnose_capture.py`
- 自带的 scapy（不含 `__pycache__`）
- `README.txt`：中文使用说明，要求玩家附上加速器名称、模式和客户端类型
- `LICENSE-scapy.txt`

玩家电脑上需要装有 Python 3 和 Npcap。用过自动导入的电脑都已经装好了。

包的源文件在 `tools/diagnose-package/`。已解压测试过：能找到 Python，用的是包内的 scapy，能写出报告；没有 Npcap 时会给出中英文提示。

## 工具链（`.toolchain/`，不进 git）

| 工具 | 版本 | 用途 |
|---|---|---|
| Eclipse Temurin JDK | 8u504-b01 | 编译和运行后端 |
| Apache Maven | 3.9.9 | 打包 `backend.jar` |
| Node.js | 16.20.2 | 这个 Electron 16 老项目在 Node 24 上编译不了 |
| yarn | 1.22.22 | 装在便携 Node 里 |

下载的压缩包都已经和官方校验值核对过，原件保存在 `.toolchain/dl/`。Maven 仓库在 `.toolchain/m2`，yarn 缓存在 `.toolchain/yarn-cache`。

## 跟进上游更新

社区一般在游戏补丁后一两周内合并数据 PR。

### 英雄和神器数据：自动，重启程序即可

程序每次启动时按下面的顺序取数据：

1. 下载服务器上的 `herodata.json` 和 `artifactdata.json`，通常是 S3，S3 不可用时换成 Azure 镜像。同时记下文件的 `Last-Modified` 时间。
2. 查询 GitHub 上这两个文件最后一次提交的时间（`api.github.com`）。
3. 如果服务器连不上，或者 GitHub 上的提交比服务器文件新 10 分钟以上，说明原作者那边的同步停了，就改用 `raw.githubusercontent.com` 上 main 分支的版本。
4. 都失败时，用本地 `data/cache/` 里的副本。

GitHub API 查不到时间（比如网络问题或超出频率限制）时，照常使用服务器上的数据。每个请求 15 秒超时，不会卡住启动。用了 GitHub 副本时，开发者工具的控制台会打印 `Using GitHub copy of ...`。

已在程序里模拟验证过四种情况：正常、服务器数据过期、服务器连不上、GitHub API 返回 403，每种都加载到 391 个英雄。

### 代码更新：工具菜单 → 检查更新，或双击"更新配装器"

从菜单启动时，程序会自己关闭，更新完再重新打开。直接运行脚本时，要先关掉配装器。

更新来源：有名为 `upstream` 的远程仓库时（fork 之后的设置）用 `upstream/main`，否则用 `origin/main`。也可以用 `-Remote` 指定。

脚本会：

1. 拒绝在程序还开着，或者有未提交改动时运行。
2. 拉取原仓库的 main，列出新提交，然后合并。
3. 按改动的文件决定后面的步骤：
   - `package.json` 或 `yarn.lock` 变了：重新安装依赖，并重新编译前端。
   - `backend/src`、`backend/pom.xml` 或 `backend.jar` 变了：重新编译 jar，并单独提交一次。
   - `app/`、`configs/` 或 `internals/` 里，除 `app/js`、`assets`、`css`、`locales` 以外的文件变了：运行 `yarn build`。`app/js` 是直接加载的，不需要编译。
   - 只有 `data/` 变了：什么都不用做。
4. 如果只有 `backend.jar` 冲突（上游也提交了一份 jar），会自动用合并后的源码重新编译来解决。其他冲突会撤销这次合并，并列出冲突的文件，需要手动处理。
5. 某一步失败时，会把没完成的步骤记在 `.git/fribbels-update-pending` 里，下次运行先补做，即使上游没有新提交也一样。
6. 最后检查上游有没有把 `global.TEST = true` 或 `allowDowngrade = true` 加回来，有就给出警告。

已在临时副本里用伪造的上游提交测过：无更新、后端改动、jar 冲突、编译失败后补做、有未提交改动时拒绝运行、程序开着时拒绝运行。

### 手动更新

不用脚本时，步骤如下：

```bash
git fetch origin
git merge origin/main
```

如果 `backend/src` 有变化，重新编译 jar：

```powershell
$env:JAVA_HOME = "F:\Agent\E7\fribbels-optimizer\.toolchain\jdk8u504-b01"
cd backend
..\.toolchain\apache-maven-3.9.9\bin\mvn.cmd -B package "-Dmaven.repo.local=F:\Agent\E7\fribbels-optimizer\.toolchain\m2"
copy target\backend.jar ..\data\jar\backend.jar
```

如果 `app/` 或 `package.json` 有变化，在仓库根目录重新安装依赖并编译（先把 `.toolchain` 里的 Node 加进 PATH）：

```powershell
$env:PATH = "F:\Agent\E7\fribbels-optimizer\.toolchain\node-v16.20.2-win-x64;$env:PATH"
yarn install
yarn build
```

## 已知但未处理的上游问题

- #234：导入器只导入装备齐全的英雄。需要真实抓包数据才能复现和测试。
- #235：macOS 上抓包选错网卡。只影响 Mac。
