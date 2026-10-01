import SwiftUI

struct InputBar: View {
    @Binding var text: String
    var onAttachFile: (() -> Void)? = nil
    var onSend: () -> Void
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            // Plus / Attachment Button (Popover Menu)
            Menu {
                Button(action: {
                    onAttachFile?()
                }) {
                    Label("Attach File", systemImage: "doc.badge.plus")
                }
            } label: {
                Image(systemName: "plus.circle.fill")
                    .resizable()
                    .frame(width: 32, height: 32)
                    .foregroundStyle(Color.accentColor)
            }
            .accessibilityLabel("Attach media or document")
            .accessibilityHint("Opens menu to select and upload a file")
            
            TextField("Tulis pesan ke AI...", text: $text, axis: .vertical)
                .lineLimit(1...5)
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.sentences)
                .keyboardType(.default)
                .environment(\.locale, Locale(identifier: "id_ID"))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(uiColor: .systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color(uiColor: .separator), lineWidth: 0.5)
                )
                .font(.body)
                .accessibilityLabel("Message input field")
                .accessibilityHint("Enter your message to the AI here")
            
            // Send button
            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .resizable()
                    .frame(width: 32, height: 32)
                    .foregroundStyle(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray.opacity(0.4) : Color.accentColor)
                    .scaleEffect(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.9 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: text.isEmpty)
            }
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityLabel("Send message")
            .accessibilityHint("Sends the current text to the AI")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(uiColor: .secondarySystemBackground))
        .animation(.default, value: text)
    }
}


#Preview {
    struct PreviewWrapper: View {
        @State private var text = ""
        var body: some View {
            InputBar(text: $text) {
                print("Sent: \(text)")
                text = ""
            }
        }
    }
    return PreviewWrapper()
}
