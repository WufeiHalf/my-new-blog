title: 在这台服务器上折腾 Hexo + Aurora 的记录
author: blog-author
date: 2026-02-03 20:30:00
categories:
  - 服务器
tags:
  - 服务器
  - 博客配置
  - 瞎鼓捣
  - openclaw代笔
---

> 这篇是给未来的自己看的「操作说明书」：这台雨云服务器上是怎么配置 Hexo + Aurora 的，平时想手动加文章、改 About、重新生成页面，都怎么搞。

## 一、整体结构说明

- 博客根目录：`/opt/blog`
- 引擎：Hexo 8.x
- 主题：`hexo-theme-aurora@2.5.3`
- 域名：`wfcloudfare.xyz`
- 主要配置文件：
  - Hexo 主配置：`/opt/blog/_config.yml`
  - Aurora 主题配置：`/opt/blog/_config.aurora.yml`
- 源文件目录：`/opt/blog/source`
  - 文章：`/opt/blog/source/_posts/*.md`
  - About 页面：`/opt/blog/source/about/index.md`

Hexo 的工作流就是：**改 `source` 里的内容 → 运行生成命令 → 静态文件写到 `public/` 目录 → 由服务端（1Panel/openresty）对外提供访问。**

---

## 二、常用命令速查

以下命令都在 `/opt/blog` 目录下执行：

```bash
cd /opt/blog

# 清理历史生成文件（出问题先来一遍）
npx hexo clean

# 重新生成静态文件
npx hexo generate

# 本地预览（需要端口转发或本机调试时）
npx hexo server
```

如果想用 npm scripts，也可以：

```bash
npm run clean    # 等价于 hexo clean
npm run build    # 等价于 hexo generate
npm run server   # 等价于 hexo server
```

生成完成后，Aurora 会在日志里输出类似：

```text
Thanks for using: hexo-plugin-aurora v1.8.4 & hexo-theme-aurora v2.5.3
API data generated with hexo-plugin-aurora v1.8.4
```

看到这些基本就说明主题侧也正常工作了。

---

## 三、手动添加一篇文章的完整流程

示例：我想写一篇关于服务器/博客的文章，分类放在「服务器」，标签写成「服务器、博客配置、瞎鼓捣、openclaw代笔」。

### 1. 新建 Markdown 文件

在 `/opt/blog/source/_posts` 目录下新建一个 `*.md` 文件，比如：

```bash
cd /opt/blog/source/_posts
nano my-first-server-note.md
```

文件内容模板可以参考下面这个（front‑matter 头部必须顶格写在最前面）：

```yaml
title: 我的第一篇服务器折腾记录
author: blog-author
# 不写 date 就用生成时间；也可以手动指定
date: 2026-02-03 21:00:00
categories:
  - 服务器
tags:
  - 服务器
  - 博客配置
  - 瞎鼓捣
  - openclaw代笔
---

这里开始就是正文内容，可以正常写 Markdown：

- 支持标题、列表、代码块等
- 图片可以放在 `source/` 下面再用相对路径引用

```bash
# 示例命令
ls -al
```
```

说明：
- `categories` 支持多级，比如：
  ```yaml
  categories:
    - 技术
    - 服务器
  ```
  Hexo 会自动生成分类页面，不需要手动注册分类。
- `tags` 是文章级别的关键词，随便写，主题会自动生成标签页。

### 2. 回到项目根目录重新生成

保存文章后，回到 `/opt/blog` 目录，执行：

```bash
cd /opt/blog
npx hexo clean
npx hexo generate
```

看到类似 `Generated: api/categories/服务器.json`、`Generated: post/xxx.html` 的输出，就说明文章已经被收进去了。

### 3. 访问验证

生成完成后，通过域名访问博客首页或归档页面：

- 首页：`https://wfcloudfare.xyz/`
- 归档：主题会在菜单里给出入口

在 Aurora 主题下，文章会自动挂到：

- 首页卡片流
- 分类页（比如「服务器」分类）
- 归档页

---

## 四、About 页面在哪里改

- 源文件路径：`/opt/blog/source/about/index.md`
- 对应页面：`/public/page/about/index.html`
- Aurora 还会生成：`/public/api/pages/about/index.json`

修改步骤：

1. 编辑文件：
   ```bash
   cd /opt/blog
   nano source/about/index.md
   ```
2. 按 Markdown 写你的自我介绍/关于
3. 保存后执行：
   ```bash
   npx hexo generate
   ```
4. 确认日志里有：
   ```text
   Generated: api/pages/about/index.json
   Generated: page/about/index.html
   ```

然后访问博客导航里的 About 页面就能看到最新内容。

---

## 五、Aurora 主题的一些小提示

- 主题路径：`/opt/blog/themes/aurora`（一般不用动源码）
- 主题配置：`/opt/blog/_config.aurora.yml`
- 当文章数量少于 3 篇时，Aurora 会给出提示：
  > You need at least 3 articles to enable [FEATURE MODE], you currently have 1. [PIN MODE] is activated instead!
  这是正常现象，多写两篇文章就会切到完整的「Feature Mode」。

如果要改主题配置（例如：菜单、社交链接、头像等）：

1. 编辑 `_config.aurora.yml`
2. 保存后执行：
   ```bash
   cd /opt/blog
   npx hexo clean
   npx hexo generate
   ```

---

## 六、出问题时可以怎么排查

1. **页面没更新**
   - 确认有没有执行：
     ```bash
     cd /opt/blog
     npx hexo clean
     npx hexo generate
     ```
   - 有缓存场景（CDN）的话注意清一下缓存。

2. **新文章不显示**
   - 检查 `_posts/*.md` 里 front‑matter 是否完整，`---` 分隔符有没有写对。
   - `date` 是否是未来时间（未来时间的文章可能被当成未发布）。

3. **主题样式乱了 / 报错**
   - 先 `npx hexo clean` 再 `npx hexo generate`。
   - 看终端输出有没有明显报错信息。

---

这一篇就当是「Hexo + Aurora 在这台服务器上的使用手册」。以后要是忘了怎么手动加文章、怎么重新生成页面，回来翻翻这篇就行。由 openclaw 代笔记录。