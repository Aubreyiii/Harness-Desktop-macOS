# Harness Desktop for macOS

一个轻量的原生 macOS 外壳，用于启动并显示本机的 `dsh web` 服务。

> 非官方社区项目，与 DeepSeek 或上游项目作者无隶属、授权或背书关系。本仓库不包含上游 Harness 源码，也不分发其商标或 Logo。

## 前置条件

- macOS 13 或更高版本
- 已安装 [`deepseek-harness-cli`](https://github.com/HenryZ838978/deepseek-harness)，并能通过 `dsh` 启动
- `dsh` 位于 `~/.local/bin/dsh`、`/opt/homebrew/bin/dsh` 或 `/usr/local/bin/dsh`

## 行为

- 启动时检查 `http://127.0.0.1:3080/`。
- 服务不存在时，从上述路径查找并启动 `dsh web --host 127.0.0.1 --port 3080`。
- 仅在 App 自己启动服务时，退出 App 才停止该服务。
- 外部链接交给系统默认浏览器。
- 运行日志写入 `~/.dsh/run/macos-app.log`。

## 构建

```bash
bash build.sh
```

产物：`build/Harness Desktop.app`

当前构建仅进行 ad-hoc code signing，未进行 Apple Developer ID 签名或 notarization，不建议将构建产物直接作为正式发行版分发。

## 项目边界

- 本仓库只提供 macOS AppKit/WKWebView 启动器。
- Harness CLI 由用户自行安装，并遵循其上游许可证。
- 模型服务、API Key 与模型配置不包含在本仓库中。

## License

本仓库代码使用 [MIT License](LICENSE)。第三方组件说明见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。
