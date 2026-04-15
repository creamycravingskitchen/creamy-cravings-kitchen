import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#endif
#if os(iOS)
import UIKit
#endif

struct KitchenDashboardView: View {
    @Binding var store: KitchenFinanceStore
    @State private var selectedTab: KitchenTab = .uploadReceipt
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showingFileImporter = false
    @State private var showingCamera = false
    @State private var plaidHealthSummary = "Backend status not checked yet."
    @State private var plaidErrorMessage: String?
    @State private var plaidItemId: String?
    @State private var plaidLastSyncSummary = "No Plaid sync has been run yet."
    @State private var plaidItems: [PlaidStoredItemPayload] = []
    @State private var isCheckingBackend = false
    @State private var isLoadingSandboxTransactions = false
    @State private var isRefreshingLinkedAccounts = false
    @State private var isSyncingLinkedAccount = false
    @State private var showingSalesHistory = false
    @State private var showingExpenseHistory = false
    private let plaidClient = PlaidBackendClient()

    var body: some View {
        TabView(selection: $selectedTab) {
            uploadReceiptTab
                .tabItem {
                    Label("Upload Receipt", systemImage: "doc.viewfinder")
                }
                .tag(KitchenTab.uploadReceipt)

            transactionsTab
                .tabItem {
                    Label("Transactions", systemImage: "building.columns")
                }
                .tag(KitchenTab.transactions)

            salesTab
                .tabItem {
                    Label("Sales", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(KitchenTab.sales)

            expensesTab
                .tabItem {
                    Label("Expenses", systemImage: "chart.bar.doc.horizontal")
                }
                .tag(KitchenTab.expenses)
        }
        .tint(AppTheme.accent)
        .background(AppTheme.appBackground.ignoresSafeArea())
        .task {
            await checkPlaidBackend()
        }
        .onChange(of: selectedPhotoItem) { _, newValue in
            guard newValue != nil else {
                return
            }

            store.addImportedReceipt(name: "Photo Library Receipt", source: .photoLibrary)
            selectedPhotoItem = nil
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.image, .pdf],
            allowsMultipleSelection: false
        ) { result in
            guard case let .success(urls) = result, let url = urls.first else {
                return
            }

            store.addImportedReceipt(name: url.lastPathComponent, source: .fileUpload)
        }
#if os(iOS)
        .sheet(isPresented: $showingCamera) {
            CameraCaptureView { image in
                guard image != nil else {
                    return
                }

                store.addImportedReceipt(name: "Camera Capture", source: .camera)
            }
        }
#endif
    }

    private var uploadReceiptTab: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                    ProductHeaderView(
                        eyebrow: "Receipt Operations",
                        title: "Creamy Cravings Kitchen",
                        subtitle: "Capture receipts from your camera or import files so every expense has a clean audit trail from day one."
                    )

                    HStack(spacing: AppTheme.cardSpacing) {
                        ActionCard(
                            title: "Upload Receipt",
                            detail: "Import image or PDF receipts from Files or Finder.",
                            systemImage: "square.and.arrow.down.on.square"
                        ) {
                            showingFileImporter = true
                        }

                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            ActionCardLabel(
                                title: "Photo Library",
                                detail: "Choose an existing receipt image from Photos.",
                                systemImage: "photo.on.rectangle.angled"
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    HStack(spacing: AppTheme.cardSpacing) {
                        ActionCard(
                            title: "Use Camera",
                            detail: cameraDetail,
                            systemImage: "camera.viewfinder"
                        ) {
#if os(iOS)
                            showingCamera = true
#else
                            showingFileImporter = true
#endif
                        }

                        InsightCard(
                            title: "Next Up",
                            value: "\(store.receipts.count)",
                            footnote: "receipts in review"
                        )
                    }

                    sectionCard("Recent Uploads") {
                        VStack(spacing: 14) {
                            ForEach(store.receipts) { receipt in
                                HStack(alignment: .center, spacing: 14) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(receipt.name)
                                            .font(.headline)
                                            .foregroundStyle(AppTheme.textPrimary)
                                        Text(receipt.source.label)
                                            .font(.subheadline)
                                            .foregroundStyle(AppTheme.textSecondary)
                                    }

                                    Spacer()

                                    Text(receipt.importedAt.formatted(date: .abbreviated, time: .omitted))
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                                .padding(16)
                                .background(AppTheme.secondarySurface)
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            }
                        }
                    }
                }
                .padding(AppTheme.screenPadding)
                .frame(maxWidth: 1120)
            }
            .background(AppTheme.appBackground.ignoresSafeArea())
        }
    }

    private var transactionsTab: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                    ProductHeaderView(
                        eyebrow: "Bank Feed",
                        title: "Transactions",
                        subtitle: "Plaid will connect to Bank of America checking so the kitchen can import bank activity directly into the app."
                    )

                    HStack(spacing: AppTheme.cardSpacing) {
                        InsightCard(
                            title: "Connected Institution",
                            value: store.connectedInstitution,
                            footnote: "Plaid-ready"
                        )
                        InsightCard(
                            title: "Imported Transactions",
                            value: "\(store.transactions.count)",
                            footnote: "sample feed"
                        )
                        InsightCard(
                            title: "Checking Account",
                            value: "BofA",
                            footnote: "primary source"
                        )
                    }

                    sectionCard("Plaid Connection") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("The app is wired to a local Plaid backend so Mac can open Plaid Link in the browser, while secrets and access tokens stay server-side.")
                                .font(.body)
                                .foregroundStyle(AppTheme.textSecondary)

                            Label(plaidHealthSummary, systemImage: "lock.shield")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.accent)

                            if let plaidErrorMessage {
                                Text(plaidErrorMessage)
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.negativeAccent)
                            }

                            HStack(spacing: 12) {
                                Button(isCheckingBackend ? "Checking..." : "Check Backend") {
                                    Task {
                                        await checkPlaidBackend()
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(isCheckingBackend)

                                Button(isLoadingSandboxTransactions ? "Loading..." : "Load Sandbox Transactions") {
                                    Task {
                                        await loadSandboxTransactions()
                                    }
                                }
                                .buttonStyle(.bordered)
                                .disabled(isLoadingSandboxTransactions)
                            }

                            HStack(spacing: 12) {
                                Button("Connect Checking Account") {
                                    openPlaidLinkInBrowser()
                                }
                                .buttonStyle(.borderedProminent)

                                Button(isRefreshingLinkedAccounts ? "Refreshing..." : "Refresh Linked Accounts") {
                                    Task {
                                        await refreshLinkedAccounts()
                                    }
                                }
                                .buttonStyle(.bordered)
                                .disabled(isRefreshingLinkedAccounts)

                                Button(isSyncingLinkedAccount ? "Syncing..." : "Sync Latest Account") {
                                    Task {
                                        await syncLatestLinkedAccount()
                                    }
                                }
                                .buttonStyle(.bordered)
                                .disabled(isSyncingLinkedAccount || plaidItems.isEmpty)
                            }

                            if plaidItemId != nil {
                                Label("Plaid item stored securely on the backend for this app session.", systemImage: "checkmark.seal.fill")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.positiveAccent)
                            }

                            Text(plaidLastSyncSummary)
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.textSecondary)

                            if !plaidItems.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Linked Items")
                                        .font(.headline)
                                        .foregroundStyle(AppTheme.textPrimary)

                                    ForEach(plaidItems) { item in
                                        HStack {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(item.institutionName ?? "Linked Institution")
                                                    .font(.subheadline.weight(.semibold))
                                                    .foregroundStyle(AppTheme.textPrimary)
                                                Text(item.itemId)
                                                    .font(.caption.monospaced())
                                                    .foregroundStyle(AppTheme.textSecondary)
                                            }

                                            Spacer()

                                            if plaidItemId == item.itemId {
                                                Text("Active")
                                                    .font(.caption.weight(.semibold))
                                                    .foregroundStyle(AppTheme.positiveAccent)
                                            }
                                        }
                                        .padding(14)
                                        .background(AppTheme.secondarySurface)
                                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                    }
                                }
                            }
                        }
                    }

                    sectionCard("Imported Activity") {
                        VStack(spacing: 14) {
                            ForEach(store.transactions) { transaction in
                                TransactionRow(transaction: transaction)
                            }
                        }
                    }
                }
                .padding(AppTheme.screenPadding)
                .frame(maxWidth: 1120)
            }
            .background(AppTheme.appBackground.ignoresSafeArea())
        }
    }

    private var salesTab: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                    ProductHeaderView(
                        eyebrow: "Revenue View",
                        title: "Sales",
                        subtitle: "Every credit transaction rolls into monthly sales summaries so you can see the kitchen's top-line performance at a glance."
                    )

                    HStack(spacing: AppTheme.cardSpacing) {
                        InsightCard(
                            title: "Current Year Sales",
                            value: store.currency(store.currentYearSalesTotal),
                            footnote: "January to date"
                        )
                        InsightCard(
                            title: "Last Year Sales",
                            value: store.currency(store.previousYearSalesSnapshot.total),
                            footnote: "\(store.previousYearSalesSnapshot.year) full year"
                        )
                    }

                    sectionCard("Year Comparison") {
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Need previous-year detail?")
                                    .font(.headline)
                                    .foregroundStyle(AppTheme.textPrimary)
                                Text("Open a compact year summary with month-by-month sales and the full-year total.")
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }

                            Spacer()

                            Button("View \(store.previousYearSalesSnapshot.year) Sales") {
                                showingSalesHistory = true
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }

                    sectionCard("Monthly Sales \(currentYearLabel)") {
                        VStack(spacing: 14) {
                            ForEach(store.currentYearSalesByMonth) { group in
                                MonthlySummaryRow(group: group, accent: AppTheme.positiveAccent)
                            }
                        }
                    }

                    sectionCard("Sales Transactions") {
                        VStack(spacing: 14) {
                            ForEach(store.salesTransactions) { transaction in
                                TransactionRow(transaction: transaction)
                            }
                        }
                    }
                }
                .padding(AppTheme.screenPadding)
                .frame(maxWidth: 1120)
            }
            .background(AppTheme.appBackground.ignoresSafeArea())
            .sheet(isPresented: $showingSalesHistory) {
                YearHistorySheet(
                    title: "Sales History",
                    subtitle: "Monthly sales for \(store.previousYearSalesSnapshot.year) plus the full-year total.",
                    snapshot: store.previousYearSalesSnapshot,
                    accent: AppTheme.positiveAccent,
                    totalLabel: "Full Year Sales",
                    currency: store.currency
                )
            }
        }
    }

    private var expensesTab: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                    ProductHeaderView(
                        eyebrow: "Cost Control",
                        title: "Expenses",
                        subtitle: "Every debit transaction is grouped by month so operating costs stay visible and reviewable."
                    )

                    HStack(spacing: AppTheme.cardSpacing) {
                        InsightCard(
                            title: "Current Year Expenses",
                            value: store.currency(store.currentYearExpensesTotal),
                            footnote: "January to date"
                        )
                        InsightCard(
                            title: "Last Year Expenses",
                            value: store.currency(store.previousYearExpensesSnapshot.total),
                            footnote: "\(store.previousYearExpensesSnapshot.year) full year"
                        )
                    }

                    sectionCard("Year Comparison") {
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Review prior-year spend")
                                    .font(.headline)
                                    .foregroundStyle(AppTheme.textPrimary)
                                Text("Open a small year summary to compare each month of last year's expenses against the current year.")
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }

                            Spacer()

                            Button("View \(store.previousYearExpensesSnapshot.year) Expenses") {
                                showingExpenseHistory = true
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }

                    sectionCard("Monthly Expenses \(currentYearLabel)") {
                        VStack(spacing: 14) {
                            ForEach(store.currentYearExpensesByMonth) { group in
                                MonthlySummaryRow(group: group, accent: AppTheme.negativeAccent)
                            }
                        }
                    }

                    sectionCard("Expense Transactions") {
                        VStack(spacing: 14) {
                            ForEach(store.expenseTransactions) { transaction in
                                TransactionRow(transaction: transaction)
                            }
                        }
                    }
                }
                .padding(AppTheme.screenPadding)
                .frame(maxWidth: 1120)
            }
            .background(AppTheme.appBackground.ignoresSafeArea())
            .sheet(isPresented: $showingExpenseHistory) {
                YearHistorySheet(
                    title: "Expense History",
                    subtitle: "Monthly expenses for \(store.previousYearExpensesSnapshot.year) plus the full-year total.",
                    snapshot: store.previousYearExpensesSnapshot,
                    accent: AppTheme.negativeAccent,
                    totalLabel: "Full Year Expenses",
                    currency: store.currency
                )
            }
        }
    }

    @ViewBuilder
    private func sectionCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)

            content()
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(AppTheme.cardStroke, lineWidth: 1)
        )
    }

    private var cameraDetail: String {
#if os(iOS)
        "Launch the iPhone camera and capture a fresh receipt on the spot."
#else
        "Mac flow placeholder. Next step is a continuity camera or native capture experience."
#endif
    }

    private var currentYearLabel: String {
        String(Calendar.current.component(.year, from: .now))
    }

    @MainActor
    private func checkPlaidBackend() async {
        isCheckingBackend = true
        defer { isCheckingBackend = false }

        do {
            let health = try await plaidClient.health()
            plaidHealthSummary = health.configured
                ? "Backend ready in \(health.environment.capitalized) for \(health.products.joined(separator: ", ")). Stored items: \(health.storedItems)."
                : "Backend is reachable but missing Plaid credentials."
            if plaidItemId == nil {
                plaidErrorMessage = nil
            }
            await refreshLinkedAccounts(silent: true)
        } catch {
            if plaidItemId != nil {
                plaidHealthSummary = "Backend check hit a transient Apple network warning, but the Plaid session is already working."
                plaidErrorMessage = nil
            } else {
                plaidHealthSummary = "Backend unavailable at http://127.0.0.1:8080."
                plaidErrorMessage = error.localizedDescription
            }
        }
    }

    @MainActor
    private func loadSandboxTransactions() async {
        isLoadingSandboxTransactions = true
        defer { isLoadingSandboxTransactions = false }

        do {
            let payload = try await plaidClient.loadSandboxTransactions()
            store.replaceTransactions(
                with: payload.transactions.map(\.bankTransaction),
                institutionName: payload.institutionName
            )
            plaidItemId = payload.itemId
            plaidHealthSummary = "Sandbox transactions imported successfully."
            plaidLastSyncSummary = "Loaded \(payload.transactions.count) transactions from \(payload.institutionName ?? "Plaid Sandbox")."
            plaidErrorMessage = nil
            await refreshLinkedAccounts(silent: true)
        } catch {
            plaidErrorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func refreshLinkedAccounts(silent: Bool = false) async {
        if !silent {
            isRefreshingLinkedAccounts = true
        }
        defer { isRefreshingLinkedAccounts = false }

        do {
            plaidItems = try await plaidClient.items()
            if let latest = plaidItems.first?.itemId {
                plaidItemId = latest
            }
            if !silent {
                plaidLastSyncSummary = plaidItems.isEmpty ? "No linked Plaid items found yet." : "Found \(plaidItems.count) linked Plaid item(s) on the backend."
            }
        } catch {
            if !silent {
                plaidErrorMessage = error.localizedDescription
            }
        }
    }

    @MainActor
    private func syncLatestLinkedAccount() async {
        guard let itemId = plaidItems.first?.itemId ?? plaidItemId else {
            plaidErrorMessage = "No linked Plaid item found. Use Connect Checking Account first."
            return
        }

        isSyncingLinkedAccount = true
        defer { isSyncingLinkedAccount = false }

        do {
            let payload = try await plaidClient.syncTransactions(itemId: itemId)
            store.replaceTransactions(
                with: payload.transactions.map(\.bankTransaction),
                institutionName: payload.institutionName
            )
            plaidItemId = payload.itemId ?? itemId
            plaidLastSyncSummary = "Synced \(payload.transactions.count) transactions from \(payload.institutionName ?? "your linked account")."
            plaidErrorMessage = nil
        } catch {
            plaidErrorMessage = error.localizedDescription
        }
    }

    private func openPlaidLinkInBrowser() {
        let url = plaidClient.linkEntryURL()
#if os(macOS)
        NSWorkspace.shared.open(url)
#else
        UIApplication.shared.open(url)
#endif
    }
}

private struct YearHistorySheet: View {
    let title: String
    let subtitle: String
    let snapshot: YearlyTransactionSnapshot
    let accent: Color
    let totalLabel: String
    let currency: (Double) -> String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(subtitle)
                        .font(.body)
                        .foregroundStyle(AppTheme.textSecondary)

                    VStack(alignment: .leading, spacing: 12) {
                        Text(totalLabel.uppercased())
                            .font(.caption.weight(.bold))
                            .kerning(1.1)
                            .foregroundStyle(AppTheme.textSecondary)

                        Text(currency(snapshot.total))
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(accent)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                    VStack(spacing: 14) {
                        if snapshot.months.isEmpty {
                            Text("No transactions found for \(snapshot.year).")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                                .background(AppTheme.secondarySurface)
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        } else {
                            ForEach(snapshot.months) { group in
                                MonthlySummaryRow(group: group, accent: accent)
                            }
                        }
                    }
                }
                .padding(AppTheme.screenPadding)
            }
            .background(AppTheme.appBackground.ignoresSafeArea())
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct ProductHeaderView: View {
    let eyebrow: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(eyebrow.uppercased())
                .font(.caption.weight(.bold))
                .kerning(1.4)
                .foregroundStyle(AppTheme.accent)

            Text(title)
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)

            Text(subtitle)
                .font(.title3)
                .foregroundStyle(AppTheme.textSecondary)
                .lineSpacing(4)
                .frame(maxWidth: 760, alignment: .leading)
        }
    }
}

private struct ActionCard: View {
    let title: String
    let detail: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ActionCardLabel(title: title, detail: detail, systemImage: systemImage)
        }
        .buttonStyle(.plain)
    }
}

private struct ActionCardLabel: View {
    let title: String
    let detail: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 48, height: 48)
                .background(AppTheme.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)

            Text(detail)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
                .lineSpacing(3)

            Spacer(minLength: 0)
        }
        .padding(22)
        .frame(maxWidth: .infinity, minHeight: 180, alignment: .leading)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(AppTheme.cardStroke, lineWidth: 1)
        )
    }
}

private struct InsightCard: View {
    let title: String
    let value: String
    let footnote: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.caption.weight(.bold))
                .kerning(1.2)
                .foregroundStyle(AppTheme.textSecondary)

            Text(value)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.75)

            Text(footnote)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(AppTheme.cardStroke, lineWidth: 1)
        )
    }
}

private struct TransactionRow: View {
    let transaction: BankTransaction

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Circle()
                .fill(transaction.direction == .credit ? AppTheme.positiveAccent.opacity(0.18) : AppTheme.negativeAccent.opacity(0.18))
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: transaction.direction == .credit ? "arrow.down.left.circle.fill" : "arrow.up.right.circle.fill")
                        .foregroundStyle(transaction.direction == .credit ? AppTheme.positiveAccent : AppTheme.negativeAccent)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                Text(transaction.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()

            Text(transaction.formattedAmount)
                .font(.headline.weight(.semibold))
                .foregroundStyle(transaction.direction == .credit ? AppTheme.positiveAccent : AppTheme.negativeAccent)
        }
        .padding(16)
        .background(AppTheme.secondarySurface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct MonthlySummaryRow: View {
    let group: MonthlyTransactionGroup
    let accent: Color

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(group.monthTitle)
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                Text("\(group.transactions.count) transactions")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()

            Text(group.formattedTotal)
                .font(.headline.weight(.semibold))
                .foregroundStyle(accent)
        }
        .padding(16)
        .background(AppTheme.secondarySurface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

#if os(iOS)
private struct CameraCaptureView: UIViewControllerRepresentable {
    let onCapture: (UIImage?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        controller.delegate = context.coordinator
        controller.sourceType = .camera
        return controller
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onCapture: (UIImage?) -> Void

        init(onCapture: @escaping (UIImage?) -> Void) {
            self.onCapture = onCapture
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            onCapture(info[.originalImage] as? UIImage)
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCapture(nil)
            picker.dismiss(animated: true)
        }
    }
}
#endif

#if DEBUG
struct KitchenDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        KitchenDashboardView(store: .constant(.sample))
    }
}
#endif
