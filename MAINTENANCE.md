# 本地维护版说明（v1.11.0）

本目录是 [fribbels/Fribbels-Epic-7-Optimizer](https://github.com/fribbels/Fribbels-Epic-7-Optimizer) 的本地维护分支 `maintenance`，基于上游 main（2026-10-12，#263）。

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
| 一键更新脚本 | `update-optimizer.cmd`、`update-optimizer.ps1` |

## 已验证（2026-10-19，在本机）

- 程序启动后会从 S3 拉取 herodata.json 和 artifactdata.json，共 391 个英雄、288 个神器，Mei Lin、Haru、Renoa、Lisette、Aube 和神器 Flame Dragon's Jewel 都在。
- 弱化 4 件套：Mei Lin 基础速度 121，套装加速度 +18，正好是 15%。
- 实际跑了一次优化（12 件装备、64 种组合）：带 4 件及以上战意的组合生命 +1036，等于基础生命 5178 的 20%；追击套的件数统计也正确。
- 先删除已穿戴的装备、再删除英雄，现在可以正常完成。

**没有验证：** 装备导入（抓包扫描）。这需要真实的游戏流量。

## 日常使用

双击 `start-optimizer.cmd`。脚本用的是 `.toolchain` 里的便携 JDK 8，不需要在系统里装 Java。

存档位置：`文档\FribbelsOptimizerSaves\`。

## 装备导入需要的额外软件

导入器（Importer）通过抓包读取游戏数据，运行的是 `data/py/scanner.py`，需要你自己安装：

- Python 3（命令行里能运行 `py` 或 `python`）
- [Npcap](https://npcap.com/)：抓包驱动，需要管理员权限安装

这两样都没有放进 `.toolchain`。

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

### 代码更新：双击 `update-optimizer.cmd`

先关掉优化器，再运行。脚本会：

1. 拒绝在程序还开着，或者有未提交改动时运行。
2. 拉取上游 `origin/main`，列出新提交，然后合并。
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
