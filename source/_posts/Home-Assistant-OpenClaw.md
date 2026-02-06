---
title: Home Assistant + OpenClaw
author: blog-author
date: 2026-02-03 08:35:11
categories:
  - OPENCLAW
tags:
  - AI
  - openclaw
  - home assistant
  - 瞎鼓捣
---
# 从 0 到 能说话控制洗衣机：Home Assistant + 美的美居 + OpenClaw 实战记录

> 记录一下我在雨云服务器上从零搭建 Home Assistant，接入美的洗衣机，然后用 OpenClaw / Clawdbot 做到“说一句话就帮我跑桶自洁”的完整过程。  
时间线大致是：**部署 HA → 配环境变量 → 安装集成 → 接入美的洗衣机 → 调通桶自洁程序 → 对话控制链路**。

---

## 一、环境与目标

- 服务器：雨云 VPS
- 系统：Ubuntu Server 22.04 LTS
- 面板：1Panel
- 目标：
  - 在这台服务器上部署 Home Assistant
  - 接入美的洗衣机（美的云 / Midea Auto Cloud）
  - 在 OpenClaw / Clawdbot 中通过自然语言控制洗衣机（例如“帮我打开洗衣机，程序为桶自洁”）

---

## 二、部署 Home Assistant（2 月 2 日）

### 2.1 部署方式选择

Home Assistant 官方支持多种方式：

- Home Assistant OS（整机镜像）
- Home Assistant Container（Docker）
- Home Assistant Core（Python venv）

我的环境本身就有 1Panel 和 Docker，所以选择了 **Home Assistant Container**，方便运维和备份。

### 2.2 Docker 启动 Home Assistant

在服务器上执行（也可以用 1Panel 图形界面对照配置）：

```sh
docker run -d \
  --name homeassistant \
  --restart=unless-stopped \
  -e TZ=Asia/Shanghai \
  -v /opt/homeassistant/config:/config \
  --net=host \
  ghcr.io/home-assistant/home-assistant:stable
```

关键点：

- `--net=host`：方便 Home Assistant 使用 8123 端口和发现局域网设备  
- `-v /opt/homeassistant/config:/config`：配置持久化到宿主机  
- `TZ=Asia/Shanghai`：时区设置为国内时间

部署后，浏览器访问：

```text
http://<服务器 IP>:8123
```

按 Web 引导完成 HA 的初始用户、密码及基础配置。

---

## 三、为 OpenClaw 准备 HA API 环境（2 月 2 日）

为了让 Clawdbot 能通过 Home Assistant 的 API 控制设备，需要在 OpenClaw 的网关进程里配置两个环境变量：

- `HA_URL`：Home Assistant 的访问地址
- `HA_TOKEN`：Home Assistant 的长效访问令牌（Long-Lived Access Token）

### 3.1 在 Home Assistant 创建 Long-Lived Token

在 HA Web 界面中：

1. 右上角点击头像 → “**个人资料**”
2. 滚到页面最底部，找到 **长效访问令牌**
3. 新建一个令牌（例如命名为 `openclaw-gateway`）
4. 复制生成的 Token（只会显示一次）

### 3.2 给 OpenClaw 网关注入环境变量

OpenClaw 网关是一个 systemd 用户服务：`openclaw-gateway.service`。

编辑 override：

```sh
systemctl --user edit openclaw-gateway.service
```

在弹出的编辑器中增加：

```ini
[Service]
Environment=HA_URL=http://127.0.0.1:8123
Environment=HA_TOKEN=<从 HA 生成的 Long-Lived Token>
```

保存后执行：

```sh
systemctl --user daemon-reload
systemctl --user restart openclaw-gateway.service
```

检查环境变量是否生效（例如通过 `ps e` 或日志）可以看到：

```text
HA_URL=http://127.0.0.1:8123
HA_TOKEN=<same token>
```

到此，OpenClaw 内置的 `homeassistant` skill 已具备访问 HA API 的能力。

---

## 四、安装 Midea Auto Cloud 集成并接入美的洗衣机

> 这一段是核心前置：让 Home Assistant 认识洗衣机。

### 4.1 安装 HACS（如未安装）

HACS 是 Home Assistant 的“第三方商店”，很多社区集成都通过它安装。

简单步骤：

1. SSH 到服务器，进入 HA 的配置目录（容器挂载点），比如：
   ```sh
   cd /opt/homeassistant/config
   ```
2. 一键安装脚本：
   ```sh
   wget -O - https://get.hacs.xyz | bash -
   ```
3. 重启 Home Assistant 容器：
   ```sh
   docker restart homeassistant
   ```
4. Web UI 中按照 HACS 文档完成初次配置。  
成功后左侧菜单会出现 `HACS`。

### 4.2 安装并配置 Midea Auto Cloud

1. 在 HACS → **Integrations** 中搜索并安装 `Midea Auto Cloud` 集成
2. 安装完成后重启 HA
3. 进入：设置 → 设备与服务 → 添加集成  
搜索 `Midea Auto Cloud`，按提示用美的 / MSmartHome / 美居账号登录绑定
4. 完成后，到 **设备与实体列表** 中确认美的洗衣机已经以多个实体的形式出现

到这里，洗衣机已经“出现在” Home Assistant 中了，接下来就只剩下找准实体 ID 和程序。

---

## 五、确认洗衣机实体与可用程序（2 月 3 日）

在这一步，需要从 HA 的实体列表中找到与洗衣机有关的几类实体。

### 5.1 关键实体 ID

最终确认的几个关键实体如下（你的设备 ID 可能不同）：

- 电源开关：`switch.208907217759387_power`  
- 启停控制：`switch.208907217759387_control_status`  
- 程序选择：`select.208907217759387_program`  
- 运行状态：`sensor.208907217759387_running_status`

可以通过 HA 的开发者工具 → 状态，或者 API：

```sh
curl -s "$HA_URL/api/states" \
  -H "Authorization: Bearer $HA_TOKEN" | jq '.[] | select(.entity_id | contains("208907217759387"))'
```

来过滤只和洗衣机相关的实体。

### 5.2 程序列表与「桶自洁」对应关系

`select.208907217759387_program` 的属性中有一个 `options` 列表，展示所有支持的程序，例如（节选）：

```json
"options": [
  "cotton",
  "eco",
  "fast_wash",
  "mixed_wash",
  "wool",
  "ssp",
  ...
  "tube_clean_all",
  ...
]
```

通过实际操作验证：

- 在美的 App / HA 前端选择 UI 上显示的「筒自洁」，  
观察 `select.208907217759387_program` 的状态，发现它变成了：`ssp`  
- `options` 列表里还有一个 `tube_clean_all`，对应的是“更彻底”的桶自洁模式

最终结论：

- **「桶自洁」 / 「筒自洁」 → 程序 key：`ssp`**
- **「桶自洁（全）」 → 程序 key：`tube_clean_all`**

这一步非常重要，因为直接用错程序 key 会导致程序执行的模式不符合预期。

---

## 六、在 OpenClaw 里编排洗衣机逻辑（ha-orchestrator）

单纯有 `homeassistant` skill 还不够，它只是能发送 API 请求。  
为了让 Clawdbot 理解“帮我打开洗衣机，程序为桶自洁”这种自然语言，我又加了一个编排 skill：`ha-orchestrator`。

### 6.1 ha-orchestrator 的职责

- 把“人话”解析成：
  - 具体控制的设备（洗衣机）
  - 使用哪个程序（`ssp` / `tube_clean_all`）
  - 应该按什么顺序调用哪些 HA 服务
- 然后调用底层的 `homeassistant` skill 完成实际的 API 请求

### 6.2 洗衣机相关约定

在 `ha-orchestrator` 的文档中，我记录了以下约定：

**实体：**

- 电源：`switch.208907217759387_power`  
- 启停：`switch.208907217759387_control_status`  
- 程序选择：`select.208907217759387_program`

**程序映射：**

- “桶自洁 / 筒自洁 / 桶清洁” → `ssp`
- “桶自洁全 / 强力桶自洁 / 全桶自洁” → `tube_clean_all`

### 6.3 指令模板：开始桶自洁（`ssp`）

当用户说：

- “开始洗衣机筒自洁”
- “开始洗衣机桶自洁”
- “帮我打开洗衣机，程序为桶自洁”

ha-orchestrator 会解析成以下步骤：

1. 打开电源：
   ```sh
   curl -s -X POST "$HA_URL/api/services/switch/turn_on" \
     -H "Authorization: Bearer $HA_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"entity_id": "switch.208907217759387_power"}'
   ```
2. 设置程序为 `ssp`：
   ```sh
   curl -s -X POST "$HA_URL/api/services/select/select_option" \
     -H "Authorization: Bearer $HA_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{
       "entity_id": "select.208907217759387_program",
       "option": "ssp"
     }'
   ```
3. 启动程序：
   ```sh
   curl -s -X POST "$HA_URL/api/services/switch/turn_on" \
     -H "Authorization: Bearer $HA_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"entity_id": "switch.208907217759387_control_status"}'
   ```

### 6.4 指令模板：桶自洁（全）（`tube_clean_all`）

当用户的说法中明确包含“全”：

- “桶自洁全”
- “强力桶自洁”
- “全桶自洁”

则映射为 `tube_clean_all`：

```sh
curl -s -X POST "$HA_URL/api/services/switch/turn_on" \
  -H "Authorization: Bearer $HA_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"entity_id": "switch.208907217759387_power"}'

curl -s -X POST "$HA_URL/api/services/select/select_option" \
  -H "Authorization: Bearer $HA_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "entity_id": "select.208907217759387_program",
    "option": "tube_clean_all"
  }'

curl -s -X POST "$HA_URL/api/services/switch/turn_on" \
  -H "Authorization: Bearer $HA_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"entity_id": "switch.208907217759387_control_status"}'
```

### 6.5 停止洗衣机的指令

当用户说：

- “停止洗衣机”
- “取消当前洗衣机程序”
- “把洗衣机关了”

则执行：

```sh
# 1. 停止当前程序
curl -s -X POST "$HA_URL/api/services/switch/turn_off" \
  -H "Authorization: Bearer $HA_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"entity_id": "switch.208907217759387_control_status"}'

# 2. 可选：关掉电源
curl -s -X POST "$HA_URL/api/services/switch/turn_off" \
  -H "Authorization: Bearer $HA_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"entity_id": "switch.208907217759387_power"}'
```

---

## 七、对话控制链路：从一句话到桶自洁（2 月 3 日）

在一切就绪后，我发出了这样一句话：

> 「帮我打开洗衣机，程序为桶自洁」

Clawdbot 做的事情大致可以拆成：

1. **意图识别**  
   - 设备：洗衣机  
   - 程序：桶自洁（非“全”）
2. **调用 ha-orchestrator**  
   - 根据文档映射“桶自洁” → 程序 key `ssp`
   - 确认实体：
     - `switch.208907217759387_power`
     - `select.208907217759387_program`
     - `switch.208907217759387_control_status`
3. **通过 homeassistant skill 调用 HA API**  
   - 依次发送三条 HTTP 请求：
     1. 打开电源  
     2. 设置程序为 `ssp`  
     3. 启动控制开关
4. **执行结果反馈**  
   
   最终聊天里给我的反馈类似：
   > 已经帮你开启洗衣机，并设置为「桶自洁」程序并启动了。等程序跑完记得把门敞一会儿通风就更好了。

从这一步开始，洗衣机就按照桶自洁程序在跑了。

---

## 八、时间线小结

按时间顺序回顾一下整个过程：

1. **部署 Home Assistant（2 月 2 日）**  
   - 在雨云服务器上通过 Docker / 1Panel 达成 HA 部署  
   - 完成 Web 端初始化
2. **为 OpenClaw 配置 HA_URL / HA_TOKEN（2 月 2 日）**  
   - 在 HA 中生成 Long-Lived Token  
   - 在 `openclaw-gateway.service` 的 systemd override 中注入 `HA_URL` / `HA_TOKEN`  
   - 重启网关，使 `homeassistant` skill 可以直接访问 HA API
3. **安装 HACS + Midea Auto Cloud 并接入洗衣机（2 月 2 日 ～ 2 月 3 日）**  
   - 通过 HACS 安装 Midea Auto Cloud  
   - 用美的账号绑定洗衣机  
   - 在实体列表中确认 washing machine 相关实体存在
4. **确认实体 ID 和程序 key（2 月 3 日）**  
   - 找到洗衣机的电源 / 启停 / 程序选择实体 ID  
   - 验证「筒自洁」实际对应程序 key 为 `ssp`，而不是 `tube_clean_all`
5. **在 ha-orchestrator 中固化映射规则（2 月 3 日）**  
   - 人话 → 程序 key：  
     - 桶自洁 → `ssp`  
     - 桶自洁全 → `tube_clean_all`
   - 人话 → 服务调用序列（电源 → 选程序 → 启动）
6. **自然语言调通桶自洁（2 月 3 日）**  
   - 对 Clawdbot 说：“帮我打开洗衣机，程序为桶自洁”  
   - Clawdbot 自动调用 HA 完成整套操作，并在聊天中反馈结果

---

## 九、后续可以做的扩展

有了这套链路之后，后面可以自然拓展到其他家电：

- 客厅 / 卧室空调：
  - “把客厅空调设到 26 度制冷”
- 热水器：
  - “打开热水器，30 分钟后提醒我关掉”
- 多设备场景：
  - “回家模式：打开客厅灯 + 开空调 26 度制冷 + 播放客厅音箱 BGM”

只要在 `ha-orchestrator` 中持续维护：

1. **实体映射表**：自然语言名称 → HA 实体 ID  
2. **语义 → 参数和服务**：如温度、模式、时长等  
3. **安全检查**：比如洗衣机门锁状态、错误码等

就可以让自然语言控制整个家，而不仅仅是洗衣机。
