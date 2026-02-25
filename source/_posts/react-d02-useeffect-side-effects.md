---
title: "学习 React Day2 积累：useEffect"
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

## 写在前面：我今天想把边界讲清楚

我今天反复在确认的一件事是：**render 是纯计算**。组件函数执行时，它只应该根据 props/state 算出 JSX（也就是 UI 描述），所以我不应该在 render 路径里做任何 I/O，比如 http 请求、订阅、定时器、读写存储、或者直接改 DOM。紧接着对应的另一半是：**useEffect 是“与外部系统同步”的机制**，它在组件渲染提交到屏幕之后运行，用来做那些 React 渲染流程不直接管理的事情。

这里的“外部系统”指的是不受 react 渲染流程直接管理的内容，比如说 http 请求，定时器，浏览器的原生事件等。与外部系统同步其实就是，react 处理完页面展示后，再处理 react 之外的内容同步。

## useEffect 的依赖数组：别当优化开关，当成规则

useEffect 有一个依赖数组，用来标记监听的对象。我今天对它的记法是按“规则”背下来，而不是当成“让它少跑一点”的优化按钮：不写依赖数组的时候，它会在每次渲染后触发；写 `[]` 表示首次渲染的时候触发，结束（卸载）的时候销毁；指定值表示指定值变更的时候触发。紧接着如果我在 effect 里读取了某个 state/props，却没把它写进依赖数组，就会读到旧值，表现出来就是那种“看起来像随机 bug”的 UI 不更新。

另一个我觉得很关键的点是开发环境 StrictMode：effect 可能会触发两次，这是为了暴露“不可重复执行/不可清理”的副作用写法。所以我写 effect 的标准必须是 **可重复执行且可清理**。

## useEffect 的 return：是 cleanup，不是 Promise

useEffect 有两个参数，第一个参数是一个 func，用来表达需要执行的操作逻辑。这个 func 需要 return 的东西，其实是 cleanup，用来在销毁组件的时候触发，或者在依赖变化导致 effect 重跑之前先触发。

我一开始会把 return 理解成“return 一个 abort 状态来表达放弃请求”，但更准确的说法是：return 的不是状态，而是 **撤销这次副作用的函数**。紧接着这也解释了为什么 effect 的 func 不能是 async 的：async 会隐式返回 Promise，和 React 期待的 cleanup function 冲突。如果非要用 async，就在内部定义一个 async 方法并且调用。

## 我今天的代码示例：三态 + Retry + 可复现 error + 可取消请求

我在 sandbox 里做了一个很具体的闭环：页面有 **loading / success / error** 三态，error 里有 Retry；同时我加了一个 `Mock fail` 的开关，把失败路径做成可复现；更重要的是，我让请求可取消，这样组件卸载或依赖变化时不会出现“旧请求回来把新状态覆盖掉”的污染。

下面是我在 `RemoteTodos` 里的核心 effect。它把“同步外界数据”的入口收敛到一条规则里：依赖变化就重跑，重跑之前先 cleanup。

```tsx
useEffect(() => {
  setStatus('loading')

  const request = loadTodos({ query, shouldFail })

  request.promise
    .then((list) => {
      setTodos(list)
      setStatus('success')
    })
    .catch((err) => {
      if (isAbortError(err)) {
        return
      }
      console.error(err)
      setStatus('error')
    })

  return () => {
    request.cancel()
  }
}, [query, retryToken, shouldFail])
```

这里我刻意把 `query`、`retryToken`、`shouldFail` 全写进依赖数组，因为 effect 里确实读取了它们。紧接着 Retry 我也没“直接绕开 effect 再发一次请求”，而是让 `retryToken` 自增，从而让 effect 按同一套规则再执行一遍：

```tsx
onRetry={() => setRetryToken((x) => x + 1)}
```

## AbortController：避免复用被 abort 的 controller

如果需要使用 AbortController，需要写到 useEffect 里，需要避免第一次执行过程中出现的互相污染，比如再次复用了已经被 abort 的 controller。我这次为了把它做得更像工程代码，就把“可取消请求”抽成一个小工具：每次请求创建新的 controller，然后把 cancel 交给 cleanup。

```ts
export type CancelableRequest<T> = {
  promise: Promise<T>
  cancel: () => void
}

export function createCancelableRequest<T>(
  runner: (signal: AbortSignal) => Promise<T>
): CancelableRequest<T> {
  const controller = new AbortController()

  return {
    promise: Promise.resolve().then(() => runner(controller.signal)),
    cancel: () => controller.abort(),
  }
}
```

同时我把 `delay` 也做成支持 `AbortSignal`，这样取消能在“模拟网络延迟”的阶段生效：

```ts
export function delay(ms: number, signal: AbortSignal): Promise<void> {
  return new Promise((resolve, reject) => {
    if (signal.aborted) {
      reject(new DOMException('The operation was aborted.', 'AbortError'))
      return
    }

    const timerId = setTimeout(() => {
      signal.removeEventListener('abort', onAbort)
      resolve()
    }, ms)

    function onAbort() {
      clearTimeout(timerId)
      signal.removeEventListener('abort', onAbort)
      reject(new DOMException('The operation was aborted.', 'AbortError'))
    }

    signal.addEventListener('abort', onAbort, { once: true })
  })
}
```

## AbortController 在真实开发里有没有用？

我今天的原话疑问是：这个 AbortController，不清楚在真实开发中是否有应用场景。紧接着我现在能给自己的一个回答是：当你有“参数频繁变化”的请求（比如搜索框 query）或者“组件很容易卸载/重建”的页面（路由切换、Tab 切换），**可取消** 能把竞态问题从偶发 bug 变成可解释的同步规则。

## 我用来检查自己是不是学会了

我检查时只看可观测行为与可解释性：页面是否覆盖 loading/success/error 三态，重试是否会把状态回到 loading 并重新请求，以及请求是否可取消（或者我能明确解释为什么无需取消）。
