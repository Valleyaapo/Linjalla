import Foundation

struct RouteSelection: Sendable {
    let id: String
    let routeId: String
}

struct SubscriptionChange: Sendable {
    let requestId: UInt64
    let newTopics: Set<String>
    let toSubscribe: [String]
    let toUnsubscribe: [String]
}

actor VehicleStream {
    private var pendingUpdates: [Int: BusModel] = [:]
    private var currentSubscriptions: Set<String> = []
    private var subscriptionGeneration: UInt64 = 0

    func buffer(_ vehicle: BusModel) {
        pendingUpdates[vehicle.id] = vehicle
    }

    func drain() -> [Int: BusModel] {
        let copy = pendingUpdates
        pendingUpdates.removeAll()
        return copy
    }

    func subscriptionChange(selections: [RouteSelection], topicPrefix: String) -> SubscriptionChange {
        subscriptionGeneration += 1

        let routeTopics = selections.flatMap { selection in
            let routeIds = Set([selection.routeId, selection.id, selection.id.replacingOccurrences(of: "HSL:", with: "")])
            return routeIds.flatMap { routeId in
                [
                    "/hfp/v2/journey/ongoing/vp/\(topicPrefix)/+/+/\(routeId)/#",
                    "/hfp/v2/journey/ongoing/vp/\(topicPrefix)/+/+/+/\(routeId)/#"
                ]
            }
        }

        let newTopics = Set(routeTopics)
        let toSubscribe = Array(newTopics.subtracting(currentSubscriptions))
        let toUnsubscribe = Array(currentSubscriptions.subtracting(newTopics))

        return SubscriptionChange(
            requestId: subscriptionGeneration,
            newTopics: newTopics,
            toSubscribe: toSubscribe,
            toUnsubscribe: toUnsubscribe
        )
    }

    func applySubscriptionUpdate(requestId: UInt64, newTopics: Set<String>) -> Bool {
        guard requestId == subscriptionGeneration else { return false }
        currentSubscriptions = newTopics
        return true
    }

    func clearSubscriptions() {
        currentSubscriptions.removeAll()
    }
}
