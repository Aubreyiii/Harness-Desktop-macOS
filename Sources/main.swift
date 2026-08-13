import AppKit
import WebKit

private let harnessURL = URL(string: "http://127.0.0.1:3080/")!

final class HarnessService {
    private(set) var process: Process?
    private let logHandle: FileHandle?

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let runDirectory = home.appendingPathComponent(".dsh/run", isDirectory: true)
        try? FileManager.default.createDirectory(at: runDirectory, withIntermediateDirectories: true)
        let logURL = runDirectory.appendingPathComponent("macos-app.log")
        if !FileManager.default.fileExists(atPath: logURL.path) {
            FileManager.default.createFile(atPath: logURL.path, contents: nil)
        }
        logHandle = try? FileHandle(forWritingTo: logURL)
        _ = try? logHandle?.seekToEnd()
    }

    deinit {
        try? logHandle?.close()
    }

    func ensureRunning(completion: @escaping (Result<Void, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            if self.isHealthy() {
                DispatchQueue.main.async { completion(.success(())) }
                return
            }

            do {
                try self.start()
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }

            for _ in 0..<120 {
                if self.isHealthy() {
                    DispatchQueue.main.async { completion(.success(())) }
                    return
                }
                if let process = self.process, !process.isRunning {
                    let error = NSError(
                        domain: "HarnessDesktopApp",
                        code: Int(process.terminationStatus),
                        userInfo: [NSLocalizedDescriptionKey: "Harness 服务启动后立即退出，请查看 ~/.dsh/run/macos-app.log"]
                    )
                    DispatchQueue.main.async { completion(.failure(error)) }
                    return
                }
                Thread.sleep(forTimeInterval: 0.25)
            }

            let error = NSError(
                domain: "HarnessDesktopApp",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "等待 Harness 服务启动超时，请查看 ~/.dsh/run/macos-app.log"]
            )
            DispatchQueue.main.async { completion(.failure(error)) }
        }
    }

    func stopIfOwned() {
        guard let process, process.isRunning else { return }
        process.terminate()
        let deadline = Date().addingTimeInterval(2)
        while process.isRunning && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        if process.isRunning {
            kill(process.processIdentifier, SIGKILL)
        }
    }

    private func isHealthy() -> Bool {
        var request = URLRequest(url: harnessURL)
        request.timeoutInterval = 0.5
        let semaphore = DispatchSemaphore(value: 0)
        var healthy = false
        let task = URLSession.shared.dataTask(with: request) { _, response, _ in
            if let response = response as? HTTPURLResponse, response.statusCode == 200 {
                healthy = true
            }
            semaphore.signal()
        }
        task.resume()
        _ = semaphore.wait(timeout: .now() + 1)
        if !healthy { task.cancel() }
        return healthy
    }

    private func start() throws {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates = [
            "\(home)/.local/bin/dsh",
            "/opt/homebrew/bin/dsh",
            "/usr/local/bin/dsh"
        ]
        guard let executable = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            throw NSError(
                domain: "HarnessDesktopApp",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "找不到 dsh。预期位置：~/.local/bin/dsh"]
            )
        }

        let child = Process()
        child.executableURL = URL(fileURLWithPath: executable)
        child.arguments = ["web", "--host", "127.0.0.1", "--port", "3080"]
        var environment = ProcessInfo.processInfo.environment
        environment["HOME"] = home
        environment["PATH"] = "\(home)/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        child.environment = environment
        child.standardOutput = logHandle
        child.standardError = logHandle
        try child.run()
        process = child
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, WKNavigationDelegate, WKUIDelegate {
    private let service = HarnessService()
    private var window: NSWindow!
    private var webView: WKWebView!

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureMenus()
        configureWindow()
        showLoading()

        service.ensureRunning { [weak self] result in
            guard let self else { return }
            switch result {
            case .success:
                self.webView.load(URLRequest(url: harnessURL))
            case .failure(let error):
                self.showError(error.localizedDescription)
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationWillTerminate(_ notification: Notification) {
        service.stopIfOwned()
    }

    private func configureWindow() {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.uiDelegate = self

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1380, height: 900),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Harness Desktop"
        window.minSize = NSSize(width: 900, height: 620)
        window.center()
        window.contentView = webView
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func configureMenus() {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)
        let appMenu = NSMenu()
        appItem.submenu = appMenu
        appMenu.addItem(withTitle: "关于 Harness Desktop", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "退出 Harness Desktop", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let viewItem = NSMenuItem()
        mainMenu.addItem(viewItem)
        let viewMenu = NSMenu(title: "显示")
        viewItem.submenu = viewMenu
        viewMenu.addItem(withTitle: "重新载入", action: #selector(reloadPage), keyEquivalent: "r")
        viewMenu.addItem(withTitle: "在浏览器中打开", action: #selector(openInBrowser), keyEquivalent: "o")
        viewMenu.addItem(.separator())
        viewMenu.addItem(withTitle: "进入全屏幕", action: #selector(NSWindow.toggleFullScreen(_:)), keyEquivalent: "f")

        NSApp.mainMenu = mainMenu
    }

    @objc private func reloadPage() {
        webView.reload()
    }

    @objc private func openInBrowser() {
        NSWorkspace.shared.open(harnessURL)
    }

    private func showLoading() {
        webView.loadHTMLString(pageHTML(title: "正在启动 Harness Desktop…", detail: "正在连接本机服务 127.0.0.1:3080"), baseURL: nil)
    }

    private func showError(_ message: String) {
        webView.loadHTMLString(pageHTML(title: "无法启动 Harness Desktop", detail: message), baseURL: nil)
    }

    private func pageHTML(title: String, detail: String) -> String {
        let safeTitle = title.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
        let safeDetail = detail.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
        return """
        <!doctype html><meta charset="utf-8"><style>
        html,body{height:100%;margin:0;background:#0b0d10;color:#f5f7fa;font:15px -apple-system,BlinkMacSystemFont,sans-serif}
        body{display:grid;place-items:center}.card{text-align:center;max-width:620px;padding:40px}.logo{font-size:42px;color:#4b8cff;margin-bottom:18px}
        h1{font-size:22px;margin:0 0 12px}p{color:#9da7b5;line-height:1.6;white-space:pre-wrap}
        </style><div class="card"><div class="logo">◉</div><h1>\(safeTitle)</h1><p>\(safeDetail)</p></div>
        """
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }
        if url.host == "127.0.0.1" || url.scheme == "about" || url.scheme == "data" {
            decisionHandler(.allow)
        } else if navigationAction.targetFrame?.isMainFrame == true {
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
        } else {
            decisionHandler(.allow)
        }
    }

    func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = parameters.allowsMultipleSelection
        panel.canChooseDirectories = parameters.allowsDirectories
        panel.canChooseFiles = !parameters.allowsDirectories
        panel.beginSheetModal(for: window) { response in
            completionHandler(response == .OK ? panel.urls : nil)
        }
    }
}

@main
enum HarnessDesktopApplication {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
        _ = delegate
    }
}
