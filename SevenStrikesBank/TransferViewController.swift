import UIKit

/// The sample's only screen: review a transfer, then confirm or cancel it.
final class TransferViewController: UIViewController {
    /// The transfer on screen. In a real app these come from your server.
    private let amount = "£2,400.00"
    private let payee = "J. Morgan"
    /// Identifies this transfer. In a real app your server issues it.
    private var transactionID = UUID().uuidString
    /// The evaluation in progress, started as soon as the screen appears.
    private var pending: Task<CoachingEvaluation?, Never>?

    private lazy var confirmButton = button("Confirm", .filled()) { [weak self] in self?.confirm() }
    private lazy var cancelButton = button("Cancel", .plain()) { [weak self] in self?.cancel() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Send money"
        view.backgroundColor = .systemBackground
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Scam Protection",
            primaryAction: UIAction { [weak self] _ in self?.offerProtection() },
        )

        let summary = UILabel()
        summary.text = "Send \(amount) to \(payee), account ending 4417."
        summary.font = .preferredFont(forTextStyle: .title3)
        summary.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [summary, confirmButton, cancelButton])
        stack.axis = .vertical
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if pending == nil { startEvaluation() }
    }

    /// Starts the evaluation now, not on Confirm. It takes seconds; reading the screen usually takes longer.
    private func startEvaluation() {
        let context = TrustInsightsCheck.context()
        pending = Task { await TrustInsightsCheck.evaluate(context) }
    }

    /// Waits for the evaluation if it is not back yet, then applies the friction it calls for.
    private func confirm() {
        guard let pending else { return }
        confirmButton.isEnabled = false
        Task {
            let evaluation = await pending.value
            let friction = TrustInsightsCheck.decide(evaluation)
            TrustInsightsCheck.record(evaluation, transactionID: transactionID, friction: friction)
            show(friction)
        }
    }

    /// The person gave up before confirming, so the evaluation was not needed. It is still reported.
    private func cancel() {
        guard let pending else { return }
        Task {
            TrustInsightsCheck.discard(await pending.value)
            reset()
        }
    }

    /// Shows the friction. A real app would also delay "Continue Anyway", and hold the transfer in its own systems.
    private func show(_ friction: Friction) {
        let sent = "\(amount) is on its way to \(payee)."
        switch friction {
        case .none:
            alert("Sent", sent, endsTransfer: true)
        case .warn:
            let warning = UIAlertController(
                title: "Is someone telling you to do this?",
                message: "We will never ask you to move money to keep it safe. If anyone has, stop and call us.",
                preferredStyle: .alert,
            )
            let stop = UIAlertAction(title: "Cancel Transfer", style: .default) { [weak self] _ in self?.reset() }
            warning.addAction(stop)
            warning.addAction(UIAlertAction(title: "Continue Anyway", style: .destructive) { [weak self] _ in
                self?.alert("Sent", sent, endsTransfer: true)
            })
            warning.preferredAction = stop
            present(warning, animated: true)
        case .hold:
            alert("Transfer paused", "We will call you on the number we have for you. If someone is telling you to "
                  + "do this, hang up.", endsTransfer: true)
        }
    }

    /// Explains scam protection and asks for permission. The calm moment Apple's API expects.
    private func offerProtection() {
        let context = TrustInsightsCheck.context()
        let explainer = UIAlertController(
            title: "Scam Protection",
            message: "iPhone can warn us when it looks like someone is talking you through a payment. "
                + "We get a risk level, not the information iPhone used to work it out.",
            preferredStyle: .alert,
        )
        explainer.addAction(UIAlertAction(title: "Not Now", style: .cancel))
        explainer.addAction(UIAlertAction(title: "Turn On", style: .default) { [weak self] _ in
            Task {
                let allowed = await TrustInsightsCheck.requestAuthorization(for: context)
                if !allowed {
                    self?.alert("Scam Protection", "You can turn it on in Settings > Privacy & Security > "
                                + "Impersonation Risk Detection.")
                }
            }
        })
        present(explainer, animated: true)
    }

    /// Starts over with a new transfer and a new evaluation.
    private func reset() {
        transactionID = UUID().uuidString
        confirmButton.isEnabled = true
        startEvaluation()
    }

    private func alert(_ title: String, _ message: String, endsTransfer: Bool = false) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            if endsTransfer { self?.reset() }
        })
        present(alert, animated: true)
    }

    private func button(_ title: String, _ style: UIButton.Configuration, action: @escaping () -> Void) -> UIButton {
        var configuration = style
        configuration.title = title
        configuration.buttonSize = .large
        return UIButton(configuration: configuration, primaryAction: UIAction { _ in action() })
    }
}
