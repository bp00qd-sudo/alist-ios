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
                        Toggle("实验性后台保活", isOn: $model.keepAliveEnabled)
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
