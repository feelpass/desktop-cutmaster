import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    // 자유 resize 허용. 최소 800×600 (데스크톱 최소 사용성 보장),
    // 최대 제약 없음 (모니터 크기까지 확장 가능, zoom 버튼 동작).
    self.contentMinSize = NSSize(width: 800, height: 600)
    // 초기 컨텐츠 영역 1400×960.
    self.setContentSize(NSSize(width: 1400, height: 960))

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
