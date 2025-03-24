import MixpanelVapor
import Vapor

protocol AnalyticsService {
    func `for`(_ request: Request) -> AnalyticsService
    func track(profileId: UUID?, name: String, params: [String: MixpanelProperty])
    func peopleSet(
        profileId: UUID, setParams: [String: MixpanelProperty]) async
    func peopleDelete(profileId: UUID) async
}

extension AnalyticsService {
    func track(profileId: UUID?, name: String, params: [String: String]) {
        track(profileId: profileId, name: name, params: params.mapValues { .string($0) })
    }

    func peopleSet(
        profileId: UUID, setParams: [String: String]
    ) async {
        await peopleSet(profileId: profileId, setParams: setParams.mapValues { .string($0) })
    }
}

final class NoOpAnalyticsService: AnalyticsService {

    func `for`(_ request: Vapor.Request) -> any AnalyticsService {
        NoOpAnalyticsService()
    }

    func track(profileId: UUID?, name: String, params: [String: MixpanelProperty]) {
        // Do nothing
    }

    func peopleSet(
        profileId: UUID, setParams: [String: MixpanelProperty]
    ) async {

    }

    func peopleDelete(profileId: UUID) async {

    }
}

struct MixpanelAnalyticsService: AnalyticsService {

    private let mixpanel: Application.MixpanelClient
    private let request: Request?

    init(mixpanel: Application.MixpanelClient, request: Request? = nil) {
        self.mixpanel = mixpanel
        self.request = request
    }

    func `for`(_ request: Vapor.Request) -> any AnalyticsService {
        MixpanelAnalyticsService(mixpanel: request.mixpanel, request: request)
    }

    func track(profileId: UUID?, name: String, params: [String: MixpanelProperty]) {
        mixpanel.track(
            distinctId: profileId?.uuidString, name: name, request: request, params: params)
    }

    func peopleSet(
        profileId: UUID, setParams: [String: MixpanelProperty]
    ) async {
        await mixpanel.peopleSet(
            distinctId: profileId.uuidString, request: request, setParams: setParams)
    }

    func peopleDelete(profileId: UUID) async {
        await mixpanel.peopleDelete(distinctId: profileId.uuidString)
    }
}

extension Application.Services {
    var analyticsService: Application.Service<AnalyticsService> {
        .init(application: self.application)
    }
}

extension Request.Services {
    var analyticsService: AnalyticsService {
        self.request.application.services.analyticsService.service.for(request)
    }
}
