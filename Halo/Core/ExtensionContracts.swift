import Foundation
import CryptoKit
import SwiftUI
import AppKit

/// Providers are deliberately not instantiated or networked by the core app.
struct WeatherSnapshot: Sendable { var temperatureCelsius: Double; var condition: String; var updated: Date }
protocol WeatherProvider { func forecast(latitude: Double, longitude: Double) async throws -> WeatherSnapshot }
protocol AIActionProvider {
    var disclosure: String { get }
    var isOnDevice: Bool { get }
    /// The caller must obtain explicit consent with the exact content and destination before invoking this method.
    func transform(text: String, instruction: String) async throws -> String
}
protocol NotchCommand { var id: String { get }; var title: String { get }; @MainActor func execute() }
protocol AutomationTrigger { var id: String { get }; func matches(context: [String: String]) -> Bool }
protocol AutomationAction { var id: String { get }; @MainActor func perform() }

struct LicenseClaims: Codable, Equatable {
    var version: Int
    var product: String
    var licenseID: String
    var features: [String]
    /// nil is a perpetual entitlement; verification has no server dependency.
    var expiresAt: Date?
}
struct SignedLicense: Codable {
    var payload: Data
    var signature: Data
    func verified(publicKey: Data, now: Date = Date()) throws -> LicenseClaims {
        let key = try Curve25519.Signing.PublicKey(rawRepresentation: publicKey)
        guard key.isValidSignature(signature, for: payload) else { throw CocoaError(.fileReadCorruptFile) }
        let claims = try JSONDecoder().decode(LicenseClaims.self, from: payload)
        guard claims.version == 1, claims.product == "Halo", !claims.licenseID.isEmpty,
              claims.expiresAt.map({ $0 > now }) ?? true else { throw CocoaError(.fileReadCorruptFile) }
        return claims
    }
}

@MainActor struct EIOpenSurface: View {
    @ObservedObject var e = EISettingsStore.shared; @ObservedObject var p = EIOpenPreferencesStore.shared; @ObservedObject var engine = EnvironmentalInterfaceEngine.shared; @ObservedObject var ui = EIOpenUI.shared
    var body: some View { GeometryReader { g in ZStack { EICozyRoom(p:p.value, env:engine.environment); VStack { HStack { Label(e.settings.mode == .pet ? "Companion" : e.settings.mode == .plant ? "Cozy Garden" : "Tiny World", systemImage:e.settings.mode.symbol).font(.headline); Spacer(); Button { ui.editing.toggle() } label:{Image(systemName:"slider.horizontal.3")}.buttonStyle(.plain); Button { EnvironmentalInterfaceOwnershipController.shared.close() } label:{Image(systemName:"xmark")}.buttonStyle(.plain) }.padding(14); Spacer(); main(size:g.size); Spacer(); actions.padding(.bottom,13) }.foregroundStyle(.white); if ui.editing { HStack { Spacer(); EIQuickEditor().frame(width:min(320,g.size.width*0.55)).padding(12) } } }.clipShape(RoundedRectangle(cornerRadius:24)) } }
    @ViewBuilder private func main(size:CGSize)->some View { switch e.settings.mode { case .off:EmptyView(); case .pet:EIPetAvatar(size:min(145,max(90,size.height*0.45)),walking:false).onTapGesture{engine.interact(.petPat)}; case .plant:EIPlantCozy(size:min(165,max(105,size.height*0.5))).onTapGesture{engine.preview(.plantPerk,duration:3)}; case .simulation:VStack{Image(systemName:"building.2.fill").font(.system(size:min(90,size.height*0.3))).foregroundStyle(p.value.accent.color);Text("A tiny world living in your notch").font(.caption)} } }
    @ViewBuilder private var actions:some View { switch e.settings.mode { case .off:EmptyView(); case .pet:HStack{button("Pat","hand.tap"){engine.interact(.petPat)};button("Snack","fork.knife"){engine.interact(.petSnack)};button("Hello","bubble.left"){engine.interact(.petGreet)}}.disabled(!e.settings.petInteraction); case .plant:HStack{button("Water","drop.fill"){engine.preview(.plantRain,duration:4)};button("Touch","hand.tap"){engine.preview(.plantPerk,duration:3)};button("Sun","sun.max.fill"){engine.preview(.plantBloom,duration:5)}}; case .simulation:HStack{button("Busy","car.2.fill"){engine.preview(.cityBusy,duration:6)};button("Night","moon.stars.fill"){engine.preview(.cityNight,duration:7)};button("Rain","cloud.rain.fill"){engine.preview(.cityRain,duration:7)}} } }
    private func button(_ t:String,_ i:String,_ a:@escaping()->Void)->some View { Button(action:a){Label(t,systemImage:i).font(.caption.bold()).padding(.horizontal,9).padding(.vertical,6).background(.white.opacity(0.1),in:Capsule())}.buttonStyle(.plain) }
}

@MainActor private struct EIQuickEditor: View {
    @ObservedObject var p=EIOpenPreferencesStore.shared; @ObservedObject var e=EISettingsStore.shared
    var body: some View { ScrollView { VStack(alignment:.leading,spacing:10){Text("EI Studio").font(.headline);if e.settings.mode == .pet {Picker("Pet",selection:bind(\.petVisual)){ForEach(EIPetVisualStyle.allCases){Text($0.rawValue).tag($0)}}.pickerStyle(.segmented);Toggle("Roam outside notch",isOn:roam);Toggle("Walk in menu bar",isOn:bind(\.menuBar)).disabled(!p.value.roam);Toggle("Peek from screen edges",isOn:bind(\.screenEdges)).disabled(!p.value.roam)};if e.settings.mode == .pet || e.settings.mode == .plant {Divider();Picker("Room",selection:bind(\.roomStyle)){ForEach(EIRoomStyle.allCases){Text($0.rawValue).tag($0)}};ColorPicker("Room color",selection:color(\.room),supportsOpacity:false);ColorPicker("Accent",selection:color(\.accent),supportsOpacity:false);ColorPicker("Floor",selection:color(\.floor),supportsOpacity:false);Toggle("Window",isOn:bind(\.window));Toggle("Lamp",isOn:bind(\.lamp));Toggle("Rug",isOn:bind(\.rug))};Divider();Toggle("EI shortcut",isOn:bind(\.shortcutEnabled));if p.value.shortcutEnabled {Picker("Key",selection:bind(\.shortcutKey)){Text("E").tag(UInt32(14));Text("I").tag(UInt32(34));Text("P").tag(UInt32(35));Text("J").tag(UInt32(38))};Picker("Modifiers",selection:bind(\.shortcutModifiers)){Text("Option + Command").tag(UInt32(2304));Text("Control + Option").tag(UInt32(6144));Text("Control + Shift").tag(UInt32(4608))}};Text("Context Interfaces always have ownership priority.").font(.caption).foregroundStyle(.secondary)}.padding(13)}.background(.ultraThinMaterial,in:RoundedRectangle(cornerRadius:16)).foregroundStyle(.white) }
    private var roam:Binding<Bool>{Binding(get:{p.value.roam},set:{v in var q=p.value;q.roam=v;p.value=q;if v{var s=e.settings;s.petResident=false;e.settings=s}})}
    private func bind<T>(_ k:WritableKeyPath<EIOpenPreferences,T>)->Binding<T>{Binding(get:{p.value[keyPath:k]},set:{var q=p.value;q[keyPath:k]=$0;p.value=q})}
    private func color(_ k:WritableKeyPath<EIOpenPreferences,WidgetColor>)->Binding<Color>{Binding(get:{p.value[keyPath:k].color},set:{var q=p.value;q[keyPath:k]=WidgetColor($0);p.value=q})}
}

@MainActor struct EIRoamingPetView: View { @ObservedObject var model=EIRoamModel(); @ObservedObject var e=EISettingsStore.shared; @ObservedObject var engine=EnvironmentalInterfaceEngine.shared; var body:some View{EIPetAvatar(size:66,walking:model.walking).scaleEffect(x:model.right ? 1:-1,y:1).contentShape(Rectangle()).onTapGesture{if e.settings.petInteraction{engine.interact(.petPat)}}.contextMenu{Button("Pat"){engine.interact(.petPat)};Button("Snack"){engine.interact(.petSnack)};Button("Open EI"){EnvironmentalInterfaceOwnershipController.shared.open()};Button("Customize"){EnvironmentalInterfaceOwnershipController.shared.open(editor:true)}}} }

@MainActor private struct EIPetAvatar: View {
    let size:CGFloat,walking:Bool; @ObservedObject var p=EIOpenPreferencesStore.shared; @ObservedObject var e=EISettingsStore.shared
    var body:some View{TimelineView(.animation(minimumInterval:walking ? 1.0/30:0.14,paused:false)){t in let ph=t.date.timeIntervalSinceReferenceDate;Group{if p.value.petVisual == .pixel{PixelDisplayRenderer(scene:pixel(ph),preset:e.settings.displayPreset,pixelGrid:e.settings.pixelGrid,glow:e.settings.pixelGlow,scanlines:e.settings.scanlines,ghosting:e.settings.ghosting,brightnessVariation:e.settings.brightnessVariation,phase:ph)}else{Text(emoji).font(.system(size:size*0.68)).shadow(color:e.settings.petPrimaryColor.color.opacity(0.35),radius:7)}}.offset(y:walking ? sin(ph*8)*2:sin(ph*1.5)*0.7)}.frame(width:size,height:size*0.8)}
    private var emoji:String{switch e.settings.petKind{case .cat:return "🐱";case .dog:return "🐶";case .fox:return "🦊"}}
    private func pixel(_ ph:Double)->EIPixelScene{let c=e.settings.petPrimaryColor.color,a=e.settings.petAccentColor.color,y=walking && Int(ph*7).isMultiple(of:2) ? 6:7;var x=[EIPixel(x:7,y:y,width:10,height:5,color:c),EIPixel(x:15,y:y-4,width:6,height:6,color:c),EIPixel(x:9,y:y+5,width:2,height:3,color:c),EIPixel(x:14,y:y+5,width:2,height:3,color:c),EIPixel(x:18,y:y-1,color:.black),EIPixel(x:4,y:y+1,width:4,color:c)];if e.settings.petKind == .dog{x += [EIPixel(x:14,y:y-3,width:2,height:4,color:a),EIPixel(x:20,y:y-3,width:2,height:4,color:a)]}else{x += [EIPixel(x:15,y:y-6,width:2,height:3,color:c),EIPixel(x:19,y:y-6,width:2,height:3,color:c)]};return .init(columns:28,rows:18,pixels:x)}
}

@MainActor private struct EIPlantCozy: View {
    let size:CGFloat; @ObservedObject var e=EISettingsStore.shared; @ObservedObject var engine=EnvironmentalInterfaceEngine.shared
    var body:some View{TimelineView(.animation(minimumInterval:1.0/20,paused:false)){t in let ph=t.date.timeIntervalSinceReferenceDate,g=min(1,engine.persistentState.plant.growth+engine.persistentState.plant.bonusGrowth);ZStack(alignment:.bottom){RoundedRectangle(cornerRadius:10).fill(e.settings.plantPotColor.color).frame(width:size*0.38,height:size*0.27);Capsule().fill(e.settings.plantColor.color).frame(width:size*0.05,height:size*(0.44+g*0.16)).offset(y:-size*0.20);ZStack{ForEach(0..<6,id:\.self){i in Ellipse().fill(e.settings.plantColor.color.opacity(0.9)).frame(width:size*0.29,height:size*0.12).rotationEffect(.degrees(i.isMultiple(of:2) ? -30:30)).offset(x:(i.isMultiple(of:2) ? -1:1)*size*0.14,y:-CGFloat(i/2)*size*0.14).scaleEffect(i<Int(2+g*4) ? 1:0.05)}}.rotationEffect(.degrees(sin(ph*1.2)*(engine.environment.isMusicPlaying ? 6:2))).offset(y:-size*0.33);if engine.currentReaction?.kind == .plantBloom{Circle().fill(.pink).frame(width:size*0.13).offset(y:-size*0.75)}}.frame(width:size,height:size)}}
}

private struct EITriangleRoom:Shape{func path(in r:CGRect)->Path{var p=Path();p.move(to:.init(x:r.midX,y:r.minY));p.addLine(to:.init(x:r.maxX,y:r.maxY));p.addLine(to:.init(x:r.minX,y:r.maxY));p.closeSubpath();return p}}
private struct EICozyRoom:View{
    let p:EIOpenPreferences,env:EIEnvironment
    var body:some View{GeometryReader{g in let a=p.accent.color;ZStack{LinearGradient(colors:bg,startPoint:.topLeading,endPoint:.bottomTrailing);if p.window{RoundedRectangle(cornerRadius:14).fill(LinearGradient(colors:sky,startPoint:.top,endPoint:.bottom)).frame(width:min(145,g.size.width*0.30),height:min(100,g.size.height*0.32)).overlay(RoundedRectangle(cornerRadius:14).stroke(.white.opacity(0.18),lineWidth:2)).position(x:g.size.width*0.24,y:g.size.height*0.35)};Rectangle().fill(p.floor.color).frame(height:g.size.height*0.27).frame(maxHeight:.infinity,alignment:.bottom);if p.rug{Ellipse().fill(a.opacity(0.30)).frame(width:min(250,g.size.width*0.56),height:min(68,g.size.height*0.18)).position(x:g.size.width*0.52,y:g.size.height*0.82)};if p.lamp{VStack(spacing:-2){EITriangleRoom().fill(a.opacity(0.78)).frame(width:44,height:30);Rectangle().fill(.white.opacity(0.35)).frame(width:4,height:40);Capsule().fill(.white.opacity(0.2)).frame(width:30,height:6)}.shadow(color:a.opacity(0.4),radius:24).position(x:g.size.width*0.84,y:g.size.height*0.58)}}}}
    private var sky:[Color]{env.timeOfDay == .night ? [Color(red:0.03,green:0.05,blue:0.13),.purple.opacity(0.45)]:[.blue.opacity(0.7),.orange.opacity(env.timeOfDay == .evening ? 0.5:0.12)]}
    private var bg:[Color]{switch p.roomStyle{case .warm:return[p.room.color,p.accent.color.opacity(0.22),.black.opacity(0.92)];case .night:return[Color(red:0.03,green:0.04,blue:0.09),p.room.color.opacity(0.72),.black];case .greenhouse:return[Color(red:0.04,green:0.12,blue:0.08),p.room.color.opacity(0.75),p.accent.color.opacity(0.16)];case .minimal:return[p.room.color,p.room.color.opacity(0.70),.black.opacity(0.80)]}}
}
