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

## 前言

我们在开发的情况下因为项目的历史原因，需要使用不同版本的 node。而在使用 AI 工具的时候又需要使用新版本（20+）的 node，会导致因为配置了公司源导致更新失败，每次都手动加 `--registry=` 又很麻烦，所以研究了下怎么一劳永逸，直接修改配置解决。

## 配置步骤

```sh
# 给不同版本写各自 global

# v20 使用公共源
nvm use 20
npm config set registry https://registry.npmjs.org/ --location=global

# 其他版本使用公司源（旧 npm 用 --global）
nvm use 16
npm config set registry https://art.haizhi.com/artifactory/api/npm/npm/ --global

nvm use 14
npm config set registry https://art.haizhi.com/artifactory/api/npm/npm/ --global

nvm use 12
npm config set registry https://art.haizhi.com/artifactory/api/npm/npm/ --global

nvm use 8
npm config set registry https://art.haizhi.com/artifactory/api/npm/npm/ --global
```

## 验证

```sh
for v in 20 16 14 12 8; do
  nvm use $v >/dev/null
  printf "v%s -> %s\n" "$v" "$(npm config get registry)"
done
```

<br/>

## 可能碰到的问题

### 表现

执行验证脚本打印出来的依旧还是全部都是公司源，好像后面设置的给前面的覆盖掉了。

### 原因

`~/.npmrc`（user/project）里有 `registry=`，优先级高于每个版本的 global，导致所有版本被同一个源覆盖。

---

## 应对方式

清掉 user/project 的 registry：

```sh
# 查看 ~/.npmrc
nl -ba ~/.npmrc

# 删除 registry 行
sed -i '' '/^registry=/d' ~/.npmrc
```

再执行上述的配置流程即可。
