import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            Group {
                if model.state == .running,
                   let url = URL(string: model.localURL) {
                    AlistWebView(url: url)
                        .ignoresSafeArea(edges: .bottom)
                } else {
                    launchView
                }
            }
            .navigationTitle("Alist")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(model.state == .running ? "停止服务" : "启动服务") {
                            if model.state == .running { model.stop() } else { model.start() }
                        }
                        Toggle("局域网访问", isOn: Binding(
                            get: { model.lanEnabled },
                            set: { model.toggleLAN($0) }
                        ))
                        Toggle("WebDAV", isOn: Binding(
                            get: { model.webDAVEnabled },
                            set: { model.setWebDAVEnabled($0) }
                        ))
                        Toggle("S3（实验性）", isOn: Binding(
                            get: { model.s3Enabled },
                            set: { model.setS3Enabled($0) }
                        ))
                        Toggle("FTP（实验性）", isOn: Binding(
                            get: { model.ftpEnabled },
                            set: { model.setFTPEnabled($0) }
                        ))
                        Toggle("SFTP（实验性）", isOn: Binding(
                            get: { model.sftpEnabled },
                            set: { model.setSFTPEnabled($0) }
                        ))
                        Toggle("实验性后台任务保活", isOn: $model.keepAliveEnabled)
                        Button("刷新内存统计") { model.refreshMemory() }
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
        }
        .onAppear { if model.state == .stopped { model.start() } }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, model.state == .running { model.refreshMemory() }
        }
    }

    private var launchView: some View {
        VStack(spacing: 18) {
            Image(systemName: "externaldrive.connected.to.line.below")
                .font(.system(size: 52))
                .foregroundStyle(.tint)
            Text(model.state.label)
                .font(.headline)
            if case .failed = model.state {
                Text("请先运行 scripts/build-ios.sh 生成 AlistCore.xcframework。")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button("重试") { model.start() }
                    .buttonStyle(.borderedProminent)
            } else if model.state != .running {
                ProgressView()
            }
        }
        .padding(32)
    }
}
