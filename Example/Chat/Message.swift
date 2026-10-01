//
//  Message.swift
//  Example
//

import Foundation
import SwiftUI

enum SenderRole: String, Codable, Equatable {
    case user
    case ai
}

struct CarouselCard: Identifiable, Equatable {
    let id: UUID = UUID()
    let title: String
    let description: String
    let imageName: String
    let actionTitle: String
}

struct KnowledgeSourceItem: Identifiable, Equatable {
    let id: UUID = UUID()
    let title: String
    let snippet: String
    let urlString: String
}

struct Message: Identifiable, Equatable {
    let id: UUID
    var serverId: String?
    var text: String
    let sender: SenderRole
    let timestamp: Date
    var isStreaming: Bool
    
    // New Feature Components
    var carouselCards: [CarouselCard]?
    var knowledgeSources: [KnowledgeSourceItem]?
    var showFeedbackBar: Bool
    
    // Reaction & Copy State
    var isLiked: Bool? // nil = no vote, true = thumbs up, false = thumbs down
    var feedbackComment: String?
    
    init(
        id: UUID = UUID(),
        serverId: String? = nil,
        text: String,
        sender: SenderRole,
        timestamp: Date = Date(),
        isStreaming: Bool = false,
        carouselCards: [CarouselCard]? = nil,
        knowledgeSources: [KnowledgeSourceItem]? = nil,
        showFeedbackBar: Bool = true,
        isLiked: Bool? = nil,
        feedbackComment: String? = nil
    ) {
        self.id = id
        self.serverId = serverId
        self.text = text
        self.sender = sender
        self.timestamp = timestamp
        self.isStreaming = isStreaming
        self.carouselCards = carouselCards
        self.knowledgeSources = knowledgeSources
        self.showFeedbackBar = showFeedbackBar && (sender == .ai)
        self.isLiked = isLiked
        self.feedbackComment = feedbackComment
    }
}
