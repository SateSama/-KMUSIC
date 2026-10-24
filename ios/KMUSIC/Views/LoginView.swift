import SwiftUI

struct LoginView: View {
    @EnvironmentObject var app: AppState

    @State private var url = ""
    @State private var username = ""
    @State private var password = ""
    @State private var errorText: String?
    @State private var loading = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Spacer(minLength: 60)

                Text("KMUSIC")
                    .font(.system(size: 44, weight: .black))
                    .foregroundColor(Color.kPrimary)
                Text("Connecte ton serveur Navidrome / Subsonic")
                    .font(.subheadline)
                    .foregroundColor(Color.kMuted)
                    .multilineTextAlignment(.center)

                VStack(spacing: 12) {
                    TextField("Adresse (ex. https://musique.exemple.com)", text: $url)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .padding(12)
                        .background(Color.kSurface)
                        .cornerRadius(10)

                    TextField("Nom d'utilisateur", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(12)
                        .background(Color.kSurface)
                        .cornerRadius(10)

                    SecureField("Mot de passe", text: $password)
                        .padding(12)
                        .background(Color.kSurface)
                        .cornerRadius(10)
                }

                if let errorText {
                    Text(errorText)
                        .font(.footnote)
                        .foregroundColor(Color.kPrimaryBright)
                        .multilineTextAlignment(.center)
                }

                Button {
                    connect()
                } label: {
                    HStack {
                        if loading { ProgressView().tint(.white) }
                        Text("Se connecter").fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(14)
                    .background(Color.kPrimary)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(loading || url.isEmpty || username.isEmpty || password.isEmpty)
                .opacity(url.isEmpty || username.isEmpty || password.isEmpty ? 0.5 : 1)
            }
            .padding(24)
        }
        .background(Color.kBackground.ignoresSafeArea())
    }

    private func connect() {
        errorText = nil
        loading = true
        let config = ServerConfig(url: url, username: username, password: password)
        Task {
            do {
                try await app.login(config)
            } catch {
                errorText = error.localizedDescription
            }
            loading = false
        }
    }
}
