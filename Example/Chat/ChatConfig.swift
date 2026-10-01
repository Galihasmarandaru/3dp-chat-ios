//
//  ChatConfig.swift
//  Example
//

import Foundation

/// Environment deployment untuk livechat
enum AppEnvironment: String, CaseIterable {
    case beta
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
    static let beta = ChatConfig(
        baseUrl: "https://beta.3dolphins.ai:31512",
        clientId: "bf8f1e7ea3e0ea87b853a6f5cc76cd1e",
        clientSecret: "d927e2b0c07c92a2a5a8dbfd91007e80"
    )
    
    static let production = ChatConfig(
        baseUrl: "https://apollo.3dolphins.ai:30000",
        clientId: "97fe0ba2893026e5928737c9666cbcfc",
        clientSecret: "b6cff274d38b6ce05503765644c551f8"
    )
    
    /// Environment yang sedang aktif (default: .beta, ganti ke .production untuk live server)
    static var activeEnvironment: AppEnvironment = .beta
    
    static var current: ChatConfig {
        switch activeEnvironment {
        case .beta:
            return beta
        case .production:
            return production
        }
    }
    
    /// Helper untuk mengubah environment secara dinamis
    static func setEnvironment(_ env: AppEnvironment) {
        activeEnvironment = env
    }
}
