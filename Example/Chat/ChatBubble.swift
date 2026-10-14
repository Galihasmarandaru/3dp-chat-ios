//
//  ChatBubble.swift
//  Example
//

import SwiftUI

struct ChatBubble: View {
    let message: Message
    var onCopy: ((String) -> Void)? = nil
    var onToggleLike: ((UUID, Bool) -> Void)? = nil
    var onActionTap: ((String) -> Void)? = nil
    
    var body: some View {
        HStack {
            if message.sender == .user {
                Spacer()
            }
            
            VStack(alignment: message.sender == .user ? .trailing : .leading, spacing: 8) {
                // Main text bubble
                HStack(alignment: .bottom, spacing: 0) {
                    contentView
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(bubbleBackground)
                .clipShape(bubbleShape)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(message.sender == .user ? "You" : "AI Assistant") message")
                .accessibilityValue(message.text)
                
                if let sources = message.knowledgeSources, !sources.isEmpty {
                    KnowledgeSourceView(sources: sources)
                        .padding(.top, 2)
                }
                
                if let cards = message.carouselCards, !cards.isEmpty {
                    CarouselView(cards: cards, onActionTap: onActionTap)
                        .padding(.top, 4)
                }
                
                HStack(spacing: 8) {
                    Text(formatTimestamp(message.timestamp))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                    
                    if message.showFeedbackBar {
                        FeedbackReactionToolbar(
                            message: message,
                            onCopy: {
                                onCopy?(message.text)
                            },
                            onToggleLike: { isLike in
                                onToggleLike?(message.id, isLike)
                            }
                        )
                    }
                }
                
                if let feedback = message.feedbackComment, !feedback.isEmpty {
                    Text("Masukan: \(feedback)")
                        .font(.caption2)
                        .italic()
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                }
            }
            
            if message.sender == .ai {
                Spacer()
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
    
    @ViewBuilder
    private var contentView: some View {
        Text(attributedString(for: message.text))
            .font(.body)
            .foregroundStyle(message.sender == .user ? .white : .primary)
            .lineLimit(nil)
            .multilineTextAlignment(.leading)
    }
    
    private var bubbleBackground: some View {
        Group {
            if message.sender == .user {
                Color.accentColor
            } else {
                Color(uiColor: .secondarySystemBackground)
            }
        }
    }
    
    private var bubbleShape: some Shape {
        let radius: CGFloat = 18
        if message.sender == .user {
            return UnevenRoundedRectangle(
                topLeadingRadius: radius,
                bottomLeadingRadius: radius,
                bottomTrailingRadius: 4,
                topTrailingRadius: radius
            )
        } else {
            return UnevenRoundedRectangle(
                topLeadingRadius: radius,
                bottomLeadingRadius: 4,
                bottomTrailingRadius: radius,
                topTrailingRadius: radius
            )
        }
    }
    
    private func attributedString(for text: String) -> AttributedString {
        do {
            return try AttributedString(markdown: text, options: .init(interpretedSyntax: .full))
        } catch {
            return AttributedString(text)
        }
    }
    
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
    
    private func formatTimestamp(_ date: Date) -> String {
        return Self.timeFormatter.string(from: date)
    }
}

struct CarouselView: View {
    let cards: [CarouselCard]
    var onActionTap: ((String) -> Void)? = nil
    @State private var currentIndex: Int = 0
    
    var body: some View {
        ZStack(alignment: .center) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                            CarouselCardView(card: card, onActionTap: onActionTap)
                                .id(index)
                                .frame(width: 240)
                        }
                    }
                    .padding(.horizontal, 36)
                    .padding(.vertical, 4)
                }
                .onChange(of: currentIndex) { _, newIndex in
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(newIndex, anchor: .center)
                    }
                }
            }
            
            HStack {
                Button(action: {
                    if currentIndex > 0 {
                        currentIndex -= 1
                    }
                }) {
                    Image(systemName: "chevron.left.circle.fill")
                        .resizable()
                        .frame(width: 28, height: 28)
                        .foregroundStyle(currentIndex > 0 ? Color.accentColor : Color.gray.opacity(0.3))
                        .background(Circle().fill(Color(uiColor: .systemBackground)))
                        .shadow(radius: 2)
                }
                .disabled(currentIndex == 0)
                .padding(.leading, 4)
                
                Spacer()
                
                Button(action: {
                    if currentIndex < cards.count - 1 {
                        currentIndex += 1
                    }
                }) {
                    Image(systemName: "chevron.right.circle.fill")
                        .resizable()
                        .frame(width: 28, height: 28)
                        .foregroundStyle(currentIndex < cards.count - 1 ? Color.accentColor : Color.gray.opacity(0.3))
                        .background(Circle().fill(Color(uiColor: .systemBackground)))
                        .shadow(radius: 2)
                }
                .disabled(currentIndex == cards.count - 1)
                .padding(.trailing, 4)
            }
        }
        .frame(height: 250)
    }
}

private struct CarouselCardView: View {
    let card: CarouselCard
    var onActionTap: ((String) -> Void)? = nil
    @State private var isSelected: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(height: 100)
                    .clipped()
                
                if card.imageName.hasPrefix("http://") || card.imageName.hasPrefix("https://"),
                   let url = URL(string: card.imageName) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .tint(Color.accentColor)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(height: 100)
                                .clipped()
                                .cornerRadius(12)
                        case .failure:
                            Image(systemName: "photo")
                                .font(.system(size: 36))
                                .foregroundStyle(Color.accentColor)
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    Image(systemName: card.imageName.isEmpty ? "sparkles" : card.imageName)
                        .font(.system(size: 40))
                        .foregroundStyle(Color.accentColor)
                }
            }
            
            // Title
            Text(card.title)
                .font(.headline)
                .lineLimit(1)
                .foregroundStyle(.primary)
            
            // Description
            Text(card.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
            
            Spacer()
            
            // Action Button
            Button(action: {
                isSelected.toggle()
                let targetAction = card.actionPayload ?? card.actionTitle
                if targetAction.hasPrefix("http://") || targetAction.hasPrefix("https://"),
                   let url = URL(string: targetAction) {
                    UIApplication.shared.open(url)
                } else {
                    onActionTap?(targetAction)
                }
            }) {
                Text(isSelected ? "Terpilih ✓" : card.actionTitle)
                    .font(.caption.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(isSelected ? Color.green : Color.accentColor)
                    .foregroundStyle(.white)
                    .cornerRadius(8)
            }
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.accentColor.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

struct KnowledgeSourceView: View {
    let sources: [KnowledgeSourceItem]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header Title
            HStack(spacing: 6) {
                Image(systemName: "book.closed.fill")
                    .foregroundStyle(Color.accentColor)
                Text("Knowledge Source")
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
            }
            
            Divider()
            
            // Items List
            ForEach(sources) { item in
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.caption.bold())
                        .foregroundStyle(.primary)
                    
                    Text(item.snippet)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    if let url = URL(string: item.urlString) {
                        Link(destination: url) {
                            HStack(spacing: 4) {
                                Image(systemName: "link")
                                    .font(.caption2)
                                Text(item.urlString)
                                    .font(.caption2)
                                    .underline()
                                Image(systemName: "arrow.up.right.square")
                                    .font(.caption2)
                            }
                            .foregroundStyle(Color.blue)
                        }
                    }
                }
                .padding(8)
                .background(Color(uiColor: .tertiarySystemBackground))
                .cornerRadius(8)
            }
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
        .frame(maxWidth: 320)
    }
}

struct FeedbackReactionToolbar: View {
    let message: Message
    var onCopy: () -> Void
    var onToggleLike: (Bool) -> Void
    
    @State private var isCopied: Bool = false
    
    var body: some View {
        HStack(spacing: 16) {
            Button(action: {
                onCopy()
                isCopied = true
                Task {
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    isCopied = false
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                        .font(.caption)
                        .foregroundStyle(isCopied ? Color.green : Color.secondary)
                }
            }
            .accessibilityLabel("Copy message")
            
            HStack(spacing: 16) {
                // Thumbs Up
                Button(action: {
                    onToggleLike(true)
                }) {
                    Image(systemName: message.isLiked == true ? "hand.thumbsup.fill" : "hand.thumbsup")
                        .font(.caption)
                        .foregroundStyle(message.isLiked == true ? Color.green : Color.secondary)
                }
                
                // Thumbs Down
                Button(action: {
                    onToggleLike(false)
                }) {
                    Image(systemName: message.isLiked == false ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                        .font(.caption)
                        .foregroundStyle(message.isLiked == false ? Color.red : Color.secondary)
                }
            }
            
            Button(action: {
                shareText(message.text)
            }) {
                Image(systemName: "square.and.arrow.up")
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }
            .accessibilityLabel("Share message")
        }
        .padding(.leading, 4)
    }
    
    private func shareText(_ text: String) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return
        }
        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        rootViewController.present(activityVC, animated: true)
    }
}

#Preview {
    VStack(spacing: 16) {
        ChatBubble(message: Message(text: "Hello! This is a user message.", sender: .user))
        ChatBubble(message: Message(
            text: "Here is a menu recommendation:",
            sender: .ai,
            carouselCards: [
                CarouselCard(title: "Nasi Goreng", description: "Enak dan gurih", imageName: "fork.knife", actionTitle: "Pilih")
            ],
            showFeedbackBar: true
        ))
    }
    .padding()
}
