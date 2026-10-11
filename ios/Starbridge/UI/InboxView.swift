import StarbridgeProtocol
import SwiftUI

/** What a sheet over the inbox shows. */
enum Opened: Identifiable, Hashable {
    case decision(String)
    case prompt(String)

    var id: Self { self }
}

/**
 * The inbox, in the order every client uses (spec/clients.md): runs first, then permission
 * prompts, then questions whose agent waits, then the rest, each oldest first. Snoozed and
 * History wait closed at the bottom.
 */
struct InboxView: View {
    let store: Store
    @Environment(\.scenePhase) private var scenePhase
    @State private var opened: Opened?
    @State private var snoozedOpen = false
    @State private var historyOpen = false

    var body: some View {
        let decisions = store.openDecisions
        let waiting = decisions.filter { $0.waiting == "waiting" }
        let rest = decisions.filter { $0.waiting != "waiting" }
        let runs = store.shownRuns
        let prompts = store.openPrompts
        let snoozed = store.snoozedDecisions
        let history = store.history
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: Tokens.Spacing.s2) {
                    if let why = store.withheldWhy { HeldBanner(store: store, why: why) }
                    ForEach(runs, id: \.id) { RunCard(run: $0, store: store) }
                    ForEach(prompts, id: \.id) { p in PromptCard(prompt: p, store: store) { opened = .prompt(p.id) } }
                    ForEach(waiting + rest, id: \.id) { d in DecisionCard(decision: d, store: store) { opened = .decision(d.id) } }
                    if runs.isEmpty, prompts.isEmpty, decisions.isEmpty, store.withheldWhy == nil {
                        Text("Nothing needs you")
                            .type(Tokens.Typography.heading)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Tokens.Spacing.s16)
                    }
                    if !snoozed.isEmpty {
                        Section(title: "Snoozed", count: "\(snoozed.count)", symbol: "moon.zzz", open: $snoozedOpen) {
                            ForEach(snoozed, id: \.id) { d in DecisionCard(decision: d, store: store) { opened = .decision(d.id) } }
                        }
                    }
                    if !history.isEmpty {
                        Section(title: "History", count: "", symbol: "clock.arrow.circlepath", open: $historyOpen) {
                            ForEach(history.prefix(100), id: \.id) { d in HistoryRow(decision: d, store: store) { opened = .decision(d.id) } }
                        }
                    }
                }
                .padding(.horizontal, Tokens.Spacing.s3)
                .padding(.bottom, Tokens.Spacing.s6)
                .animation(.default, value: decisions.map(\.id))
            }
            .refreshable { await store.refresh() }
            .background(Tokens.Colors.bg.color.ignoresSafeArea())
            .navigationTitle("Inbox")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Text("This iPhone: \(store.me?.name ?? "")")
                        Button("Sign out", role: .destructive) { Task { await store.signOut() } }
                    } label: {
                        Image(systemName: "person.crop.circle").accessibilityLabel("Account")
                    }
                }
            }
        }
        .sheet(item: $opened) { which in
            Group {
                switch which {
                case let .decision(id): DecisionDetail(store: store, id: id) { opened = nil }
                case let .prompt(id): PromptDetail(store: store, id: id) { opened = nil }
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .task { store.startPolling() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { store.startPolling() } else { store.stopPolling() }
        }
    }
}

/** A closed group at the bottom: its header opens it (#662). */
private struct Section<Content: View>: View {
    let title: String
    let count: String
    let symbol: String
    @Binding var open: Bool
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: Tokens.Spacing.s2) {
            Button {
                withAnimation { open.toggle() }
            } label: {
                HStack(spacing: Tokens.Spacing.s2) {
                    Image(systemName: symbol)
                    Text(title).type(Tokens.Typography.label)
                    Text(count).type(Tokens.Typography.machine).foregroundStyle(Tokens.Colors.fg2.color)
                    Spacer()
                    Image(systemName: "chevron.down").rotationEffect(.degrees(open ? 180 : 0))
                }
                .foregroundStyle(Tokens.Colors.fg.color)
                .frame(minHeight: Tokens.Sizes.tap)
                .padding(.horizontal, Tokens.Spacing.s2)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(open ? "Expanded" : "Collapsed")
            if open { content }
        }
        .padding(.top, Tokens.Spacing.s4)
    }
}

/** One filled card; amber fill is the only thing that says an agent waits (#248). */
private struct Card<Content: View>: View {
    let amber: Bool
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) { content }
            .padding(Tokens.Spacing.s5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Tokens.Radius.lg)
                    .fill(Tokens.Colors.surface.color)
                    .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.lg).fill(amber ? Tokens.Colors.accentSoft.color : .clear))
            )
    }
}

private struct DecisionCard: View {
    let decision: SavedDecision
    let store: Store
    let open: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let now = context.date
            // Snoozed, nothing is amber, even when its agent waits: the owner said not now (#571).
            let until = decision.snoozed
            let waiting = decision.waiting == "waiting" && until == nil
            let since = waiting ? decision.waitingAt.flatMap(Dates.parse) : nil
            let slot = until.map { "Until \(Times.clock($0, now))" }
                ?? since.map { Times.waited($0, now) }
                ?? Dates.parse(decision.body.createdAt).map { Times.since($0, now) } ?? ""
            Card(amber: waiting) {
                MetaRow(source: decision.body.source, time: slot, clock: waiting)
                HStack(alignment: .top, spacing: Tokens.Spacing.s2) {
                    Image(systemName: "questionmark.circle")
                        .foregroundStyle(waiting ? Tokens.Colors.accent.color : Tokens.Colors.fg2.color)
                        .accessibilityHidden(true)
                    Text(decision.body.question)
                        .type(Tokens.Typography.subtitle)
                        .fontWeight(waiting ? .medium : .regular)
                }
                if let why = store.notSent[decision.id] {
                    Text("Not sent: \(why)").type(Tokens.Typography.small).foregroundStyle(Tokens.Colors.bad.color)
                }
                // A snoozed card stays quiet: the owner opens it to answer.
                if until == nil, !decision.body.options.isEmpty {
                    Options(decision: decision.body, amber: waiting, height: 40) { store.answer(decision.id, choice: $0, text: nil) }
                        .padding(.top, Tokens.Spacing.s1)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: open)
            .accessibilityElement(children: .contain)
            .accessibilityValue(waiting ? since.map { Times.waitingLabel($0, now) } ?? "Waiting for you" : until.map { "Snoozed until \(Times.clock($0, now))" } ?? "")
            .accessibilityAction(named: "Open the question", open)
        }
    }
}

/** An answered question: what was answered, and how; "not sent yet" until the server takes it. */
private struct HistoryRow: View {
    let decision: SavedDecision
    let store: Store
    let open: () -> Void

    var body: some View {
        Card(amber: false) {
            MetaRow(source: decision.body.source, time: decision.answeredAt.flatMap(Dates.parse).map { Times.since($0, Date()) } ?? "")
            Text(decision.body.question).type(Tokens.Typography.body).lineLimit(2)
            Text(HistoryText.how(decision, store)).type(Tokens.Typography.small).foregroundStyle(Tokens.Colors.fg2.color).lineLimit(2)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: open)
    }
}

private struct PromptCard: View {
    let prompt: SavedPrompt
    let store: Store
    let open: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Card(amber: true) {
                MetaRow(source: prompt.body.source, time: Dates.parse(prompt.body.createdAt).map { Times.waited($0, context.date) } ?? "", clock: true)
                HStack(alignment: .top, spacing: Tokens.Spacing.s2) {
                    Image(systemName: "terminal").foregroundStyle(Tokens.Colors.accent.color).accessibilityHidden(true)
                    Text(prompt.body.description.map(visible) ?? prompt.body.tool).type(Tokens.Typography.action)
                }
                // The whole input when it fits a line, else the summary; Allow covers only what shows (#356).
                Text(prompt.fitsRow ? prompt.fullInput : visible(prompt.body.summary))
                    .type(Tokens.Typography.code)
                    .lineLimit(prompt.fitsRow ? nil : 3)
                    .padding(Tokens.Spacing.s3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: Tokens.Radius.md).fill(Tokens.Colors.surface.color))
                HStack(spacing: Tokens.Spacing.s2) {
                    OptionButton(label: "Deny", strong: false, amber: true, height: 40) { Task { await store.answerPrompt(prompt.id, allow: false) } }
                    OptionButton(label: "Allow", strong: true, amber: true, height: 40) {
                        if prompt.fitsRow { Task { await store.answerPrompt(prompt.id, allow: true) } } else { open() }
                    }
                }
                .padding(.top, Tokens.Spacing.s1)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: open)
            .accessibilityElement(children: .contain)
            .accessibilityAction(named: "Open the prompt", open)
        }
    }
}

/** A `starbridge run`: running with its progress, passed, failed, or lost; ended ones can go. */
private struct RunCard: View {
    let run: SavedRun
    let store: Store

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let now = context.date
            let started = Dates.parse(run.body.startedAt) ?? now
            let state: (String, Color) = if let exit = run.body.exit {
                exit.code == 0 ? ("Passed", Tokens.Colors.ok.color) : ("Failed, exit \(exit.code)", Tokens.Colors.bad.color)
            } else if run.lost {
                ("Lost, no news for \(Times.elapsed(run.lastNews, now))", Tokens.Colors.fg3.color)
            } else {
                ("Running, \(Times.elapsed(started, now))", Tokens.Colors.fg2.color)
            }
            Card(amber: false) {
                MetaRow(source: run.body.source, time: Times.since(started, now))
                HStack(alignment: .top, spacing: Tokens.Spacing.s2) {
                    Image(systemName: "terminal").foregroundStyle(Tokens.Colors.fg2.color).accessibilityHidden(true)
                    Text(run.body.title).type(Tokens.Typography.subtitle).fontWeight(.regular)
                }
                Text(run.body.reason).type(Tokens.Typography.small).foregroundStyle(Tokens.Colors.fg2.color)
                if let p = run.body.progress, run.body.exit == nil, p.total > 0 {
                    ProgressView(value: Double(p.done), total: Double(p.total))
                        .tint(Tokens.Colors.fg.color)
                        .accessibilityValue(p.unit == "percent" ? "\(p.done) percent" : "\(p.done) of \(p.total)")
                }
                HStack {
                    Text(state.0).type(Tokens.Typography.small).foregroundStyle(state.1)
                    Spacer()
                    if run.body.exit != nil || run.lost {
                        Button("Dismiss") { store.dismissRun(run.id) }
                            .type(Tokens.Typography.action)
                            .foregroundStyle(Tokens.Colors.fg.color)
                            .frame(minHeight: Tokens.Sizes.tap)
                    }
                }
            }
        }
    }
}

/** Nothing from the machines shows: the server holds back entries a machine has seen (#362). */
private struct HeldBanner: View {
    let store: Store
    let why: String

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.s2) {
            Text(why).type(Tokens.Typography.small)
            if store.heldRevoked != nil {
                Button("Stop waiting") { Task { await store.stopWaiting() } }.type(Tokens.Typography.action)
            }
        }
        .padding(Tokens.Spacing.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Tokens.Radius.lg).fill(Tokens.Colors.badSoft.color))
    }
}
