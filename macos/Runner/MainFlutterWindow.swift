import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    // 가로 폭은 1400으로 고정 — 부품 행이 잘리지 않도록.
    // 세로는 720 이상 자유롭게 resize 가능.
    let fixedWidth: CGFloat = 1400
    let minHeight: CGFloat = 880
    self.contentMinSize = NSSize(width: fixedWidth, height: minHeight)
    self.contentMaxSize = NSSize(width: fixedWidth, height: CGFloat.greatestFiniteMagnitude)
    // 시작 시 컨텐츠 영역 1400×960으로.
    self.setContentSize(NSSize(width: fixedWidth, height: 960))

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
