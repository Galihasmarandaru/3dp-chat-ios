//
//  ChatScreen.swift
//  Example
//

import SwiftUI
import UniformTypeIdentifiers
import imi_dolphin_livechat_ios

struct ChatScreen: View {
    @State private var viewModel = ChatViewModel()
    @State private var showSidebar: Bool = false
    @State private var showFileImporter: Bool = false
    @State private var showFeedbackDialog: Bool = false
    @State private var feedbackTargetMessageId: UUID? = nil
    @State private var feedbackInputText: String = ""
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    // Message List
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(viewModel.messages) { message in
                                    ChatBubble(
                                        message: message,
                                        onCopy: { text in
                                            viewModel.copyMessageText(text)
                                        },
                                        onToggleLike: { msgId, isLike in
                                            if isLike {
                                                viewModel.submitFeedback(for: msgId, isLike: true)
                                            } else {
                                                feedbackTargetMessageId = msgId
                                                feedbackInputText = message.feedbackComment ?? ""
                                                showFeedbackDialog = true
                                            }
                                        }
                                    )
                                    .id(message.id)
                                }
                                
                                if viewModel.state == .loading {
                                    loadingBubble
                                        .id("loadingBubble")
                                }
                                
                                Color.clear
                                    .frame(height: 1)
                                    .id("bottom")
                            }
                            .padding(.vertical, 8)
                        }
                        .onChange(of: viewModel.messages) { _, _ in
                            scrollToBottom(proxy: proxy)
                        }
                        .onChange(of: viewModel.state) { _, _ in
                            scrollToBottom(proxy: proxy)
                        }
                        .onAppear {
                            scrollToBottom(proxy: proxy, animated: false)
                        }
                    }
                    

                    
                    Divider()
                    
                    InputBar(text: $viewModel.inputText, onAttachFile: {
                        showFileImporter = true
                    }) {
                        viewModel.sendMessage()
                    }
                }
                .navigationTitle("AI Assistant")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: {
                            viewModel.fetchFavoritesAndHistories()
                            withAnimation(.easeInOut(duration: 0.25)) {
                                showSidebar.toggle()
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "line.3.horizontal")
                                    .font(.body.weight(.semibold))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .cornerRadius(16)
                            .foregroundStyle(.primary)
                        }
                        .accessibilityLabel("Chat Baru & Riwayat")
                        .accessibilityHint("Membuka daftar percakapan dan riwayat chat")
                    }
                }
                .background(Color(uiColor: .systemGroupedBackground))
                
                if let toastText = viewModel.copiedMessageToast {
                    VStack {
                        Spacer()
                        Text(toastText)
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.black.opacity(0.8))
                            .cornerRadius(20)
                            .shadow(radius: 4)
                            .padding(.bottom, 70)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    .animation(.easeInOut, value: toastText)
                }
                
                if showSidebar {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                showSidebar = false
                            }
                        }
                    
                    HStack(spacing: 0) {
                        SidebarView(
                            viewModel: viewModel,
                            onClose: {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    showSidebar = false
                                }
                            }
                        )
                        .frame(width: UIScreen.main.bounds.width * 0.75)
                        
                        Spacer()
                    }
                    .transition(.move(edge: .leading))
                    .zIndex(2)
                }
            }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.png, .jpeg, .pdf, .item],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let selectedUrl = urls.first {
                    viewModel.handleFileSelected(url: selectedUrl)
                }
            case .failure(let error):
                print("File selection error:", error.localizedDescription)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .inactive || newPhase == .background {
                viewModel.onAppClose()
            }
        }
        .alert("Beri Masukan (Feedback)", isPresented: $showFeedbackDialog) {
            TextField("Alasan (misal: jawaban bot kurang sesuai)", text: $feedbackInputText)
            Button("Kirim") {
                if let msgId = feedbackTargetMessageId {
                    let comment = feedbackInputText.trimmingCharacters(in: .whitespacesAndNewlines)
                    viewModel.submitFeedback(for: msgId, isLike: false, feedbackComment: comment.isEmpty ? "jawaban bot kurang sesuai" : comment)
                }
                feedbackTargetMessageId = nil
                feedbackInputText = ""
            }
            Button("Batal", role: .cancel) {
                feedbackTargetMessageId = nil
                feedbackInputText = ""
            }
        } message: {
            Text("Bantu kami meningkatkan kualitas respon dengan memberikan alasan.")
        }
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool = true) {
        let targetId: AnyHashable
        if viewModel.state == .loading {
            targetId = "loadingBubble"
        } else if let lastMessage = viewModel.messages.last {
            targetId = lastMessage.id
        } else {
            targetId = "bottom"
        }
        
        if animated {
            withAnimation(.easeOut(duration: 0.25)) {
                proxy.scrollTo(targetId, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(targetId, anchor: .bottom)
        }
    }
    
    // Custom loading bubble
    private var loadingBubble: some View {
        HStack {
            HStack(spacing: 6) {
                Circle()
                    .frame(width: 8, height: 8)
                    .scaleEffect(viewModel.state == .loading ? 1.2 : 0.8)
                Circle()
                    .frame(width: 8, height: 8)
                    .scaleEffect(viewModel.state == .loading ? 1.2 : 0.8)
                    .delayAnimation(0.2)
                Circle()
                    .frame(width: 8, height: 8)
                    .scaleEffect(viewModel.state == .loading ? 1.2 : 0.8)
                    .delayAnimation(0.4)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(UnevenRoundedRectangle(
                topLeadingRadius: 18,
                bottomLeadingRadius: 4,
                bottomTrailingRadius: 18,
                topTrailingRadius: 18
            ))
            .padding(.horizontal, 8)
            .accessibilityLabel("AI is thinking...")
            
            Spacer()
        }
        .transition(.opacity)
    }
    

}

private struct SidebarView: View {
    var viewModel: ChatViewModel
    var onClose: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Chat Baru & Riwayat")
                    .font(.title3.bold())
                Spacer()
                Button(action: {
                    viewModel.fetchFavoritesAndHistories()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption.bold())
                        Text("Perbarui")
                            .font(.caption.bold())
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.12))
                    .foregroundStyle(Color.accentColor)
                    .cornerRadius(8)
                }
            }
            .padding(.top, 40)
            .padding(.horizontal, 4)
            
            // Tombol Mulai Sesi Baru
            Button(action: {
                viewModel.startNewChat()
                onClose()
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Mulai Obrolan Baru")
                            .font(.headline)
                        Text("Membuat sesi percakapan baru")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(Color.accentColor.opacity(0.1))
                .foregroundStyle(Color.accentColor)
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Favorit")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                        
                        if viewModel.favorites.isEmpty {
                            Text("Belum ada pesan favorit")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 4)
                        } else {
                            ForEach(viewModel.favorites, id: \.transactionId) { item in
                                Button(action: {
                                    onClose()
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "star.fill")
                                            .foregroundStyle(.yellow)
                                            .font(.caption)
                                        Text(item.message ?? "Favorit")
                                            .font(.subheadline)
                                            .lineLimit(1)
                                            .foregroundStyle(.primary)
                                    }
                                    .padding(.vertical, 6)
                                }
                            }
                        }
                    }
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Percakapan")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("LIST OF CONVERSATIONS")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.accentColor)
                        }
                        .padding(.horizontal, 4)
                        
                        if viewModel.isLoadingHistories {
                            VStack(spacing: 6) {
                                ProgressView()
                                    .padding(.top, 8)
                                Text("Memuat daftar percakapan...")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        } else if let errorMsg = viewModel.historyErrorMessage {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 6) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(.orange)
                                    Text("Perhatian")
                                        .font(.caption.bold())
                                }
                                Text(errorMsg)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(10)
                            .background(Color.orange.opacity(0.12))
                            .cornerRadius(10)
                            .padding(.horizontal, 4)
                        } else if viewModel.chatHistories.isEmpty {
                            Text("Belum ada riwayat percakapan")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 4)
                        } else {
                            ForEach(Array(viewModel.chatHistories.enumerated()), id: \.offset) { index, history in
                                let conversationId = (history["conversationId"] as? String) ?? (history["id"] as? String) ?? (history["sessionId"] as? String) ?? "conv_\(index + 1)"
                                let title = (history["title"] as? String) ?? (history["summary"] as? String) ?? (history["lastMessage"] as? String) ?? "Percakapan \(index + 1)"
                                let lastMsg = history["lastMessage"] as? String
                                
                                Button(action: {
                                    // Hit GET LIST OF CHATS IN CONVERSATION & tampilkan di halaman chat
                                    viewModel.loadHistoryChat(conversationId: conversationId, title: title)
                                    onClose()
                                }) {
                                    HStack(alignment: .top, spacing: 10) {
                                        Image(systemName: "bubble.left.and.bubble.right.fill")
                                            .font(.body)
                                            .foregroundStyle(Color.accentColor)
                                            .padding(.top, 2)
                                        
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(title)
                                                .font(.subheadline.bold())
                                                .lineLimit(1)
                                                .foregroundStyle(.primary)
                                            
                                            if let snippet = lastMsg, !snippet.isEmpty {
                                                Text(snippet)
                                                    .font(.caption)
                                                    .lineLimit(2)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption2.bold())
                                            .foregroundStyle(.tertiary)
                                            .padding(.top, 4)
                                    }
                                    .padding(10)
                                    .background(Color(uiColor: .secondarySystemBackground))
                                    .cornerRadius(10)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .background(Color(uiColor: .systemBackground))
        .ignoresSafeArea(edges: .bottom)
        .onAppear {
            viewModel.fetchFavoritesAndHistories()
        }
    }
}

extension View {
    func delayAnimation(_ delay: Double) -> some View {
        self.modifier(DelayAnimationModifier(delay: delay))
    }
}

private struct DelayAnimationModifier: ViewModifier {
    let delay: Double
    @State private var isAnimated = false
    
    func body(content: Content) -> some View {
        content
            .opacity(isAnimated ? 0.3 : 1.0)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 0.6)
                    .repeatForever(autoreverses: true)
                    .delay(delay)
                ) {
                    isAnimated = true
                }
            }
    }
}

#Preview {
    ChatScreen()
}
