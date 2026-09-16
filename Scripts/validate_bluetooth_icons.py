"""Compile the production Bluetooth implementation and run its regression tests on macOS."""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
models = (root / 'Halo/Core/PersonalizationModels.swift').read_text()
workspace = (root / 'Halo/Core/WorkspaceModels.swift').read_text()
closed = (root / 'Halo/Views/ClosedNotchView.swift').read_text()
tests = (root / 'Tests/HaloCoreTests.swift').read_text()
source = 'import Foundation\nimport SwiftUI\nimport AppKit\nimport IOBluetooth\nimport CoreAudio\nimport Combine\n'
source += models.split('// MARK: - Bluetooth context state', 1)[1].split('// MARK: - Bluetooth CI settings UI', 1)[0]
source += '\nstruct LiveActivity' + workspace.split('struct LiveActivity', 1)[1].split('protocol LiveActivityProvider', 1)[0]
source += '\nenum ClosedNotchSide { case left, right }\n'
source += 'private enum BluetoothClosedActivity' + closed.split('private enum BluetoothClosedActivity', 1)[1].split('private extension ClosedNotchOptions', 1)[0]
source += 'private struct BluetoothClosedActivityView' + closed.split('private struct BluetoothClosedActivityView', 1)[1].split('@MainActor\nprivate final class MirrorCameraService', 1)[0]
source += '\nfinal class BluetoothIconTests {' + tests.split('final class HaloCoreTests: XCTestCase {', 1)[1].split('    func testPixelPalSquareSizes', 1)[0] + '\n}\n'
# Reuse the exact regression method bodies with fail-fast assertions, without
# depending on the repository's currently incomplete XCTest target.
source = source.replace('XCTAssertEqual', 'checkEqual').replace('XCTAssertNil', 'checkNil').replace('XCTUnwrap', 'unwrap')
source += """
func checkEqual<T: Equatable>(_ actual: T, _ expected: T, file: StaticString = #file, line: UInt = #line) {
    precondition(actual == expected, "Expected \(expected), got \(actual)", file: file, line: line)
}
func checkNil<T>(_ value: T?, file: StaticString = #file, line: UInt = #line) {
    precondition(value == nil, "Expected nil", file: file, line: line)
}
func unwrap<T>(_ value: T?) throws -> T {
    guard let value else { fatalError("Expected a value") }
    return value
}
let tests = BluetoothIconTests()
tests.testBluetoothDeviceSymbolsUseReportedClassForRenamedAccessories()
try tests.testBluetoothDisconnectActivityRetainsVisualAndDecodesLegacyActivities()
print("Bluetooth production code compiled; both regression tests passed.")
"""
with tempfile.TemporaryDirectory(prefix='halo-bluetooth-') as directory:
    source_path = Path(directory) / 'main.swift'
    executable = Path(directory) / 'BluetoothIconTests'
    source_path.write_text(source)
    subprocess.run(['xcrun', 'swiftc', '-swift-version', '5', str(source_path), '-o', str(executable)], check=True)
    subprocess.run([str(executable)], check=True)
