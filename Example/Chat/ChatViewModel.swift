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

    func loadHistoryChat(sessionId: String) {
        loadHistoryChat(conversationId: sessionId, title: nil)
    }

    
    func sendMessage() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let currentPrompt = trimmed
        inputText = ""
        
        if !Connector.shared.isConnected {
            Connector.shared.doConnectToStomp()
        }
        
        Connector.shared.onSendMessage(messages: currentPrompt)
        
        let userMsg = Message(text: currentPrompt, sender: .user, timestamp: Date())
        messages.append(userMsg)
        
        state = .loading
        
        let lowercasedPrompt = currentPrompt.lowercased()
        if lowercasedPrompt == "makan" {
            Task {
                try? await Task.sleep(nanoseconds: 600_000_000)
                self.state = .idle
                self.addMakanCarouselResponse()
            }
            return
        }
        
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
    
    private func addMakanCarouselResponse() {
        let cards = [
            CarouselCard(
                title: "Nasi Goreng Spesial",
                description: "Nasi goreng lezat khas rempah pilihan dengan telur mata sapi dan emping renyah.",
                imageName: "fork.knife",
                actionTitle: "Pilih Menu"
            ),
            CarouselCard(
                title: "Sate Ayam Madura",
                description: "Sate ayam empuk dengan bumbu kacang gurih melimpah dan lontong hangat.",
                imageName: "takeoutbag.and.cup.and.straw",
                actionTitle: "Pilih Menu"
            ),
            CarouselCard(
                title: "Soto Ayam Lamongan",
                description: "Soto ayam kuah kuning segar beraroma rempah dengan taburan koya gurih.",
                imageName: "cup.and.saucer",
                actionTitle: "Pilih Menu"
            ),
            CarouselCard(
                title: "Rendang Sapi Padang",
                description: "Daging sapi olahan santan dan bumbu rempah asli Minang yang kaya rasa.",
                imageName: "wineglass",
                actionTitle: "Pilih Menu"
            ),
            CarouselCard(
                title: "Es Cendol Dawet",
                description: "Minuman segar es santan gurih, gula merah manis cair, dan cendol hijau pandan.",
                imageName: "mug",
                actionTitle: "Pilih Menu"
            )
        ]
        
        let aiMsg = Message(
            text: "Berikut adalah 5 rekomendasi menu makanan dan minuman terbaik untuk Anda:",
            sender: .ai,
            timestamp: Date(),
            carouselCards: cards,
            showFeedbackBar: true
        )
        messages.append(aiMsg)
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
    
    func toggleLike(for messageId: UUID, isLike: Bool) {
        submitFeedback(for: messageId, isLike: isLike, feedbackComment: nil)
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
    
    private func processMessage(_ dolphinMessage: DolphinMessage) {
        let isUser = dolphinMessage.isUser == true
        let text = dolphinMessage.message ?? ""
        
        guard !text.isEmpty else { return }
        
        if isUser {
            return
        } else {
            self.state = .idle

            if let lastMsg = messages.last, lastMsg.sender == .ai && (lastMsg.carouselCards != nil || lastMsg.knowledgeSources != nil) {
                return
            }
            
            let serverId = dolphinMessage.id ?? dolphinMessage.transactionId
            let messageType = dolphinMessage.messageType ?? ""
            if messageType == "streaming_first" {
                let aiMsg = Message(serverId: serverId, text: text, sender: .ai, timestamp: dolphinMessage.createdDate ?? Date(), isStreaming: true, showFeedbackBar: false)
                messages.append(aiMsg)
            } else if messageType == "streaming" {
                if let lastIndex = messages.indices.last, messages[lastIndex].sender == .ai {
                    messages[lastIndex].text = text
                    messages[lastIndex].isStreaming = true
                    if messages[lastIndex].serverId == nil {
                        messages[lastIndex].serverId = serverId
                    }
                } else {
                    let aiMsg = Message(serverId: serverId, text: text, sender: .ai, timestamp: dolphinMessage.createdDate ?? Date(), isStreaming: true, showFeedbackBar: false)
                    messages.append(aiMsg)
                }
            } else if messageType == "streaming_last" {
                if let lastIndex = messages.indices.last, messages[lastIndex].sender == .ai {
                    messages[lastIndex].text = text
                    messages[lastIndex].isStreaming = false
                    messages[lastIndex].showFeedbackBar = true
                    if messages[lastIndex].serverId == nil {
                        messages[lastIndex].serverId = serverId
                    }
                } else {
                    let aiMsg = Message(serverId: serverId, text: text, sender: .ai, timestamp: dolphinMessage.createdDate ?? Date(), isStreaming: false, showFeedbackBar: true)
                    messages.append(aiMsg)
                }
            } else {
                let aiMsg = Message(serverId: serverId, text: text, sender: .ai, timestamp: dolphinMessage.createdDate ?? Date(), isStreaming: false, showFeedbackBar: true)
                messages.append(aiMsg)
            }
        }
    }
}
