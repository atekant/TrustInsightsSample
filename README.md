# Trust Insights sample: SevenStrikes Bank

A one-screen UIKit app that shows how to use Trust Insights, the iOS 27
framework that tells your app when it looks like someone is coaching the
person through what they are doing. The fictional SevenStrikes Bank checks
a £2,400 transfer before it goes through.

The sample is short on purpose. Everything that touches the API is in one
file, in the order you meet it. The rest is one screen and boilerplate.

The background, and why your app should adopt this, is in the article:
[Trust Insights, or how your app can tell when someone is being talked through a scam](https://7strikes.dev/articles/trust-insights/).

## What you need

- Xcode 27 and an iPhone running iOS 27. Trust Insights needs internet
  access, and evaluation runs partly on the device and partly on Apple's
  servers. The simulator returns `.unavailable`, so you need a device to see
  anything happen.
- Your own team. Select it under Signing & Capabilities, then add the
  **Trust Insights** capability, which fills in the
  `com.apple.developer.trustinsights.base` entitlement.
- On the iPhone, Settings > Privacy & Security > Impersonation Risk
  Detection turned on. With it off, for the app or for everything,
  `authorizationStatus(for:)` returns `.denied`. If the app reports
  `.unavailable` on a real device with the capability added, the causes Apple
  lists that remain are an unsupported device or region.

While you develop, requests go to Apple's sandbox. A build from the App
Store gets the production models.

## Where things are

| File | What it holds |
|---|---|
| `TrustInsightsCheck.swift` | All of the API, in five numbered steps |
| `TransferViewController.swift` | The screen: when to start the check, and what to do with the answer |
| `App/AppDelegate.swift` | Boilerplate |

The five steps in `TrustInsightsCheck.swift`:

1. **Describe the operation.** An `InsightContext` with the category
   (`.payment` here) and the one insight the sample asks for,
   `IsLikelyBeingCoachedInsight`.
2. **Ask for permission, at a calm moment.** From a settings action, after
   explaining what it does. Never in the middle of a transfer, where a
   scammer on the phone would tell the person to tap Not Now. The app reads
   the status that comes back, and only sends the person to Settings when
   Settings can help.
3. **Request an evaluation.** Started when the transfer screen appears, so
   the seconds it takes pass while the person reads. Every
   authorization status and every error is handled, and each one ends with
   the app falling back to its own checks.
4. **Decide, and report.** `unknown` leaves friction as it was, `medium`
   warns, `high` holds the transfer. Every evaluation is reported with
   `reportConsumption` exactly once, on every branch, including a cancelled
   transfer. An app that skips this may be rate-limited or lose access to
   the service.
5. **Record what happened.** The result, the friction and the evaluation's
   `eventID`, kept with the transfer in your own records. The sample logs
   them.

## Everything happens in the app

Apple's WWDC26 session describes the integration as entirely client-side,
and this sample keeps it that way. Your server, your Android app and your
fraud pipeline do not change. The app asks before the transfer, warns or
holds, and records what it did, like any other check it already runs.

Because the decision is made in the app, the sample only ever adds
friction. Anyone who can change the app can change what it reads, and a
faked `unknown` only removes friction the sample never takes away. Using a
result to skip one of your own checks needs a result your server can trust,
and that is outside what this sample covers.

The evaluation also carries a `signedPayload`, which Apple's documentation
describes as data for server-side validation. As of November 2026 the
details a server needs to check it are not public, so the sample does not
use it.

## What you cannot test well

You can run the whole flow on a device, but you cannot make it see a scam.
Apple does not say what behaviour it treats as coaching, so there is no way
to set up the conditions for a `medium` or a `high` result on purpose. The
WWDC26 session says the values and errors can be overridden with launch
arguments in the scheme, and refers to the documentation for the list. As
of November 2026 the documentation does not list them, so the sample has no
overrides. When Apple documents them, they go in the shared scheme.

Until then, how much weight a `medium` or a `high` gets is the bank's call.
Watch what happens to the transfers that got each value, and tell Apple
through Feedback Assistant where the results do not match what your fraud
team sees. The model only gets better if the banks using it say where it
is wrong.

## More

- [Trust Insights](https://developer.apple.com/documentation/trustinsights), Apple's documentation
- [Meet Trust Insights](https://developer.apple.com/videos/play/wwdc2026/379/), WWDC26
- [Trust Insights: Detect Coerced Actions In Sensitive iOS Flows](https://www.theswift.dev/posts/trust-insights-sensitive-ios-flows/), The Swift Dev, for the design side

## Licence

MIT. See [LICENSE](LICENSE).
