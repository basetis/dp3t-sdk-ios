/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import Foundation

/**
 Synchronizes data on known cases
 */
class KnownCasesSynchronizer {
    /// The app id to use
    private let appInfo: DP3TApplicationInfo
    /// A database to store the known cases
    private let database: KnownCasesStorage

    private var defaults: DefaultStorage

    /// A DP3T matcher
    private weak var matcher: DP3TMatcherProtocol?

    /// Create a known case synchronizer
    /// - Parameters:
    ///   - appId: The app id to use
    ///   - database: The database for storage
    ///   - matcher: The matcher for DP3T resolution and checks
    init(appInfo: DP3TApplicationInfo,
         database: DP3TDatabase,
         matcher: DP3TMatcherProtocol,
         defaults: DefaultStorage = Default.shared) {
        self.appInfo = appInfo
        self.database = database.knownCasesStorage
        self.matcher = matcher
        self.defaults = defaults
    }

    /// A callback result of async operations
    typealias Callback = (Result<Void, DP3TNetworkingError>) -> Void

    /// Synchronizes the local database with the remote one
    /// - Parameters:
    ///   - service: The service to use for synchronization
    ///   - callback: The callback once the task if finished
    /// - Returns: the operation which can be used to cancel the sync
    @discardableResult
    func sync(service: ExposeeServiceClientProtocol, now: Date = Date(), forceManually: Bool, callback: Callback?) -> Operation {
        let queue = OperationQueue()

        let operation = BlockOperation {
            self.internalSync(service: service, now: now, forceManually: forceManually, callback: callback)
        }

        queue.addOperation(operation)

        return operation
    }

    /// Stores the first SDK launch date
    @discardableResult
    static func initializeSynchronizerIfNeeded(defaults: DefaultStorage = Default.shared) -> Date {
        guard defaults.lastLoadedBatchReleaseTime == nil else { return defaults.lastLoadedBatchReleaseTime! }
        let nowTimestamp = Date().timeIntervalSince1970
        let lastBatch = Date(timeIntervalSince1970: nowTimestamp - nowTimestamp.truncatingRemainder(dividingBy: Default.shared.parameters.networking.batchLength))
        var mutableDefaults = defaults
        mutableDefaults.lastLoadedBatchReleaseTime = lastBatch
        return lastBatch
    }

    private func internalSync(service: ExposeeServiceClientProtocol, now: Date = Date(), forceManually: Bool, callback: Callback?) {
        let nowTimestamp = now.timeIntervalSince1970

        var lastBatch: TimeInterval!
        if let storedLastBatch = defaults.lastLoadedBatchReleaseTime,
            storedLastBatch < Date() {
            lastBatch = storedLastBatch.timeIntervalSince1970
        } else {
            assert(false, "This should never happen if initializeSynchronizerIfNeeded gets called on SDK init")
            lastBatch = KnownCasesSynchronizer.initializeSynchronizerIfNeeded().timeIntervalSince1970
        }
        
        print("lastBatch \(Date(timeIntervalSince1970: lastBatch).millisecondsSince1970)")
        let batchesToLoad = Int((nowTimestamp - lastBatch) / Default.shared.parameters.networking.batchLength)
        print("batchesToLoad: \(batchesToLoad)")

        let nextBatch = lastBatch + Default.shared.parameters.networking.batchLength
        print("nextBatch: \(Date(timeIntervalSince1970: nextBatch).millisecondsSince1970)")

        let finalIndex = (forceManually ? batchesToLoad+1 : batchesToLoad)
        print("finalIndex: \(finalIndex)")
        for batchIndex in 0 ..< finalIndex {
            let currentReleaseTime = Date(timeIntervalSince1970: nextBatch + Default.shared.parameters.networking.batchLength * TimeInterval(batchIndex))
            let result = service.getExposeeSynchronously(batchTimestamp: currentReleaseTime)
            print(result)
            switch result {
            case let .failure(error):
                callback?(.failure(error))
                return
            case let .success(knownCases):
                print("KNOWN CASES")
                print(knownCases)
                if let knownCases = knownCases {
                    try? database.update(knownCases: knownCases)
                    for knownCase in knownCases {
                        try? matcher?.checkNewKnownCase(knownCase)
                    }
                }
                if batchIndex != batchesToLoad {
                    defaults.lastLoadedBatchReleaseTime = currentReleaseTime
                }
            }
        }

        callback?(.success(()))
    }
}
