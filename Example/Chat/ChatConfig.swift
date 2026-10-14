//
//  ChatConfig.swift
//  Example
//

import Foundation

/// Environment deployment untuk livechat
enum AppEnvironment: String, CaseIterable {
    case devops
    case beta
    case driver
    case production
}

struct ChatConfig {
    let baseUrl: String
    let clientId: String
    let clientSecret: String
    var botId: String
    var generativeBaseUrl: String
    var jwtToken: String? // Opsional: JWT Bearer token khusus untuk Generative History API
    var customGraphAuthUrl: String?
    var graphUsername: String
    var graphPassword: String
    
    /// Otomatis menghitung URL auth graph jika tidak ditentukan secara custom
    var graphAuthUrl: String {
        return customGraphAuthUrl ?? "\(generativeBaseUrl)/dolphin/apiv1/graph/auth"
    }
    
    init(
        baseUrl: String,
        clientId: String,
        clientSecret: String,
        botId: String = "9a85edecbc9393858367a0f918e7022f",
        generativeBaseUrl: String = "https://apollo.3dolphins.ai:9443",
        jwtToken: String? = nil,
        graphAuthUrl: String? = nil,
        graphUsername: String = "admin@inmotion.co.id",
//        graphUsername: String = "api@inmotion.co.id",
        graphPassword: String = "admin@Dolphin123"
    ) {
        self.baseUrl = baseUrl
        self.clientId = clientId
        self.clientSecret = clientSecret
        self.botId = botId
        self.generativeBaseUrl = generativeBaseUrl
        self.jwtToken = jwtToken
        self.customGraphAuthUrl = graphAuthUrl
        self.graphUsername = graphUsername
        self.graphPassword = graphPassword
    }
    
    // Konfigurasi Environment Tersedia
    static let devops = ChatConfig(
        baseUrl: "https://devops.3dolphins.ai:31418",
        clientId: "f181392d7b4f13ec1903d6359edf0cf2",
        clientSecret: "0a105a36837fd92504c9b9a1ad8d36a5"
    )
    
    static let beta = ChatConfig(
        baseUrl: "https://beta.3dolphins.ai:31512",
        clientId: "bf8f1e7ea3e0ea87b853a6f5cc76cd1e",
        clientSecret: "d927e2b0c07c92a2a5a8dbfd91007e80"
    )
    
    static let driver = ChatConfig(
        baseUrl: "https://driver.3dolphins.ai:31418",
        clientId: "f181392d7b4f13ec1903d6359edf0cf2",
        clientSecret: "0a105a36837fd92504c9b9a1ad8d36a5"
    )
    
    static let production = ChatConfig(
        baseUrl: "https://apollo.3dolphins.ai:30000",
        clientId: "97fe0ba2893026e5928737c9666cbcfc",
        clientSecret: "b6cff274d38b6ce05503765644c551f8"
    )
    
    /// Environment yang sedang aktif (default: .devops untuk testing streaming chat & carousel)
    static var activeEnvironment: AppEnvironment = .devops
    
    static var current: ChatConfig {
        switch activeEnvironment {
        case .devops:
            return devops
        case .beta:
            return beta
        case .driver:
            return driver
        case .production:
            return production
        }
    }
    
    /// Helper untuk mengubah environment secara dinamis
    static func setEnvironment(_ env: AppEnvironment) {
        activeEnvironment = env
    }
}
