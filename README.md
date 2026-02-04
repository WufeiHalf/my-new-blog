我的新博客计划，由openclaw堂堂复活。

（测试：本地 README 已通过 Webhook 自动部署链路更新一次。）

## 项目简介

这是我的 Hexo 博客源码仓库，用来记录工作积累、折腾笔记和各种配置实战。仓库中的内容会同步部署到我的个人博客站点。

## 核心操作流程

### 1. 本地克隆仓库

```bash
git clone git@github.com:WufeiHalf/my-new-blog.git
cd my-new-blog
npm install
```

### 2. 写一篇新文章

在 `source/_posts` 目录下新建一个 Markdown 文件，例如：

```bash
cd my-new-blog

# 新建文件
vim source/_posts/example-post.md
```

示例内容：

```markdown
---
title: nvm 不同 Node 版本使用不同 registry 的配置实战
date: 2026-02-04 10:50:00
categories:
  - 前端相关
tags:
  - 环境配置
  - nvm
  - node版本
  - 前端配置
  - 工作积累
---

# nvm 不同版本配置不同 registry

这里是正文内容，例如：
- 背景说明
- 配置步骤
- 验证方式
- 踩坑记录
```

保存后，本地预览文章：

```bash
npx hexo server
# 浏览器访问 http://localhost:4000 查看效果
```

### 3. 提交并推送到 GitHub

```bash
git status
git add .
git commit -m "add: example post about nvm multi registry"
git push
```

推送到 GitHub 后，服务器会通过部署脚本拉取最新代码并重新生成博客（当前为手动执行 deploy.sh，后续可以接入 Webhook 自动化）。

### 4. 服务器部署脚本示例

服务器上（/opt/blog）使用的部署脚本大致为：

```bash
#!/usr/bin/env bash
set -e
cd /opt/blog

echo "[deploy] pulling latest code..."
git pull --ff-only

echo "[deploy] generating site..."
npx hexo clean
npx hexo generate

echo "[deploy] done."
```

当我在服务器上执行：

```bash
/opt/blog/deploy.sh
```

就会拉取最新仓库内容并重新生成整站静态文件。后续也可以通过 GitHub Webhook 或 CI/CD（如 GitHub Actions）来自动触发这个脚本，实现全自动部署。

（第二次测试：域名反代 webhook 链路。）

（第三次测试：1Panel 管理 github-hook 站点后推送。）
