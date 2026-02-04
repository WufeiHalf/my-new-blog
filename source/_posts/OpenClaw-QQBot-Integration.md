---
title: 将 OpenClaw 接入 QQ 机器人的完整实战记录
date: 2026-02-03 19:20:00
categories:
  - 服务器
tags:
  - openclaw
  - 第三方服务
  - 瞎鼓捣
  - 服务器
---

> 这篇是把「将 QQ 接入 OpenClaw」的全过程做一个完整记录，方便以后我自己/别人照着抄。

## 前提条件

- 一台可以长期在线的服务器（我这里是雨云的洛杉矶节点，Ubuntu Server 22.04）
- OpenClaw 已经在服务器上跑起来，采用的是 **本机 `openclaw-cn` 方式**，而不是 Docker
- 已有一个可用的 QQ 号，并可以在 QQ 开放平台创建机器人

## 一、获取 QQ 机器人凭证 & 配置 IP 白名单

1. 打开 QQ 开放平台：<https://q.qq.com/qqbot/#/home>
2. 创建一个「机器人」应用（注意不是小程序/游戏）。
3. 在「开发管理」里拿到：
   - `AppID`
   - `AppSecret`
4. 在机器人配置里找到 **IP 白名单**，填入当前服务器的公网 IP。

公网 IP 可以在服务器上用一条命令查出来，例如：

```bash
curl https://myip.ipip.net
```

我这台机器返回的是：

```text
当前 IP：<你的服务器公网 IP>
```

于是就在 QQ 机器人管理后台的 IP 白名单里填了 `<你的服务器公网 IP>`。

## 二、在服务器上安装 qqbot 插件

OpenClaw 支持通过插件的方式接入各种渠道，QQ 对应的是社区插件 `sliverp/qqbot`。

我的 OpenClaw 工作目录是 `/root/clawd`，在服务器上执行：

```bash
cd /root/clawd

# 第一次使用时拉取 qqbot 插件仓库
git clone https://github.com/sliverp/qqbot.git

# 通过 openclaw-cli 安装插件
openclaw-cn plugins install /root/clawd/qqbot/.
```

安装成功后日志里会出现类似：

```text
Installing to /root/.openclaw/extensions/qqbot…
Installing plugin dependencies…
Installed plugin: qqbot
Restart the gateway to load plugins.
```

## 三、在 OpenClaw 里添加 QQ Bot 渠道

插件装好只是「有能力」接 qqbot，还需要在 OpenClaw 的渠道配置里，把 QQ 机器人账号接上来。

我选择了最简单的方式：直接用命令行添加渠道，把 `AppID` 和 `AppSecret` 拼成一个 token。

命令格式：

```bash
openclaw-cn channels add --channel qqbot --token "AppID:AppSecret"
```

在这台服务器上的实际命令是：

```bash
openclaw-cn channels add --channel qqbot --token "102840004:LctBTm5Pk5RnAXvJi7XyPrJmFjDiDjGn"
```

执行完后，用下面的命令检查渠道状态：

```bash
openclaw-cn channels list
```

预期输出中应该能看到类似：

```text
聊天通道：
- Feishu default: 已配置, token=config, 已启用
- QQ Bot default: 已配置, token=config, 已启用
```

说明 QQ Bot 渠道已经被配置并启用了。

> 如果你更熟悉手动改配置文件，也可以直接编辑 `~/.openclaw/openclaw.json`，在 `channels` 里加上 `qqbot` 的配置块，不过用 `channels add` 命令要省心很多。

## 四、重启 OpenClaw 网关让配置生效

渠道和插件准备好之后，需要重启网关进程，让新的 qqbot 渠道真正生效。

我这里的重启命令是：

```bash
cd /root/clawd
openclaw-cn gateway restart
```

如果你是前台跑的 `openclaw-cn gateway`，也可以 Ctrl + C 停掉再重新启动一次。

## 五、在 QQ 里把机器人拉进来测试

1. 回到 QQ 机器人管理端，在沙箱/调试页面里，找到「添加成员」旁边的二维码。
2. 用手机 QQ 扫码，把机器人加到自己的聊天列表或者某个 QQ 群里。
3. 在 QQ 里给机器人发一句：

   ```text
   你好
   ```

4. 如果一切正常：
   - 服务器日志里会看到 qqbot 收到这条消息；
   - OpenClaw 会转发给当前配置的大脑（比如我现在这个会话）；
   - 机器人会在 QQ 里回你一条正常的文本回复。

到这一步，就说明「OpenClaw ↔ qqbot ↔ QQ」整条链路已经打通了。

## 六、可选：定制 QQ 侧的人设 / 系统提示词

默认情况下，qqbot 渠道会把 QQ 用户的消息转发给 OpenClaw 的主会话，用的是网关里配置的系统提示词。

如果想给 QQ 单独定制一个“人格”，可以在 `qqbot` 渠道配置里加上 `systemPrompt` 字段，例如：

```json
{
  "channels": {
    "qqbot": {
      "enabled": true,
      "appId": "你的AppID",
      "clientSecret": "你的AppSecret",
      "systemPrompt": "你是我的 QQ 机器人助手，回答要尽量简短、口语化。"
    }
  }
}
```

修改完配置之后，再重启一次网关即可生效。

## 七、踩坑 & 小记

- **IP 白名单一定要填服务器的公网 IP**，不是本地电脑的 IP，否则 qqbot 无法正常访问 QQ 接口。
- 插件安装后如果发现渠道列表里没有 QQ Bot，优先检查：
  - `plugins install` 是否报错；
  - `channels add` 命令是否用对 token 格式 `AppID:AppSecret`。
- OpenClaw 提示 `Config was last written by a newer Clawdbot` 可以先暂时忽略，只是配置文件由更新版本写入过的提醒，不影响 qqbot 正常使用。

这次把 QQ 接入 OpenClaw 的过程基本跑通了，后面如果再折腾更多 QQ 相关自动化（比如群管、固定指令、联动其他服务），再另开一篇继续记折腾过程。

