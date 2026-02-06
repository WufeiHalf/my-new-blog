---
title: OpenClaw Skills 实战记录：从 SearXNG 403 到 agent-browser 环境补齐
date: 2026-02-06 17:25:00
categories:
  - OPENCLAW
tags:
  - openclaw
  - openclaw代笔
  - ai
  - skills
---

这篇文章记录一次完整的 OpenClaw“技能体系”落地过程：我在服务器上试图让 OpenClaw 更像一个可持续演进的工作流系统，过程中先踩到了 **SearXNG JSON 403** 的坑，又把 **ClawdHub skill 安装链路**、**auto-updater / self-improving-agent** 以及 **Agent Browser** 的运行环境补齐。

为了避免泄露敏感信息，文中所有 token、内网地址、具体密钥都用占位符代替。

## 目标：把 OpenClaw 从“能聊天”变成“能持续产出”的工作流

这次需求的起点很朴素：我希望 OpenClaw 不仅能回答问题，还能在服务器上形成稳定的三段式闭环：

- **输入层**：联网检索、拉取资料、打开页面、抓取结构化结果
- **执行层**：安装/更新 skills、跑命令、落文件、调度定时任务
- **沉淀层**：把踩坑和修复写进技能说明或 learnings，避免下次重复浪费

其中“输入层”的基石被我放在 SearXNG 上：因为我更想要一个可控、可替换、可解释的搜索入口，而不是黑盒。

## 第一坑：SearXNG 首页 200，但 /search?format=json 403

现象是：

- 访问 `http://search.wfcloudfare.xyz/?token=<TOKEN>` 可以打开 SearXNG 首页（200）
- 但真正自动化需要的接口 `http://search.wfcloudfare.xyz/search?...&format=json` 却一直 403

一开始我以为是 OpenResty 的 token 放行规则没覆盖到 `/search`，但进一步排查发现：

- 只要带 `format=json`，即便直接请求容器内部 `127.0.0.1:8081/search?...&format=json` 也会 403

最终定位到原因：这是 **SearXNG 自身 settings.yml 的 formats 白名单**。

在 `/etc/searxng/settings.yml` 中，配置项 `search.formats` 默认只允许 html：

```yml
search:
  formats:
    - html
```

因此，任何 `format=json` 都会被 SearXNG 直接拒绝（403）。修复方式是把 json 加进白名单：

```yml
search:
  formats:
    - html
    - json
```

改完后重启 searxng 容器，`/search?format=json` 立刻恢复 200，可以稳定返回结构化 JSON。

这个问题的价值在于：它说明“代理侧以为的接口能力”，可能会被服务端的安全默认值暗中削弱；把约束写进技能文档，比口头记忆靠谱。

## 第二坑：ClawdHub CLI 在 Node 24 下跑不起来（缺 undici）

下一步我想装 skills。直觉上是用 ClawdHub CLI：

```bash
npx clawdhub@latest ...
```

但第一次运行直接炸：Node.js v24 环境下报 `ERR_MODULE_NOT_FOUND: Cannot find package 'undici'`。

这个错误本质上是：CLI 的某段代码依赖 `undici`，但 npx 临时环境里没把它带齐，于是直接无法启动。

修复策略也很直接：

- 先用 npx 的 `-p` 把 undici 和 clawdhub 一起装进临时环境验证可用
- 然后干脆全局安装 `clawdhub` + `undici`，让后续更新/安装链路更稳定

对应做法是：

```bash
npm install -g clawdhub undici
clawdhub -V
```

这样以后就不依赖 npx 的临时拼装状态，出错概率小很多。

## 安装与落地：把“能用”的技能补齐到 workspace

这一轮真正落地的 skills 主要是四个方向：

- **clawdhub**：技能管理器本身（搜索/安装/更新/发布）
- **auto-updater**：每天自动更新 OpenClaw + skills（减少维护心智负担）
- **self-improving-agent**：把纠错/踩坑沉淀成可查询的 learnings 文件
- **agent-browser**：补齐浏览器自动化能力，让“网页操作”不依赖 GUI

安装落点统一放在当前工作区：`/root/clawd/skills/`，方便与现有技能一起管理。

### self-improving-agent：不靠脑子记，靠文件记

我额外在 workspace 里建了 `.learnings/` 目录并初始化了三个文件：

- `.learnings/LEARNINGS.md`
- `.learnings/ERRORS.md`
- `.learnings/FEATURE_REQUESTS.md`

这样以后遇到“我以为能用但其实不行”的情况，就能快速记一条：原因、复现、修法、以及应该修改哪个 skill 文档。

### agent-browser：把 Linux 上的浏览器自动化跑通

agent-browser 的 skill 文档建议：

```bash
npm install -g agent-browser
agent-browser install --with-deps
```

在 Linux 服务器上补齐依赖时，会涉及一批图形库（GTK、X11、nss3 等）以及 Playwright 的 Chromium 下载。

安装过程中有一个很现实的运维细节：系统会提示“内核已升级，建议重启以加载新内核”。这不是阻断项，但它提醒了一个事实：**你以为你只是装个工具，实际上你动到的是系统运行时依赖**。如果追求长期稳定，后续应该找时间做一次计划内重启。

安装完成后，用 `example.com` 做最小验证：

- `agent-browser open https://example.com` 成功
- `agent-browser snapshot -i` 能列出交互元素

这意味着浏览器自动化的链路已经在这台 Linux 服务器上闭环。

## 补一个小坑：发布后验证域名写错（根域不一定可用）

发布完成后我习惯性用 `curl https://wfcloudfare.xyz/` 做在线验证，结果在服务器上直接报 `Could not resolve host`，看起来像是 DNS 或网络问题。

但这其实是我把“根域”当成了博客域名。你这个站点真正对外的入口是：

- **https://blog.wfcloudfare.xyz/**

根域 `wfcloudfare.xyz` 在你当前架构下并不保证解析到博客，因此用它做验收会产生误判。

这个坑的修复方法也很直接：验证线上可用性前，先去 `/opt/1panel/www/conf.d/` 看对应站点的 `server_name`，不要靠记忆/猜测。

## 这次流程真正的收获

这轮折腾表面上是“装 skills”，但更关键的收获是把几个隐含规则显性化：

- **服务端能力要以“接口可用性”验真**：UI 能打开不代表 API 能用，`format=json` 这种参数会触发权限分支。
- **工具链要避免临时环境依赖**：能全局安装就别靠 npx 拼装，尤其在 Node 24 这种变化更快的版本上。
- **技能文档必须写出失败模式**：像 SearXNG 的 `search.formats`、ClawdHub 的 `undici`，都属于“你不写就必踩”的坑。
- **沉淀要落到文件**：`.learnings/` 的存在，本质上是把“调教”从对话记忆变成可版本化的工程资产。

后续如果要继续扩工作流，这套结构已经够用了：用 SearXNG 做输入，用技能做执行，用 learnings 做沉淀，再用 cron 做调度。
