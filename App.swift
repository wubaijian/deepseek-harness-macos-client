import Cocoa
import WebKit

private let serverURL = URL(string: "http://127.0.0.1:3080")!
private let projectPreferenceKey = "DeepSeekHarnessProjectPath"

final class AppDelegate: NSObject, NSApplicationDelegate, WKNavigationDelegate {
    private var window: NSWindow!
    private var webView: WKWebView!
    private var serverProcess: Process?
    private var startedServer = false
    private var startupAttempts = 0
    private var isQuitting = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()

        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.allowsMagnification = true

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1280, height: 820),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "DeepSeek Harness"
        window.minSize = NSSize(width: 900, height: 600)
        window.center()
        window.contentView = webView
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        showStatus(title: "DeepSeek 正在启动", detail: "正在连接本地服务，请稍候……")
        connectOrStartServer()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationWillTerminate(_ notification: Notification) {
        isQuitting = true
        guard startedServer, let process = serverProcess, process.isRunning else { return }
        process.terminate()
    }

    private func connectOrStartServer() {
        checkServer { [weak self] isHarness in
            guard let self else { return }
            DispatchQueue.main.async {
                if isHarness {
                    self.loadHarness()
                } else {
                    self.startServer()
                }
            }
        }
    }

    private func startServer() {
        guard let projectURL = locateHarnessProject() else {
            showFailure("没有找到 DeepSeek Harness 源码文件夹。请重新打开客户端并选择正确的文件夹。")
            return
        }
        guard let nodeURL = locateNode() else {
            showFailure("没有找到 Node.js。请先安装 Node.js 22.19 或更高版本。")
            return
        }

        let process = Process()
        process.executableURL = nodeURL
        process.arguments = [
            "--import", "tsx/esm",
            "apps/cli/src/bin.ts", "web",
            "--host", "127.0.0.1",
            "--port", "3080"
        ]
        process.currentDirectoryURL = projectURL

        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        process.environment = environment

        let logURL = logFileURL()
        FileManager.default.createFile(atPath: logURL.path, contents: nil)
        if let log = FileHandle(forWritingAtPath: logURL.path) {
            try? log.truncate(atOffset: 0)
            process.standardOutput = log
            process.standardError = log
        }

        process.terminationHandler = { [weak self] task in
            guard task.terminationStatus != 0 else { return }
            DispatchQueue.main.async {
                guard let self, !self.isQuitting else { return }
                self.showFailure("后台服务启动失败。错误记录：\(logURL.path)")
            }
        }

        do {
            try process.run()
            serverProcess = process
            startedServer = true
            waitForServer()
        } catch {
            showFailure("无法启动后台服务：\(error.localizedDescription)")
        }
    }

    private func locateHarnessProject() -> URL? {
        let fileManager = FileManager.default
        let appParent = Bundle.main.bundleURL.deletingLastPathComponent()
        let home = fileManager.homeDirectoryForCurrentUser
        var candidates: [URL] = []

        if let saved = UserDefaults.standard.string(forKey: projectPreferenceKey) {
            candidates.append(URL(fileURLWithPath: saved))
        }
        var searchRoot = appParent
        for _ in 0..<4 {
            candidates.append(searchRoot.appendingPathComponent("DeepSeek"))
            candidates.append(searchRoot.appendingPathComponent("deepseek-harness"))
            let parent = searchRoot.deletingLastPathComponent()
            if parent.path == searchRoot.path { break }
            searchRoot = parent
        }
        candidates += [
            home.appendingPathComponent("DeepSeek"),
            home.appendingPathComponent("deepseek-harness")
        ]

        if let match = candidates.first(where: isHarnessProject) {
            UserDefaults.standard.set(match.path, forKey: projectPreferenceKey)
            return match
        }

        let panel = NSOpenPanel()
        panel.title = "选择 DeepSeek Harness 源码文件夹"
        panel.message = "请选择包含 apps、packages 和 package.json 的 deepseek-harness 文件夹。"
        panel.prompt = "选择"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let selected = panel.url, isHarnessProject(selected) else {
            return nil
        }
        UserDefaults.standard.set(selected.path, forKey: projectPreferenceKey)
        return selected
    }

    private func isHarnessProject(_ url: URL) -> Bool {
        let fileManager = FileManager.default
        return fileManager.fileExists(atPath: url.appendingPathComponent("package.json").path)
            && fileManager.fileExists(atPath: url.appendingPathComponent("apps/cli/src/bin.ts").path)
    }

    private func locateNode() -> URL? {
        let fileManager = FileManager.default
        return ["/usr/local/bin/node", "/opt/homebrew/bin/node", "/usr/bin/node"]
            .map { URL(fileURLWithPath: $0) }
            .first { fileManager.isExecutableFile(atPath: $0.path) }
    }

    private func logFileURL() -> URL {
        let logs = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: logs, withIntermediateDirectories: true)
        return logs.appendingPathComponent("DeepSeekHarnessMacClient.log")
    }

    private func waitForServer() {
        startupAttempts += 1
        checkServer { [weak self] isHarness in
            guard let self else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + (isHarness ? 0 : 0.6)) {
                if isHarness {
                    self.loadHarness()
                } else if self.startupAttempts < 100 {
                    self.waitForServer()
                } else {
                    self.showFailure("启动超时。请关闭客户端后重新打开。")
                }
            }
        }
    }

    private func checkServer(completion: @escaping (Bool) -> Void) {
        var request = URLRequest(url: serverURL)
        request.timeoutInterval = 1.5
        URLSession.shared.dataTask(with: request) { data, response, _ in
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            completion(status == 200 && body.contains("DeepSeek Harness"))
        }.resume()
    }

    private func loadHarness() {
        webView.load(URLRequest(url: serverURL))
    }

    private func showStatus(title: String, detail: String) {
        let html = """
        <!doctype html><html lang="zh-CN"><meta charset="utf-8">
        <style>
          body{margin:0;background:#f7f8fa;color:#172033;font:16px -apple-system,BlinkMacSystemFont,"PingFang SC",sans-serif;display:grid;place-items:center;height:100vh}
          main{text-align:center;padding:40px}.mark{width:54px;height:54px;margin:auto;border-radius:16px;background:#151515;color:white;display:grid;place-items:center;font-size:27px;font-weight:700}
          h1{font-size:22px;margin:20px 0 8px}p{color:#667085;margin:0;max-width:680px;line-height:1.7}
        </style><main><div class="mark">D</div><h1>\(title)</h1><p>\(detail)</p></main></html>
        """
        webView.loadHTMLString(html, baseURL: nil)
    }

    private func showFailure(_ message: String) {
        showStatus(title: "启动没有完成", detail: message)
    }
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.regular)
application.run()
