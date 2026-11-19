import Testing
import Foundation
@testable import Later_再度

struct OnboardingRouterTests {
    private let before = OnboardingRouter.legacyCutoff.addingTimeInterval(-86400)
    private let after = OnboardingRouter.legacyCutoff.addingTimeInterval(86400)

    @Test func onboardedAtMeansFinished() {
        #expect(OnboardingRouter.gate(name: "れな", onboardedAt: Date(), recordCreatedAt: after) == .finished)
        #expect(OnboardingRouter.gate(name: "", onboardedAt: Date(), recordCreatedAt: nil) == .finished)
    }
    @Test func oldRecordWithNameIsLegacyFinished() {
        #expect(OnboardingRouter.gate(name: "れな", onboardedAt: nil, recordCreatedAt: before) == .legacyFinished)
    }
    @Test func newRecordWithoutOnboardedAtResumes() {
        #expect(OnboardingRouter.gate(name: "れな", onboardedAt: nil, recordCreatedAt: after) == .resume)
    }
    @Test func emptyNameOrNoRecordResumes() {
        #expect(OnboardingRouter.gate(name: " ", onboardedAt: nil, recordCreatedAt: before) == .resume)
        #expect(OnboardingRouter.gate(name: "れな", onboardedAt: nil, recordCreatedAt: nil) == .resume)
    }
    @Test func resumeTable() {
        #expect(OnboardingRouter.resume(saved: "", signedIn: true) == nil)
        #expect(OnboardingRouter.resume(saved: "id", signedIn: true) == .id)
        #expect(OnboardingRouter.resume(saved: "tag", signedIn: false) == .signin)
        #expect(OnboardingRouter.resume(saved: "go", signedIn: true) == .go)
        #expect(OnboardingRouter.resume(saved: "in", signedIn: true) == .name)
        #expect(OnboardingRouter.resume(saved: "mail", signedIn: true) == .name)
        #expect(OnboardingRouter.resume(saved: "zzz", signedIn: true) == .name)
    }
}
