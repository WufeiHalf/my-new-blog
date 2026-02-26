---
title: React 基础：useState、事件处理、条件渲染与 Hook 规则
date: 2026-02-26 20:54:17
categories:
  - 前端相关
tags:
  - React
  - Hooks
  - useState
  - 事件处理
  - 条件渲染
  - Full-Stack-Open
---

## useState

### 作用

这个函数调用将**状态（state）**添加到组件中。

```javascript
const [ counter, setCounter ] = useState(0)
```

`counter` 是一个可变化的变量；当这个变量变更时会触发 React 的重新渲染。

`useState` 是一个函数，函数的返回值是一个数组 `[]`：第一个元素是这个变量，第二个元素是设置这个变量的方法，也就是我上面写的 `setCounter`。

`setCounter` 这个修改组件状态的函数被调用的时候，React 会重新渲染组件，也就是会重新执行这个组件函数的函数体。

```javascript
() => {
  const [ counter, setCounter ] = useState(0)
  setTimeout(() => setCounter(counter + 1), 1000)

  return (
    <div>{counter}</div>
  )
}
```

一个这样的代码，调用流程如下：第一次执行 App 函数体，先 `useState(0)` 设置到了 `counter` 是 0，然后一个异步任务先不管，先 return 到页面上是 0。然后异步任务触发，调用 `setCounter` 后重新渲染组件，这个时候 `counter` 是 1 了，然后反复地执行上面的内容。

## 事件处理

### 点击事件

使用 `onClick` 来监听点击事件。点击事件的方法可以直接声明在组件函数的方法里。

```javascript
const App = () => {
  const [ counter, setCounter ] = useState(0)

  const handleClick = () => {
    console.log('clicked')
  }

  return (
    <div>
      <div>{counter}</div>
      <button onClick={handleClick}>plus</button>
    </div>
  )
}
```

也可以直接写在组件 return 的 JSX 代码里。

```javascript
const App = () => {
  const [ counter, setCounter ] = useState(0)

  return (
    <div>
      <div>{counter}</div>
      <button onClick={() => console.log('clicked')}>plus</button>
    </div>
  )
}
```

当然，最好还是声明在模板外部，也就是 `return()` 的外部。

**调用一个改变状态的函数会导致组件重新渲染**。

### 和 useState 结合

`useState()` 括号内的内容不止可以用来设定固定的数值或者字符串，也可以设置为对象。如下所示。

```javascript
const [clicks, setClicks] = useState({ left: 0, right: 0 })
```

那我们在调用的时候，可以使用 `...` 展开语法，来更新指定的对象内容。

```javascript
const handleClick = () => {
  setClicks({ ...clicks, right: clicks.right++ })
}
```

#### set 方法的异步更新

**注意：React 针对值的更新是异步更新的**。也就是说，在下面的这段代码里：

```javascript
const handleLeftClick = () => {
  setAll(allClicks.concat('L'))
  console.log('left before', left)
  setLeft(left + 1)
  console.log('left after', left)
  setTotal(left + right)
}
```

这里的 `left before` 和 `left after` 都会打印出同一个值。所以想要实时展示的话，需要给新值赋值给一个变量，然后 `setTotal` 用这个变量。

### 条件渲染

形如如下代码：

```javascript
const History = (props) => {
  if (props.allClicks.length === 0) {
    return (
      <div>
        the app is used by pressing the buttons
      </div>
    )
  }

  return (
    <div>
      button press history: {props.allClicks.join(' ')}
    </div>
  )
}
```

针对不同的状态展示不同的内容，称之为**条件渲染（conditional rendering）**（v-if 还是比这个简单多了，不知道 React 有没有更好点的语法糖）。

## Hook 函数的规则

像 `useState` 和 `useEffect` 这种称为 **Hook**。它们不能在循环、条件表达式或任何不是定义组件的函数的地方调用。
