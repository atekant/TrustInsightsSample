import Foundation
import os
import TrustInsights

/// A request for the one insight this sample asks for.
typealias CoachingRequest = InsightEvaluator.InsightRequest<IsLikelyBeingCoachedInsight>
/// The context holding that request. The API takes a parameter pack; this sample passes one request.
typealias CoachingContext = InsightEvaluator.InsightContext<CoachingRequest>
/// The evaluation that comes back.
typealias CoachingEvaluation = InsightEvaluation<IsLikelyBeingCoachedInsight>

/// What the app puts between the person and the transfer.
enum Friction {
    /// The normal confirmation. Whatever checks the app already had still apply.
    case none
    /// A warning that names the scam before the transfer goes through.
    case warn
    /// Stop, and check with the person outside the app.
    case hold
}

/// Everything this sample does with Trust Insights, in the order you meet it.
enum TrustInsightsCheck {
    private static let log = Logger(subsystem: "com.example.SevenStrikesBank", category: "TrustInsights")

    // MARK: 1. Describe the operation

    /// Builds the context for a transfer.
    ///
    /// The category tells the model what the person is about to do. The others are `.account` (email, password,
    /// recovery details), `.resourceUse`, `.communication` and `.other`.
    static func context() -> CoachingContext {
        InsightEvaluator.InsightContext(
            operationCategory: .payment,
            requestedEvaluations: IsLikelyBeingCoachedInsight.request(schema: .version1),
        )
    }

    // MARK: 2. Ask for permission, at a calm moment

    /// Asks the person to allow Trust Insights, and returns the status that comes back.
    ///
    /// Call this from a deliberate action, such as a settings row, after explaining what it does. Never in the
    /// middle of a transfer, where a scammer on the phone would tell the person to tap Not Now. The caller needs the
    /// status itself, because there is no point sending someone to Settings when the answer is `.unavailable`.
    static func requestAuthorization(for context: CoachingContext) async -> InsightEvaluator.AuthorizationStatus? {
        try? await InsightEvaluator().requestAuthorization(for: context)
    }

    // MARK: 3. Request an evaluation

    /// Requests an evaluation, or returns `nil` when there is none to be had.
    ///
    /// The result comes back as the return value of this call. There is no delegate, notification or extension.
    /// The session says it takes a couple of seconds and the documentation says several, and it needs internet
    /// access, so start it early (see `TransferViewController`).
    /// While you develop, requests go to Apple's sandbox; an App Store build gets the production models.
    /// A production app should also stop waiting after a deadline of its own and go ahead on its usual checks.
    static func evaluate(_ context: CoachingContext) async -> CoachingEvaluation? {
        let evaluator = InsightEvaluator()
        do {
            switch try await evaluator.authorizationStatus(for: context) {
            case .authorized:
                break
            case .notDetermined, .deniedRequestable:
                // The app may ask, but from step 2, not here.
                return nil
            case .denied:
                // The app may not ask. The person can turn it on in Settings.
                return nil
            case .unavailable:
                // The app may not ask, and Settings may not help: Apple lists unsupported devices, a missing
                // entitlement and regions where the framework is not available.
                return nil
            @unknown default:
                return nil
            }
            return try await evaluator.requestEvaluation(context: context)
        } catch let error as InsightEvaluator.EvaluationError {
            // A thrown error means there is no evaluation, and so nothing to report.
            switch error {
            case .contextInvalid(let detail):
                log.fault("Invalid request, a bug to fix: \(detail, privacy: .public)")
            case .denied:
                log.notice("Evaluation denied")
            case .notAvailable:
                log.notice("Trust Insights is not available")
            case .rateLimitExceeded:
                log.notice("Rate limited. Unreported evaluations are one cause.")
            case .serverError, .localError:
                log.notice("Transient failure. Try again on the next transfer, not in a loop.")
            case .payloadSecurityError:
                log.error("The payload should not be trusted, and may have been tampered with")
            @unknown default:
                log.error("Unknown error: \(String(describing: error), privacy: .public)")
            }
            return nil
        } catch {
            log.error("Unexpected error: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    // MARK: 4. Decide, and report what you decided

    /// Chooses the friction, and reports the choice to Trust Insights.
    ///
    /// Every evaluation must be reported exactly once, or the app may be rate-limited or lose access to the service.
    /// Each branch below reports.
    ///
    /// The decision is made in the app, so it only ever adds friction. Anyone who can change the app can change what
    /// it reads here, and faking `unknown` only removes friction this sample never takes away.
    static func decide(_ evaluation: CoachingEvaluation?) -> Friction {
        // No evaluation: no permission, no network, or an error. The app's own checks decide, as before.
        guard let evaluation else { return .none }

        switch evaluation.insight.outcome {
        case .success(.unknown):
            // No evidence of coaching. That is not evidence of safety, so friction stays as it was.
            evaluation.reportConsumption(.usedUnchangedFriction, insightsUsed: [evaluation.insight])
            return .none
        case .success(.medium):
            evaluation.reportConsumption(.usedIncreasedFriction, insightsUsed: [evaluation.insight])
            return .warn
        case .success(.high):
            evaluation.reportConsumption(.usedIncreasedFriction, insightsUsed: [evaluation.insight])
            return .hold
        case .success:
            // A level newer than this sample. Do not guess what it means.
            evaluation.reportConsumption(.notUsedError)
            return .none
        case .failure(let error):
            // The evaluation came back, but the insight inside it failed. It still has to be reported.
            log.notice("Insight failed: \(String(describing: error), privacy: .public)")
            evaluation.reportConsumption(.notUsedError)
            return .none
        }
    }

    /// Reports an evaluation the app did not need, because the person cancelled before confirming.
    static func discard(_ evaluation: CoachingEvaluation?) {
        evaluation?.reportConsumption(.notUsedNotNeeded)
    }

    // MARK: 5. Record what happened

    /// Writes down the result and what the app did with it. This sample only logs.
    ///
    /// Keep it with the transfer in your own records. Your fraud team needs to see, later, what happened to the
    /// transfers that got each result: that is how a bank works out how much weight `medium` deserves. Keep the
    /// `eventID` as well, which is what Apple's documentation says to report if fraud is discovered later.
    static func record(_ evaluation: CoachingEvaluation?, transactionID: String, friction: Friction) {
        let result = evaluation.map { String(describing: $0.insight.outcome) } ?? "no evaluation"
        let eventID = evaluation?.eventID ?? "none"
        log.info("""
            Transfer \(transactionID, privacy: .public): \(result, privacy: .public), \
            friction \(String(describing: friction), privacy: .public), event \(eventID, privacy: .public)
            """)
    }
}
