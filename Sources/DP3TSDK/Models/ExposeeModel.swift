/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import Foundation

/// Model of the exposed person
struct ExposeeModel: Encodable {
    /// Secret key used to generate EphID (base64 encoded)
    let key: String

    /// The onset date
    let keyDate: Int

    /// Authentication data provided by health institutes to verify test results
//    let authData: String?

    let fake: Int

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        // Encode key
        try container.encode(key, forKey: .key)
        // Encode auth if present only
//        try container.encodeIfPresent(authData, forKey: .authData)
        // Compute date
//        let startOfDayTimestamp = Int(keyDate.dayMin.millisecondsSince1970)
//        try container.encode(startOfDayTimestamp, forKey: .keyDate)
        
        try container.encode(keyDate, forKey: .keyDate)

        try container.encode(fake, forKey: .fake)
//        try container.encode(fake ? 1 : 0, forKey: .fake)
    }

    enum CodingKeys: CodingKey {
        case key, keyDate/*, authData*/, fake
    }
}
