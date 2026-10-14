//
//  ChatViewModel.swift
//  Example
//

import Foundation
import SwiftUI
import Observation
import imi_dolphin_livechat_ios

enum ChatState: Equatable {
    case idle
    case loading
    case streaming
    case error(String)
}

@Observable
@MainActor
class ChatViewModel {
    var messages: [Message] = []
    var inputText: String = ""
    var state: ChatState = .idle
    var copiedMessageToast: String? = nil
    
    var favorites: [DolphinMessage] = []
    var chatHistories: [[String: Any]] = []
    var isLoadingHistories: Bool = false
    var historyErrorMessage: String? = nil
    
    var isStreaming: Bool {
        state == .streaming
    }
    
    init() {
        messages = []
        state = .loading
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleIncomingMessageNotification(_:)),
            name: Notification.Name(rawValue: notificationMessage),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleConnectionStatusNotification(_:)),
            name: Notification.Name(rawValue: notificationConnectionStatus),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTypingConditionNotification(_:)),
            name: Notification.Name(rawValue: notificationTypingCondition),
            object: nil
        )
        
        if !Connector.shared.access_token.isEmpty || Connector.shared.jwtToken != nil {
            fetchFavoritesAndHistories()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func extractCompletedTurns() -> [(question: String, answer: String)] {
        var turns: [(question: String, answer: String)] = []
        var pendingQuestion: String? = nil
        
        for msg in messages {
            if msg.sender == .user {
                let trimmed = msg.text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    pendingQuestion = trimmed
                }
            } else if msg.sender == .ai {
                let trimmed = msg.text.trimmingCharacters(in: .whitespacesAndNewlines)
                if let q = pendingQuestion, !trimmed.isEmpty && !msg.isStreaming {
                    turns.append((question: q, answer: trimmed))
                    pendingQuestion = nil
                }
            }
        }
        return turns
    }
    
    func onAppClose() {
        let turnsToSave = extractCompletedTurns()
        let convIdToSave = Connector.shared.currentConversationId
        if !turnsToSave.isEmpty {
            Connector.shared.saveConversationTurns(turns: turnsToSave, conversationId: convIdToSave, completion: nil)
        }
        Connector.shared.endActiveSession()
    }
    
    func startNewChat() {
        let turnsToSave = extractCompletedTurns()
        let convIdToSave = Connector.shared.currentConversationId
        
        messages = []
        state = .loading
        
        Connector.shared.enableGetQueue(isEnable: false)
        
        if Connector.shared.isConnected {
            Connector.shared.endActiveSession()
        }
        
        // Start a fresh conversation ID for the new chat
        Connector.shared.startNewConversation()
        
        // Asynchronously archive previous conversation turns in background
        if !turnsToSave.isEmpty {
            Task.detached { [weak self] in
                Connector.shared.saveConversationTurns(turns: turnsToSave, conversationId: convIdToSave) { success in
                    if success {
                        print("[ChatViewModel] Successfully saved conversation \(convIdToSave) to history.")
                    }
                    Task { @MainActor [weak self] in
                        self?.fetchFavoritesAndHistories()
                    }
                }
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if Connector.shared.access_token.isEmpty {
                Connector.shared.getUserToken()
            } else {
                Connector.shared.doConnectToStomp()
            }
        }
    }
    
    func handleFileSelected(url: URL) {
        guard Connector.shared.attachmentManager.validateFileMimeType(url: url) else {
            state = .error("Tipe file tidak didukung (.png, .jpg, .pdf, .doc, .docx, .xls, .xlsx)")
            return
        }
        
        let nsUrl = url as NSURL
        let ext = url.pathExtension.lowercased()
        let stateType = (ext == "png" || ext == "jpg" || ext == "jpeg") ? "image" : "document"
        
        state = .loading
        Connector.shared.sendAttachment(fileNsUrl: nsUrl, state: stateType)
        let fileMsg = Message(
            text: "[File Attached: \(url.lastPathComponent)]",
            sender: .user,
            timestamp: Date()
        )
        messages.append(fileMsg)
        state = .idle

    }
    
    func fetchFavoritesAndHistories() {
        isLoadingHistories = true
        historyErrorMessage = nil
        
        Connector.shared.fetchFavorites { [weak self] list in
            Task { @MainActor in
                self?.favorites = list
            }
        }
        Connector.shared.fetchConversations { [weak self] list, errorMsg in
            Task { @MainActor in
                self?.isLoadingHistories = false
                self?.chatHistories = list
                self?.historyErrorMessage = errorMsg
            }
        }
    }
    
    func loadHistoryChat(conversationId: String, title: String? = nil) {
        let turnsToSave = extractCompletedTurns()
        let convIdToSave = Connector.shared.currentConversationId
        if !turnsToSave.isEmpty && convIdToSave != conversationId {
            Task.detached { [weak self] in
                Connector.shared.saveConversationTurns(turns: turnsToSave, conversationId: convIdToSave) { _ in
                    Task { @MainActor [weak self] in
                        self?.fetchFavoritesAndHistories()
                    }
                }
            }
        }
        Connector.shared.currentConversationId = conversationId
        
        state = .loading
        Connector.shared.fetchConversationChats(conversationId: conversationId) { [weak self] chats in
            Task { @MainActor in
                guard let self = self else { return }
                self.state = .idle
                if !chats.isEmpty {
                    var parsedMessages: [Message] = []
                    let dateFormatter = ISO8601DateFormatter()
                    dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    let fallbackFormatter = ISO8601DateFormatter()
                    
                    for item in chats {
                        var timestamp = Date()
                        if let tsNum = (item["timestamp"] as? Double) ?? (item["createdDate"] as? Double) {
                            timestamp = Date(timeIntervalSince1970: tsNum > 10_000_000_000 ? tsNum / 1000 : tsNum)
                        } else if let dateStr = (item["createdDate"] as? String) ?? (item["createdAt"] as? String) {
                            timestamp = dateFormatter.date(from: dateStr) ?? fallbackFormatter.date(from: dateStr) ?? Date()
                        }
                        
                        let ratingStr = item["rating"] as? String
                        let isLiked: Bool? = (ratingStr == "up") ? true : ((ratingStr == "down") ? false : nil)
                        let ratingFeedback = item["ratingFeedback"] as? String
                        let chatId = (item["id"] as? String) ?? (item["messageId"] as? String) ?? (item["transactionId"] as? String)
                        
                        // Dukung format question & answer jika respons server berpasangan
                        if let question = (item["question"] as? String) ?? (item["query"] as? String), !question.isEmpty {
                            let qMsg = Message(text: question, sender: .user, timestamp: timestamp)
                            parsedMessages.append(qMsg)
                        }
                        if let answer = (item["answer"] as? String) ?? (item["response"] as? String), !answer.isEmpty {
                            let aMsg = Message(
                                serverId: chatId,
                                text: answer,
                                sender: .ai,
                                timestamp: timestamp,
                                isStreaming: false,
                                showFeedbackBar: true,
                                isLiked: isLiked,
                                feedbackComment: ratingFeedback
                            )
                            parsedMessages.append(aMsg)
                            continue
                        }
                        
                        // Format individual message (message / role)
                        let text = (item["message"] as? String) ?? (item["content"] as? String) ?? (item["text"] as? String) ?? ""
                        guard !text.isEmpty else { continue }
                        let senderStr = ((item["sender"] as? String) ?? (item["role"] as? String) ?? "").lowercased()
                        let isUser = senderStr == "user" || (item["isUser"] as? Bool == true)
                        
                        let msg = Message(
                            serverId: chatId,
                            text: text,
                            sender: isUser ? .user : .ai,
                            timestamp: timestamp,
                            isStreaming: false,
                            showFeedbackBar: !isUser,
                            isLiked: isLiked,
                            feedbackComment: ratingFeedback
                        )
                        parsedMessages.append(msg)
                    }
                    if !parsedMessages.isEmpty {
                        self.messages = parsedMessages
                    }
                }
            }
        }
    }

    
    func sendMessage() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let currentPrompt = trimmed
        inputText = ""
        
        sendQuickReply(currentPrompt)
    }
    
    func sendQuickReply(_ prompt: String) {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        if !Connector.shared.isConnected {
            Connector.shared.doConnectToStomp()
        }
        
        Connector.shared.onSendMessage(messages: trimmed)
        
        let userMsg = Message(text: trimmed, sender: .user, timestamp: Date())
        messages.append(userMsg)
        
        state = .loading
        
        let lowercasedPrompt = trimmed.lowercased()
        if lowercasedPrompt == "tidur" {
            Task {
                try? await Task.sleep(nanoseconds: 600_000_000)
                self.state = .idle
                self.addTidurKnowledgeSourceResponse()
            }
            return
        }
        
        Task {
            try? await Task.sleep(nanoseconds: 20_000_000_000)
            if self.state == .loading {
                self.state = .idle
            }
        }
    }
    
    private func addTidurKnowledgeSourceResponse() {
        let sources = [
            KnowledgeSourceItem(
                title: "Kemenkes RI - Manfaat Tidur 8 Jam",
                snippet: "Tidur malam yang cukup (7-8 jam) dapat meningkatkan imunitas tubuh, daya ingat, dan fokus.",
                urlString: "https://kemenkes.go.id/artikel/manfaat-tidur"
            ),
            KnowledgeSourceItem(
                title: "Sleep Foundation - Sleep Hygiene Guide",
                snippet: "Panduan pola hidup sehat sebelum tidur: kurangi paparan layar gadget 1 jam sebelum tidur.",
                urlString: "https://sleepfoundation.org/sleep-hygiene"
            ),
            KnowledgeSourceItem(
                title: "Journal of Sleep Medicine - Rest & Recovery",
                snippet: "Studi mendalam perbaikan jaringan sel organ tubuh selama fase Deep Sleep.",
                urlString: "https://journalofsleepmedicine.org/rest-recovery"
            )
        ]
        
        let aiMsg = Message(
            text: "Berikut adalah informasi dan panduan mengenai kualitas tidur yang cukup untuk kesehatan tubuh dan pikiran:",
            sender: .ai,
            timestamp: Date(),
            knowledgeSources: sources,
            showFeedbackBar: true
        )
        messages.append(aiMsg)
    }
    
    func submitFeedback(for messageId: UUID, isLike: Bool, feedbackComment: String? = nil) {
        guard let idx = messages.firstIndex(where: { $0.id == messageId }) else { return }
        
        let previousLiked = messages[idx].isLiked
        let newLiked: Bool? = (previousLiked == isLike && feedbackComment == nil) ? nil : isLike
        messages[idx].isLiked = newLiked
        messages[idx].feedbackComment = feedbackComment
        
        guard let ratingState = newLiked else { return }
        let rating = ratingState ? "up" : "down"
        let serverId = messages[idx].serverId ?? messages[idx].id.uuidString
        
        Connector.shared.updateFeedback(id: serverId, rating: rating, ratingFeedback: feedbackComment) { success, error in
            if success {
                print("Feedback submitted successfully for \(serverId): \(rating)")
            } else {
                print("Failed to submit feedback for \(serverId): \(error?.localizedDescription ?? "unknown error")")
            }
        }
    }
    
    func copyMessageText(_ text: String) {
        UIPasteboard.general.string = text
        copiedMessageToast = "Tersalin ke papan klip!"
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if self.copiedMessageToast == "Tersalin ke papan klip!" {
                self.copiedMessageToast = nil
            }
        }
    }
    
    @objc private func handleIncomingMessageNotification(_ notification: Notification) {
        guard let dolphinMessage = notification.object as? DolphinMessage else { return }
        
        Task { @MainActor in
            self.processMessage(dolphinMessage)
        }
    }
    
    @objc private func handleTypingConditionNotification(_ notification: Notification) {
        Task { @MainActor in
            self.state = .loading
        }
    }

    @objc private func handleConnectionStatusNotification(_ notification: Notification) {
        guard let status = (notification.object as? Int) ?? (notification.object as? NSNumber)?.intValue else { return }
        
        Task { @MainActor in
            switch status {
            case 2: // Connected
                print("ChatViewModel: Socket connected")
                self.fetchFavoritesAndHistories()
            case 4, 5: // Disconnected / Error
                if self.state == .loading {
                    self.state = .idle
                }
            default:
                break
            }
        }
    }
    
    private func extractCarouselCards(from dolphinMessage: DolphinMessage) -> (cards: [CarouselCard]?, textOverride: String?) {
        // 1. Cek properti native carouselItems pada DolphinMessage
        if let items = dolphinMessage.carouselItems, !items.isEmpty {
            var cards: [CarouselCard] = []
            for item in items {
                let title = item.title ?? ""
                let desc = item.description ?? ""
                let img = item.imageUrl ?? "sparkles"
                let actionTitle = item.buttons?.first?.label ?? "Pilih"
                let actionPayload = item.buttons?.first?.payload ?? item.buttons?.first?.label
                cards.append(CarouselCard(
                    title: title,
                    description: desc,
                    imageName: img,
                    actionTitle: actionTitle,
                    actionPayload: actionPayload
                ))
            }
            if !cards.isEmpty {
                let rawText = dolphinMessage.message?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let fallback = rawText.isEmpty ? "Berikut adalah rekomendasi untuk Anda:" : nil
                return (cards, fallback)
            }
        }
        
        // 2. Hybrid Fallback: Parse JSON string dari dolphinMessage.message jika ada
        guard let rawMessage = dolphinMessage.message else {
            return (nil, nil)
        }
        
        let trimmed = rawMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (trimmed.hasPrefix("{") && trimmed.hasSuffix("}")) || (trimmed.hasPrefix("[") && trimmed.hasSuffix("]")),
              let data = trimmed.data(using: .utf8) else {
            return (nil, nil)
        }
        
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
            
            var cardDictionaries: [[String: Any]] = []
            var detectedText: String? = nil
            
            if let arr = jsonObject as? [[String: Any]] {
                cardDictionaries = arr
            } else if let dict = jsonObject as? [String: Any] {
                detectedText = (dict["message"] as? String) ?? (dict["text"] as? String) ?? (dict["title"] as? String)
                if let arr = (dict["cards"] as? [[String: Any]]) ??
                             (dict["carousel"] as? [[String: Any]]) ??
                             (dict["items"] as? [[String: Any]]) ??
                             (dict["elements"] as? [[String: Any]]) {
                    cardDictionaries = arr
                }
            }
            
            guard !cardDictionaries.isEmpty else {
                return (nil, nil)
            }
            
            var parsedCards: [CarouselCard] = []
            for dict in cardDictionaries {
                let title = (dict["title"] as? String) ?? (dict["name"] as? String) ?? ""
                let desc = (dict["description"] as? String) ?? (dict["desc"] as? String) ?? (dict["subtitle"] as? String) ?? ""
                let img = (dict["imageUrl"] as? String) ?? (dict["image"] as? String) ?? (dict["picture"] as? String) ?? (dict["icon"] as? String) ?? "sparkles"
                
                var actionTitle = "Pilih"
                var actionPayload: String? = nil
                
                if let action = dict["action"] as? String {
                    actionTitle = action
                    actionPayload = action
                } else if let btnText = (dict["button"] as? String) ?? (dict["actionTitle"] as? String) {
                    actionTitle = btnText
                    actionPayload = (dict["payload"] as? String) ?? btnText
                } else if let buttons = dict["buttons"] as? [[String: Any]], let firstBtn = buttons.first {
                    actionTitle = (firstBtn["label"] as? String) ?? (firstBtn["title"] as? String) ?? "Pilih"
                    actionPayload = (firstBtn["payload"] as? String) ?? (firstBtn["url"] as? String) ?? actionTitle
                }
                
                if !title.isEmpty || !desc.isEmpty {
                    parsedCards.append(CarouselCard(
                        title: title,
                        description: desc,
                        imageName: img,
                        actionTitle: actionTitle,
                        actionPayload: actionPayload
                    ))
                }
            }
            
            if !parsedCards.isEmpty {
                let fallbackText = detectedText ?? "Berikut adalah pilihan untuk Anda:"
                return (parsedCards, fallbackText)
            }
        } catch {
            // Bukan format carousel JSON, teruskan sebagai teks biasa
        }
        
        return (nil, nil)
    }
    
    private func processMessage(_ dolphinMessage: DolphinMessage) {
        let isUser = dolphinMessage.isUser == true
        if isUser {
            return
        }
        
        self.state = .idle
        
        let extraction = extractCarouselCards(from: dolphinMessage)
        let carouselCards = extraction.cards
        let text = extraction.textOverride ?? (dolphinMessage.message ?? "")
        
        guard !text.isEmpty || carouselCards != nil else { return }
        
        let serverId = dolphinMessage.id ?? dolphinMessage.transactionId
        
        let messageType = dolphinMessage.messageType ?? ""
        let isLastStreamingChunk = (messageType == "streaming_last")
        
        // Cegah duplikasi frame pesan carousel yang persis sama kecuali jika merupakan closing frame streaming_last
        if !isLastStreamingChunk,
           let lastMsg = messages.last,
           lastMsg.sender == .ai,
           let lastId = lastMsg.serverId,
           lastId == serverId,
           lastMsg.carouselCards != nil,
           carouselCards != nil {
            return
        }
        if messageType == "streaming_first" {
            let aiMsg = Message(
                serverId: serverId,
                text: text,
                sender: .ai,
                timestamp: dolphinMessage.createdDate ?? Date(),
                isStreaming: true,
                carouselCards: carouselCards,
                showFeedbackBar: false
            )
            messages.append(aiMsg)
        } else if messageType == "streaming" {
            if let lastIndex = messages.indices.last, messages[lastIndex].sender == .ai {
                messages[lastIndex].text = text
                messages[lastIndex].isStreaming = true
                if carouselCards != nil {
                    messages[lastIndex].carouselCards = carouselCards
                }
                if messages[lastIndex].serverId == nil {
                    messages[lastIndex].serverId = serverId
                }
            } else {
                let aiMsg = Message(
                    serverId: serverId,
                    text: text,
                    sender: .ai,
                    timestamp: dolphinMessage.createdDate ?? Date(),
                    isStreaming: true,
                    carouselCards: carouselCards,
                    showFeedbackBar: false
                )
                messages.append(aiMsg)
            }
        } else if messageType == "streaming_last" {
            if let lastIndex = messages.indices.last, messages[lastIndex].sender == .ai {
                messages[lastIndex].text = text
                messages[lastIndex].isStreaming = false
                messages[lastIndex].showFeedbackBar = true
                if carouselCards != nil {
                    messages[lastIndex].carouselCards = carouselCards
                }
                if messages[lastIndex].serverId == nil {
                    messages[lastIndex].serverId = serverId
                }
            } else {
                let aiMsg = Message(
                    serverId: serverId,
                    text: text,
                    sender: .ai,
                    timestamp: dolphinMessage.createdDate ?? Date(),
                    isStreaming: false,
                    carouselCards: carouselCards,
                    showFeedbackBar: true
                )
                messages.append(aiMsg)
            }
        } else {
            let aiMsg = Message(
                serverId: serverId,
                text: text,
                sender: .ai,
                timestamp: dolphinMessage.createdDate ?? Date(),
                isStreaming: false,
                carouselCards: carouselCards,
                showFeedbackBar: true
            )
            messages.append(aiMsg)
        }
    }
}
