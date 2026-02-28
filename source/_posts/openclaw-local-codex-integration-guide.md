---
title: 打通 OpenClaw 调用本地 Codex：配置步骤与常见坑位
date: 2026-02-28 17:40:00
categories:
  - 服务器
tags:
  - openclaw
  - codex
  - 开发工作流
  - 本地代理
  - 配置排错
---

> 目标：让 OpenClaw 在本机任务中稳定调用本地 Codex CLI，输出可复现 patch/diff，避免因为路径漂移、模型配置错误导致任务失败。

## 目标链路

- **对话与推理**：走远程模型（仅用于理解、规划、总结）。
- **代码修改执行**：走本地 `codex` CLI（本机），产出补丁、必要检查结果和可复现 diff。

---

## 配置步骤

### 1) 固定路径（先解决 80% 的环境问题）

在记忆文件里写死本机 Codex 的绝对路径，例如：

```text
<YOUR_CODEX_BIN>
```

常见取值形态：

```text
/Users/<YOUR_USER>/.nvm/versions/node/<YOUR_NODE_VERSION>/bin/codex
```

这样可以避开两类高频故障：

- nvm 切版本后 `PATH` 指向变化
- shell 环境不一致导致 `codex: command not found`

---

### 2) 约束执行策略（避免“能跑但不稳定”）

建议在系统规则里明确：

- **涉及代码实现 / 修改 / 重构 / 修 bug**：优先调用本地 Codex 产出 patch/diff。
- **默认不执行 `git commit/push`**，除非用户明确要求。
- 调用失败时必须回报：
  - 失败点
  - 关键错误行
  - 下一步修复动作

---

### 3) 本地 Codex 最小校验集

```bash
ls -l <YOUR_CODEX_BIN>
test -x <YOUR_CODEX_BIN> && echo OK
<YOUR_CODEX_BIN> --version
```

三条都过，再开始接业务任务。

---

### 4) 实际任务调用约定（模式化）

推荐流程：

1. Agent 先规划修改点
2. 把任务描述喂给本地 Codex
3. 由 Codex 产出 patch/diff
4. 返回变更摘要 + 验证步骤

如果需要测试，只跑最小必要集，把结果摘要回传给上层 Agent。

---

## 仓库与技能适配：myclaude → OpenClaw

核心思路是复用现成的 wrapper 编排能力，让 OpenClaw 只负责喂任务和接结果。

### 相关技能位置（示例）

- `~/.openclaw/workspace/skills/openclaw-codex/SKILL.md`
  - 用于固定 codex 绝对路径、约定工作目录与校验命令。
- `~/.openclaw/workspace/skills/openclaw-codeagent-wrapper/SKILL.md`
  - 在 OpenClaw 中调用 wrapper，统一入口并支持多后端/并行/worktree。

### myclaude 侧关键文件（脱敏示例）

- wrapper：`/Users/<YOUR_USER>/.claude/bin/codeagent-wrapper`
- 模型配置：`/Users/<YOUR_USER>/.codeagent/models.json`

---

## 可复用的调用方式（heredoc 版）

```bash
/Users/<YOUR_USER>/.claude/bin/codeagent-wrapper \
  --backend codex \
  --workdir /Users/<YOUR_USER>/Desktop/workcode/<YOUR_REPO> \
  --codex-bin <YOUR_CODEX_BIN> <<'EOF_TASK'
<在这里写任务说明，多行可用>
EOF_TASK
```

说明：

- `--codex-bin` 是否可用取决于 wrapper 实现。
- 如果 wrapper 不支持该参数，就在封装脚本里直接写绝对路径调用。

---

## OpenClaw 侧脚本封装建议

可以在 workspace 下放一个薄封装（如 `scripts/codeagent_codex.sh`），脚本只做四件事：

1. 固定 codex 绝对路径
2. 校验 wrapper 存在且可执行
3. 打印关键版本信息（wrapper/codex）
4. 原样透传退出码给上层

这样上层只管任务，不管环境细节。

---

## 适配后的最小验收

```bash
test -x /Users/<YOUR_USER>/.claude/bin/codeagent-wrapper && echo wrapper:OK
test -x <YOUR_CODEX_BIN> && echo codex:OK
ls -l /Users/<YOUR_USER>/.codeagent/models.json
```

再补一条空任务试运行（仅打印版本/环境），确认链路、权限、模型选择都正确。

---

## 常见坑位与处理

### 1. `codex: command not found`

原因：依赖 PATH + nvm 漂移。  
处理：统一改绝对路径。

### 2. 模型配置存在但调用失败

原因：`models.json` 默认后端或模型名不匹配。  
处理：先跑“空任务 + 版本输出”，确认后端和模型生效，再跑真实任务。

### 3. 仓库脏状态导致 diff 混乱

原因：工作区已有未提交改动。  
处理：启用 worktree 隔离，保证单任务单上下文。

---

## 一句话结论

把 **绝对路径固定 + wrapper 统一入口 + 最小验收脚本** 这三件事做完，OpenClaw 调用本地 Codex 的稳定性会明显提升，补丁输出也更容易复现。
