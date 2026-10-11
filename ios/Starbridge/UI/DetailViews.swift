import StarbridgeProtocol
import SwiftUI

/**
 * A question opened: its words, its options, the reply field, and the session line. Answered from
 * here, the sheet goes at the tap (#927); a refused answer comes back in the list.
 */
struct DecisionDetail: View {
    let store: Store
    let id: String
    let close: () -> Void

    var body: some View {
        if let d = store.decision(id) {
            let open = d.isOpen && store.unsent[id] == nil
            let until = d.snoozed
            let waiting = d.waiting == "waiting" && until == nil
            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Spacing.s4) {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let since = waiting ? d.waitingAt.flatMap(Dates.parse) : nil
                        MetaRow(
                            source: d.body.source,
                            time: since.map { Times.waited($0, context.date) } ?? Dates.parse(d.body.createdAt).map { Times.since($0, context.date) } ?? "",
                            clock: waiting
                        )
                    }
                    Text(d.body.question).type(Tokens.Typography.question).textSelection(.enabled)
                    if !d.body.context.isEmpty { ContextView(text: d.body.context) }
                    ForEach(d.body.links ?? [], id: \.url) { link in
                        if let url = URL(string: link.url) {
                            Link(link.title ?? link.url, destination: url).type(Tokens.Typography.small).underline()
                        }
                    }
                    if let until {
                        Text("Snoozed until \(Times.clock(until, Date()))").type(Tokens.Typography.small).foregroundStyle(Tokens.Colors.fg2.color)
                    }
                    if let why = store.notSent[id] {
                        Text("Not sent: \(why)").type(Tokens.Typography.small).foregroundStyle(Tokens.Colors.bad.color)
                    }
                    if open {
                        Answering(store: store, decision: d, amber: waiting) { close() }
                    } else {
                        Text(HistoryText.how(d, store)).type(Tokens.Typography.body).foregroundStyle(Tokens.Colors.fg2.color)
                    }
                    SessionLine(source: d.body.source, agent: d.body.agent)
                }
                .padding(Tokens.Spacing.s5)
            }
            .foregroundStyle(Tokens.Colors.fg.color)
            .background(Tokens.Colors.bg.color.ignoresSafeArea())
        } else {
            Text("This question is gone.").type(Tokens.Typography.body).padding()
        }
    }
}

/** What History says of an answered question, shared by its row and its detail. */
enum HistoryText {
    @MainActor static func how(_ d: SavedDecision, _ store: Store) -> String {
        if let unsent = store.unsent[d.id] { return "You: \(unsent) · not sent yet" }
        if let mine = d.answer { return "You: \(mine)" }
        if let theirs = d.theirAnswer, let by = d.answeredBy { return "\(store.memberName(by)): \(theirs)" }
        switch d.settled {
        case "withdrawn": return d.reason.map { "Withdrawn · \($0)" } ?? "Withdrawn"
        case "elsewhere": return "Answered at the keyboard"
        default: break
        }
        if let page = d.body.answerIn { return Store.doneText(page) }
        return "Answered"
    }
}

/** The ways to answer an open question: its page and Done, its options, and the reply field. */
private struct Answering: View {
    let store: Store
    let decision: SavedDecision
    let amber: Bool
    let answered: () -> Void

    var body: some View {
        let body = decision.body
        VStack(alignment: .leading, spacing: Tokens.Spacing.s3) {
            if let page = body.answerIn, let url = URL(string: page.url) {
                // Answered on its page, never here; Done says the owner did (#539).
                Link(destination: url) {
                    Text("Answer in \(page.title ?? url.host() ?? page.url)")
                        .type(Tokens.Typography.action)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .foregroundStyle(Tokens.Colors.bg.color)
                        .background(Capsule().fill(Tokens.Colors.fg.color))
                }
                if body.done == true {
                    OptionButton(label: "Done", strong: false, amber: amber, height: 48) { send(nil, nil) }
                }
            } else {
                if !body.options.isEmpty {
                    Options(decision: body, amber: amber, height: 48) { send($0, nil) }
                }
                // A question with options takes a typed reply only when it says so (#201).
                if body.options.isEmpty || body.replies == true {
                    ReplyField(store: store, id: decision.id, placeholder: body.options.isEmpty ? "Your answer" : "Reply") { send(nil, $0) }
                }
            }
        }
    }

    private func send(_ choice: String?, _ text: String?) {
        store.answer(decision.id, choice: choice, text: text)
        answered()
    }
}

/**
 * The reply field: grows to 10 lines, then scrolls (#947), and keeps a draft with its question
 * while the app runs (#992). Return starts a new line; the arrow sends.
 */
private struct ReplyField: View {
    let store: Store
    let id: String
    let placeholder: String
    let send: (String) -> Void

    var body: some View {
        let draft = Binding(get: { store.drafts[id] ?? "" }, set: { store.drafts[id] = $0 })
        let text = draft.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        HStack(alignment: .bottom, spacing: Tokens.Spacing.s2) {
            TextField(placeholder, text: draft, axis: .vertical)
                .lineLimit(1...10)
                .type(Tokens.Typography.body)
            Button {
                store.drafts[id] = nil
                send(text)
            } label: {
                Image(systemName: "arrow.up.circle.fill").font(.system(size: 30))
            }
            .disabled(text.isEmpty)
            .accessibilityLabel("Send")
        }
        .padding(.horizontal, Tokens.Spacing.s4)
        .padding(.vertical, Tokens.Spacing.s2)
        .frame(minHeight: 56)
        .background(RoundedRectangle(cornerRadius: Tokens.Radius.md).fill(Tokens.Colors.surface2.color))
    }
}

/**
 * A permission prompt opened: what the agent wants to run, the full input, and the answers. A
 * deny may carry a note to the agent; a wider allow only takes a scope the prompt offered.
 */
struct PromptDetail: View {
    let store: Store
    let id: String
    let close: () -> Void
    @State private var note = ""
    @State private var seen = false

    var body: some View {
        if let p = store.prompt(id) {
            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Spacing.s4) {
                    MetaRow(source: p.body.source, time: Dates.parse(p.body.createdAt).map { Times.since($0, Date()) } ?? "")
                    Text(p.headline).type(Tokens.Typography.question)
                    // The whole input; Allow waits until its end has been on screen (#274).
                    Text(p.fullInput)
                        .type(Tokens.Typography.code)
                        .textSelection(.enabled)
                        .padding(Tokens.Spacing.s4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: Tokens.Radius.lg).fill(Tokens.Colors.surface2.color))
                    Color.clear.frame(height: 1).background(
                        GeometryReader { g in
                            Color.clear.onChange(of: g.frame(in: .global).minY, initial: true) { _, y in
                                if y < UIScreen.main.bounds.height { seen = true }
                            }
                        }
                    )
                    if p.isOpen {
                        VStack(spacing: Tokens.Spacing.s2) {
                            OptionButton(label: "Allow", strong: true, amber: true, height: 48) { answer(p, allow: true, .once) }
                                .disabled(!seen)
                                .opacity(seen ? 1 : 0.38)
                            // Each wider allow shows the exact rule it adds (PROTOCOL.md).
                            ForEach(p.body.suggestions, id: \.rule) { s in
                                VStack(alignment: .leading, spacing: Tokens.Spacing.s1) {
                                    OptionButton(label: s.label, strong: false, amber: true, height: 48) { answer(p, allow: true, s.scope) }
                                    Text(visible(s.rule)).type(Tokens.Typography.snippet).foregroundStyle(Tokens.Colors.fg2.color)
                                }
                                .disabled(!seen)
                                .opacity(seen ? 1 : 0.38)
                            }
                            TextField("Note to the agent (optional)", text: $note, axis: .vertical)
                                .lineLimit(1...4)
                                .type(Tokens.Typography.body)
                                .padding(Tokens.Spacing.s3)
                                .background(RoundedRectangle(cornerRadius: Tokens.Radius.md).fill(Tokens.Colors.surface2.color))
                            OptionButton(label: "Deny", strong: false, amber: true, height: 48) { answer(p, allow: false, .once) }
                        }
                    } else {
                        Text(p.answer.map { $0 == "deny" ? "You denied it" : "You allowed it" } ?? (p.answeredAt != nil ? "Answered" : "Expired"))
                            .type(Tokens.Typography.body)
                            .foregroundStyle(Tokens.Colors.fg2.color)
                    }
                    SessionLine(source: p.body.source, agent: p.body.agent)
                }
                .padding(Tokens.Spacing.s5)
            }
            .foregroundStyle(Tokens.Colors.fg.color)
            .background(Tokens.Colors.bg.color.ignoresSafeArea())
        } else {
            Text("This prompt is gone.").type(Tokens.Typography.body).padding()
        }
    }

    private func answer(_ p: SavedPrompt, allow: Bool, _ scope: PermissionScope) {
        let message = allow ? nil : note
        close()
        Task { await store.answerPrompt(p.id, allow: allow, scope: scope, message: message) }
    }
}
