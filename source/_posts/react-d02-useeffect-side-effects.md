---
title: "React 学习 D02：render 纯计算与 useEffect（dependency array 与 cleanup）"
date: 2026-02-25 13:21:00
categories:
  - 前端相关
tags:
  - React
  - Hooks
  - useEffect
  - 副作用
  - 学习笔记
---

## 写在前面：我在 D02 真正想搞清楚的边界

我把 D02 的学习目标压缩成一句话：让 **render 保持纯计算**，同时用 **useEffect** 去处理“与外部系统同步”的事情。紧接着我发现，只要这条边界一清晰，异步请求、定时器、事件监听这些东西就不再是“写着写着就乱了”的黑箱，而是有明确时序与清理规则的可控系统。

这里的“外部系统”指的是不受 React 渲染流程直接管理的世界，例如 HTTP 请求、定时器（setTimeout / setInterval）、浏览器原生事件监听、以及需要手动读写的存储或非 React 管理的 DOM。更有趣的是，React 的渲染过程本质上只负责把 props/state 映射成 UI 描述，因此任何 I/O 都会把渲染从“计算 UI”变成“推动外界变化”，这会让渲染次数的变化直接引爆重复请求、重复订阅与竞态问题。

## useEffect 到底是什么：它同步的是“外部系统”

`useEffect` 是 React 官方提供的 Hook，用来在组件渲染提交到屏幕之后执行副作用，从而把组件状态与外部系统的状态对齐。紧接着这就意味着，effect 不是“写逻辑的地方”，而是“写同步规则的地方”：当哪些输入变化时，需要重新同步外界；当同步建立了外部影响时，需要如何撤销。

在实际使用上，`useEffect(effectFn, deps)` 只有两个参数。第一个参数 `effectFn` 是执行副作用的函数，它可以返回一个 **cleanup function**，用于撤销副作用；第二个参数是 **dependency array**，用于声明 effect 依赖哪些值。

## dependency array：它不是优化开关，而是重跑规则

dependency array 的语义必须被当成规则来理解，因为它直接决定了 effect 何时运行、何时重跑、何时清理。紧接着最常见的混乱来源，就是把它当成“让 effect 少跑一点”的随手开关，或者为了“只跑一次”硬写 `[]`，却在 effect 里读取会变化的 props/state。

它的基本行为可以这样记：不传 deps 的时候，effect 会在每次渲染提交后运行；传 `[]` 的时候，effect 在首次挂载后运行一次，并在卸载时执行 cleanup；传 `[x, y]` 的时候，effect 在首次挂载后运行，并在 `x` 或 `y` 变化后重新运行，而且每次重新运行前都会先执行上一次的 cleanup。

## effect 的 return：返回的是 cleanup，不是 Promise，也不是“abort 状态”

我一开始容易把 `return` 理解成“返回某种状态来中止请求”，但更准确的说法是：`effectFn` 返回的东西必须是 **cleanup function**，它会在组件卸载或依赖变化导致 effect 重跑之前被调用。紧接着这就解释了为什么 `effectFn` 不能直接写成 `async`：如果它是 `async`，就会隐式返回 Promise，这与 React 期待的 cleanup function 冲突。

需要异步逻辑时，常见写法是在 effect 内部定义并调用一个 `async function`，或者直接处理 Promise 链；与此同时，cleanup 用来撤销“这次 effect 建立的外部影响”。

## AbortController：它在真实项目里很常见

`AbortController` 的价值在于把“取消请求”变成可执行的规则，尤其在组件快速切换、参数频繁变化或并发请求时，它能把竞态问题从“偶发 bug”变成“确定性的取消”。紧接着正确的用法是：每次 effect 执行都创建一套新的 controller，并在 cleanup 里调用 `abort()`，从而保证旧请求不会在未来某个时间点回写错误的状态。

更有趣的是，在统一封装层（例如项目里的 `http.ts`）把“可取消请求”抽象成一个 `CancelableRequest` 往往更贴近真实工程，因为它把取消、超时、错误分类与重试策略收敛成可复用的接口，使得组件层只需要声明同步规则而不需要重复造轮子。
