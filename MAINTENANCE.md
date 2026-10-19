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

**英雄和神器数据**由程序启动时从 S3 自动拉取，不需要做任何事。

**代码有更新时：**

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
