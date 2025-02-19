struct SettingDetailView: View {
    let title: String
    
    var body: some View {
        VStack {
            Text("\(title) Settings")
                .font(.largeTitle)
                .padding()
            Spacer()
        }
        .navigationTitle(title)
    }
}