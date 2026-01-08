import SwiftUI

struct GroupsView: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("Groups")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding()

                Spacer()

                Text("Groups feature coming soon!")
                    .foregroundColor(.secondary)

                Spacer()
            }
            .background(Color.adaptiveDepth0.ignoresSafeArea())
            .navigationBarHidden(true)
        }
    }
}

#Preview {
    GroupsView()
}