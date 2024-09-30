import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: Settings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Settings")
                .font(.system(size: 24, weight: .bold))
                .padding(.bottom, 20)
            
            HStack {
                Text("Media download location:")
                    .frame(width: 180, alignment: .trailing)
                PathControl(url: $settings.mediaDownloadLocation)
                    .frame(width: 300)
            }
            
            Spacer()
        }
        .padding(30)
        .frame(width: 550, height: 150)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(Settings())
    }
}
