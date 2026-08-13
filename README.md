# Harness Desktop for macOS

一个自包含的原生 macOS App，用于启动并显示本机 Harness Web UI。

> 非官方社区项目，与 DeepSeek 无隶属、授权或背书关系。本仓库不分发 DeepSeek 商标或 Logo。

## 用户安装

当前发行版支持 Apple Silicon（arm64）和 macOS 13 或更高版本。

1. 从 GitHub Releases 下载 `.dmg`。
2. 打开 DMG，把 `Harness Desktop.app` 拖入 `Applications`。
3. 启动 App。
4. 在 Harness 设置中填写你自己的模型服务与 API Key。

发行版已内置 Node.js 和官方 `@deepseek-ai/dsh`，用户无需安装 Node、npm 或 `dsh`，也不需要部署远程服务器。模型凭据不会包含在安装包中。

## 行为

- 启动时检查 `http://127.0.0.1:3080/`，并验证目标确实是 Harness。
- 服务不存在时，优先启动 App 内置运行时。
- 仅在 App 自己启动服务时，退出 App 才停止该服务。
- 用户配置和会话保存在用户自己的 `~/.dsh`。
- 外部链接交给系统默认浏览器。
- 运行日志写入 `~/.dsh/run/macos-app.log`。

## 从源码构建

要求：

- macOS 13 或更高版本
- Xcode Command Line Tools
- 网络连接（首次构建会下载固定版本的 Node.js 与 `@deepseek-ai/dsh`）

```bash
bash build.sh
```

产物：`build/Harness Desktop.app`

制作 DMG、ZIP 与 SHA-256：

```bash
bash package.sh
```

## 签名状态

公开的开发者预览版使用 ad-hoc code signing，尚未进行 Apple Developer ID 签名或 notarization。若 macOS 阻止首次打开，请在 Finder 中右键 App，选择“打开”。正式无警告分发需要 Apple Developer Program 证书与 notarization。

## 内置组件

- [deepseek-ai/deepseek-harness](https://github.com/deepseek-ai/deepseek-harness) / `@deepseek-ai/dsh@0.1.0-rc.6`
- Node.js 24.19.0

第三方许可证随 App 一起放在 `Contents/Resources/licenses/`。

## License

本仓库启动器代码使用 [MIT License](LICENSE)。第三方组件说明见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。
