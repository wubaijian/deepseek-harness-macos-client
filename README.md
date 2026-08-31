# DeepSeek Harness macOS Client

一个轻量的、非官方的 DeepSeek Harness macOS 桌面客户端外壳。它使用系统原生 Swift、Cocoa 和 WebKit，把本地运行的 [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness) Web UI 放进独立的 Mac 应用窗口。

> 本项目不是 DeepSeek 官方产品，也不包含 DeepSeek 模型权重、API Key 或 DeepSeek Harness 源码。

## 它做什么

- 双击 `.app` 自动启动本地 DeepSeek Harness。
- 使用独立的 macOS 客户端窗口，不需要手动打开浏览器。
- 自动寻找与客户端同级的 `DeepSeek` 或 `deepseek-harness` 文件夹。
- 找不到源码时，弹出文件夹选择窗口。
- 客户端正常退出时，停止由它启动的后台服务。
- API Key 继续由 DeepSeek Harness 自己管理，本客户端不读取或保存密钥。

## 环境要求

- macOS 13 或更高版本
- Apple Silicon Mac
- Node.js `22.19+` 或 `24+`
- 已安装并完成构建的 DeepSeek Harness 源码

先准备 DeepSeek Harness：

```bash
git clone https://github.com/deepseek-ai/deepseek-harness.git DeepSeek
cd DeepSeek
corepack pnpm install
corepack pnpm run build
```

## 构建客户端

```bash
git clone https://github.com/wubaijian/deepseek-harness-macos-client.git
cd deepseek-harness-macos-client
chmod +x build.sh
./build.sh ../DeepSeek
```

构建结果：

```text
dist/DeepSeek Harness.app
```

把应用放在 `DeepSeek` 源码文件夹旁边，随后双击打开。首次使用时，在 DeepSeek Harness 内进入“设置 → 模型”配置 API Key。

## 隐私与安全

- 本仓库不包含任何 API Key、用户配置或会话数据。
- DeepSeek Harness 的密钥由上游项目保存在用户本机的 `~/.dsh/.credentials.yaml`。
- 客户端只监听本机地址 `127.0.0.1:3080`。
- 运行智能体前，请先备份重要文件，并确认所选工作区与权限设置。

## 已知限制

- 当前构建脚本仅面向 Apple Silicon。
- 依赖本机已有的 Node.js 与 DeepSeek Harness 源码，尚未打包为完全独立的安装程序。
- 默认使用 3080 端口；若该端口被其他程序占用，启动会失败。

## 许可证

客户端源代码采用 [MIT License](LICENSE)。DeepSeek Harness 及其标志的权利归各自权利人所有，详见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。
