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
    let id: UUID
    let title: String
    let description: String
    let imageName: String
    let actionTitle: String
    var actionPayload: String?
    
    init(
        id: UUID? = nil,
        title: String,
        description: String,
        imageName: String,
        actionTitle: String,
        actionPayload: String? = nil
    ) {
        if let explicitId = id {
            self.id = explicitId
        } else {
            let contentKey = "\(title)|\(description)|\(imageName)|\(actionTitle)|\(actionPayload ?? "")"
            var hashValue: UInt64 = 14695981039346656037
            for byte in contentKey.utf8 {
                hashValue ^= UInt64(byte)
                hashValue = hashValue &* 1099511628211
            }
            let lengthValue = UInt64(contentKey.count)
            self.id = UUID(uuid: (
                UInt8(truncatingIfNeeded: hashValue >> 56), UInt8(truncatingIfNeeded: hashValue >> 48),
                UInt8(truncatingIfNeeded: hashValue >> 40), UInt8(truncatingIfNeeded: hashValue >> 32),
                UInt8(truncatingIfNeeded: hashValue >> 24), UInt8(truncatingIfNeeded: hashValue >> 16),
                UInt8(truncatingIfNeeded: hashValue >> 8),  UInt8(truncatingIfNeeded: hashValue),
                UInt8(truncatingIfNeeded: lengthValue >> 56), UInt8(truncatingIfNeeded: lengthValue >> 48),
                UInt8(truncatingIfNeeded: lengthValue >> 40), UInt8(truncatingIfNeeded: lengthValue >> 32),
                UInt8(truncatingIfNeeded: lengthValue >> 24), UInt8(truncatingIfNeeded: lengthValue >> 16),
                UInt8(truncatingIfNeeded: lengthValue >> 8),  UInt8(truncatingIfNeeded: lengthValue)
            ))
        }
        self.title = title
        self.description = description
        self.imageName = imageName
        self.actionTitle = actionTitle
        self.actionPayload = actionPayload
    }
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
