import Cocoa

private enum ConversionStatus: String {
    case waiting
    case running
    case success
    case failed

    var localizedTitle: String {
        L10n.tr("status.\(rawValue)")
    }
}

private struct ConversionItem {
    let url: URL
    var status: ConversionStatus
    var message: String
}

final class ViewController: NSViewController {
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let dropTitleLabel = NSTextField(labelWithString: "")
    private let dropSubtitleLabel = NSTextField(labelWithString: "")
    private let addButton = NSButton(title: "", target: nil, action: nil)
    private let addFolderButton = NSButton(title: "", target: nil, action: nil)
    private let outputButton = NSButton(title: "", target: nil, action: nil)
    private let outputLabel = NSTextField(labelWithString: "")
    private let summaryLabel = NSTextField(labelWithString: "")
    private let progressIndicator = NSProgressIndicator()
    private let convertButton = NSButton(title: "", target: nil, action: nil)
    private let clearButton = NSButton(title: "", target: nil, action: nil)
    private let defaultScanButton = NSButton(title: "", target: nil, action: nil)
    private let formatLabel = NSTextField(labelWithString: "")
    private let languageLabel = NSTextField(labelWithString: "")
    private let outputTitleLabel = NSTextField(labelWithString: "")
    private let formatPopup = NSPopUpButton()
    private let languagePopup = NSPopUpButton()
    private let dropView = DropView()

    private var items: [ConversionItem] = [] {
        didSet {
            tableView.reloadData()
            updateSummary()
        }
    }

    private lazy var outputDirectory: URL = {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Music", isDirectory: true)
            .appendingPathComponent("音转匣 输出", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    private let conversionQueue = DispatchQueue(label: "yinzhuanxia.conversion.queue", qos: .userInitiated, attributes: .concurrent)
    private let transcoder = AudioTranscoder()
    private var completedCount = 0
    private var successCount = 0
    private var failureCount = 0

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildInterface()
        outputLabel.stringValue = outputDirectory.path
        NotificationCenter.default.addObserver(self, selector: #selector(languageDidChange), name: .appLanguageDidChange, object: nil)
        applyLocalization()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func buildInterface() {
        titleLabel.font = .systemFont(ofSize: 28, weight: .semibold)
        titleLabel.textColor = .labelColor

        subtitleLabel.font = .systemFont(ofSize: 13)
        subtitleLabel.textColor = .secondaryLabelColor

        addButton.target = self
        addButton.action = #selector(addFiles)
        addFolderButton.target = self
        addFolderButton.action = #selector(addFolder)
        outputButton.target = self
        outputButton.action = #selector(selectOutputDirectory)

        defaultScanButton.target = self
        defaultScanButton.action = #selector(scanMusicFolder)

        clearButton.target = self
        clearButton.action = #selector(clearItems)

        convertButton.target = self
        convertButton.action = #selector(convert)
        convertButton.bezelStyle = .rounded

        formatPopup.target = self
        formatPopup.action = #selector(outputFormatChanged)
        rebuildFormatPopup(selected: .original)

        languagePopup.target = self
        languagePopup.action = #selector(languageChanged)
        rebuildLanguagePopup()

        progressIndicator.minValue = 0
        progressIndicator.maxValue = 1
        progressIndicator.doubleValue = 0
        progressIndicator.isIndeterminate = false

        outputLabel.lineBreakMode = .byTruncatingMiddle
        outputLabel.textColor = .secondaryLabelColor

        dropView.onDrop = { [weak self] urls in
            self?.add(urls: urls)
        }

        dropTitleLabel.font = .systemFont(ofSize: 18, weight: .medium)
        dropSubtitleLabel.font = .systemFont(ofSize: 12)
        dropSubtitleLabel.textColor = .secondaryLabelColor

        let dropStack = NSStackView(views: [dropTitleLabel, dropSubtitleLabel])
        dropStack.orientation = .vertical
        dropStack.alignment = .centerX
        dropStack.spacing = 6
        dropStack.translatesAutoresizingMaskIntoConstraints = false
        dropView.addSubview(dropStack)

        NSLayoutConstraint.activate([
            dropStack.centerXAnchor.constraint(equalTo: dropView.centerXAnchor),
            dropStack.centerYAnchor.constraint(equalTo: dropView.centerYAnchor)
        ])

        setupTable()

        let buttonRow = NSStackView(views: [addButton, addFolderButton, defaultScanButton, outputButton, formatLabel, formatPopup, languageLabel, languagePopup, clearButton, convertButton])
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 10
        buttonRow.alignment = .centerY

        let outputRow = NSStackView(views: [outputTitleLabel, outputLabel])
        outputRow.orientation = .horizontal
        outputRow.spacing = 8
        outputRow.alignment = .centerY

        let stack = NSStackView(views: [titleLabel, subtitleLabel, dropView, buttonRow, outputRow, scrollView, progressIndicator, summaryLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        for arrangedView in stack.arrangedSubviews {
            arrangedView.translatesAutoresizingMaskIntoConstraints = false
            arrangedView.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),
            dropView.heightAnchor.constraint(equalToConstant: 118),
            scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 260)
        ])
    }

    private func setupTable() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.headerView = NSTableHeaderView()

        let columns: [(String, CGFloat)] = [
            ("name", 260),
            ("status", 120),
            ("message", 220),
            ("path", 360)
        ]

        for column in columns {
            let tableColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(column.0))
            tableColumn.width = column.1
            tableColumn.minWidth = column.1 == 360 ? 220 : 90
            tableView.addTableColumn(tableColumn)
        }

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.borderType = .bezelBorder
    }

    @objc private func addFiles() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedFileTypes = Array(supportedInputExtensions)
        if panel.runModal() == .OK {
            add(urls: panel.urls)
        }
    }

    @objc private func addFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = true
        if panel.runModal() == .OK {
            add(urls: panel.urls)
        }
    }

    @objc private func selectOutputDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            outputDirectory = url
            outputLabel.stringValue = url.path
        }
    }

    @objc private func clearItems() {
        items.removeAll()
        progressIndicator.doubleValue = 0
    }

    @objc private func outputFormatChanged() {
        updateSummary()
    }

    @objc private func languageChanged() {
        guard let rawValue = languagePopup.selectedItem?.representedObject as? String,
              let language = AppLanguage(rawValue: rawValue) else {
            return
        }
        AppLanguage.selected = language
    }

    @objc private func languageDidChange() {
        applyLocalization()
        view.window?.title = L10n.tr("app.name")
    }

    @objc private func scanMusicFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = true
        panel.prompt = L10n.tr("button.scanMusic")
        if panel.runModal() == .OK {
            add(urls: panel.urls)
        }
    }

    @objc private func convert() {
        guard items.isEmpty == false else {
            showAlert(title: L10n.tr("alert.noFiles.title"), message: L10n.tr("alert.noFiles.message"))
            return
        }

        convertButton.isEnabled = false
        completedCount = 0
        successCount = 0
        failureCount = 0
        progressIndicator.doubleValue = 0
        items = items.map { ConversionItem(url: $0.url, status: .waiting, message: "") }

        try? FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        let group = DispatchGroup()

        for index in items.indices {
            group.enter()
            mark(index: index, status: .running, message: "")
            conversionQueue.async { [weak self] in
                guard let self else {
                    group.leave()
                    return
                }
                let result = self.convertItem(at: index)
                DispatchQueue.main.async {
                    self.finish(index: index, result: result)
                    group.leave()
                }
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            self.convertButton.isEnabled = true
            self.showAlert(
                title: L10n.tr("alert.done.title"),
                message: L10n.tr("alert.done.message", self.successCount, self.failureCount)
            )
        }
    }

    private func add(urls: [URL]) {
        let found = urls.flatMap { supportedFiles(from: $0) }
        guard found.isEmpty == false else {
            updateSummary()
            return
        }

        var existing = Set(items.map { $0.url.standardizedFileURL.path })
        var newItems = items
        for url in found {
            let path = url.standardizedFileURL.path
            if existing.insert(path).inserted {
                newItems.append(ConversionItem(url: url, status: .waiting, message: ""))
            }
        }

        items = newItems.sorted { $0.url.lastPathComponent.localizedStandardCompare($1.url.lastPathComponent) == .orderedAscending }
    }

    private func supportedFiles(from url: URL) -> [URL] {
        var isDirectory = ObjCBool(false)
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return []
        }

        if isDirectory.boolValue {
            let keys: Set<URLResourceKey> = [.isRegularFileKey]
            guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles]) else {
                return []
            }
            return enumerator.compactMap { item in
                guard let fileURL = item as? URL else { return nil }
                return isSupported(fileURL) ? fileURL : nil
            }
        }

        return isSupported(url) ? [url] : []
    }

    private func isSupported(_ url: URL) -> Bool {
        supportedInputExtensions.contains(url.pathExtension.lowercased())
    }

    private func convertItem(at index: Int) -> Result<URL, Error> {
        do {
            let inputURL = items[index].url
            let outputURL: URL
            if encryptExtDictionary.keys.contains(inputURL.pathExtension.lowercased()) {
                let decoder = try QMDecoder(originFilePath: inputURL.path, outputDirectory: outputDirectory.path)
                let decryptedAudio = try decoder.decryptedAudioData()
                outputURL = try transcoder.write(
                    decryptedAudio: decryptedAudio,
                    sourceURL: inputURL,
                    outputDirectory: outputDirectory,
                    format: selectedOutputFormat
                )
            } else {
                outputURL = try transcoder.write(
                    inputURL: inputURL,
                    outputDirectory: outputDirectory,
                    format: selectedOutputFormat
                )
            }
            return .success(outputURL)
        } catch {
            return .failure(error)
        }
    }

    private var selectedOutputFormat: OutputFormat {
        guard let rawValue = formatPopup.selectedItem?.representedObject as? String,
              let format = OutputFormat(rawValue: rawValue) else {
            return .original
        }
        return format
    }

    private func mark(index: Int, status: ConversionStatus, message: String) {
        guard items.indices.contains(index) else { return }
        items[index].status = status
        items[index].message = message
        tableView.reloadData(forRowIndexes: IndexSet(integer: index), columnIndexes: IndexSet(integersIn: 0..<tableView.numberOfColumns))
        updateSummary()
    }

    private func finish(index: Int, result: Result<URL, Error>) {
        completedCount += 1
        progressIndicator.doubleValue = Double(completedCount) / Double(max(items.count, 1))

        switch result {
        case .success(let outputURL):
            successCount += 1
            mark(index: index, status: .success, message: outputURL.lastPathComponent)
        case .failure(let error):
            failureCount += 1
            mark(index: index, status: .failed, message: error.localizedDescription)
        }
    }

    private func applyLocalization() {
        let selectedFormat = selectedOutputFormat
        titleLabel.stringValue = L10n.tr("app.name")
        subtitleLabel.stringValue = L10n.tr("app.subtitle")
        dropTitleLabel.stringValue = L10n.tr("drop.title")
        dropSubtitleLabel.stringValue = L10n.tr("formats.short")
        addButton.title = L10n.tr("button.addFiles")
        addFolderButton.title = L10n.tr("button.addFolder")
        defaultScanButton.title = L10n.tr("button.scanMusic")
        outputButton.title = L10n.tr("button.output")
        clearButton.title = L10n.tr("button.clear")
        convertButton.title = L10n.tr("button.convert")
        formatLabel.stringValue = L10n.tr("label.format")
        languageLabel.stringValue = L10n.tr("label.language")
        outputTitleLabel.stringValue = L10n.tr("label.outputDirectory")
        rebuildFormatPopup(selected: selectedFormat)
        rebuildLanguagePopup()
        tableView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier("name"))?.title = L10n.tr("table.file")
        tableView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier("status"))?.title = L10n.tr("table.status")
        tableView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier("message"))?.title = L10n.tr("table.result")
        tableView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier("path"))?.title = L10n.tr("table.path")
        tableView.reloadData()
        updateSummary()
    }

    private func rebuildFormatPopup(selected: OutputFormat) {
        formatPopup.removeAllItems()
        for format in OutputFormat.allCases {
            formatPopup.addItem(withTitle: format.localizedTitle)
            formatPopup.lastItem?.representedObject = format.rawValue
        }
        if let item = formatPopup.itemArray.first(where: { ($0.representedObject as? String) == selected.rawValue }) {
            formatPopup.select(item)
        }
    }

    private func rebuildLanguagePopup() {
        let selectedLanguage = AppLanguage.selected
        languagePopup.removeAllItems()
        for language in AppLanguage.allCases {
            languagePopup.addItem(withTitle: language.menuTitle)
            languagePopup.lastItem?.representedObject = language.rawValue
        }
        if let item = languagePopup.itemArray.first(where: { ($0.representedObject as? String) == selectedLanguage.rawValue }) {
            languagePopup.select(item)
        }
    }

    private func updateSummary() {
        if items.isEmpty {
            summaryLabel.stringValue = L10n.tr("summary.empty", L10n.tr("formats.short"))
        } else {
            let breakdown = audioFormatBreakdownText(for: items.map(\.url))
            summaryLabel.stringValue = L10n.tr("summary.items", items.count, outputDirectory.lastPathComponent, selectedOutputFormat.localizedTitle, breakdown)
        }
        convertButton.isEnabled = items.isEmpty == false
        clearButton.isEnabled = items.isEmpty == false
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = title
        alert.informativeText = message
        alert.beginSheetModal(for: view.window ?? NSWindow())
    }
}

extension ViewController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        items.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let tableColumn else { return nil }
        let identifier = tableColumn.identifier
        let cell = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView ?? NSTableCellView()
        cell.identifier = identifier

        let textField: NSTextField
        if let existing = cell.textField {
            textField = existing
        } else {
            textField = NSTextField(labelWithString: "")
            textField.lineBreakMode = .byTruncatingMiddle
            textField.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(textField)
            cell.textField = textField
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
                textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
                textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
            ])
        }

        let item = items[row]
        switch identifier.rawValue {
        case "name":
            textField.stringValue = item.url.lastPathComponent
            textField.textColor = .labelColor
        case "status":
            textField.stringValue = item.status.localizedTitle
            textField.textColor = color(for: item.status)
        case "message":
            textField.stringValue = item.message
            textField.textColor = .secondaryLabelColor
        case "path":
            textField.stringValue = item.url.deletingLastPathComponent().path
            textField.textColor = .secondaryLabelColor
        default:
            textField.stringValue = ""
        }

        return cell
    }

    private func color(for status: ConversionStatus) -> NSColor {
        switch status {
        case .waiting:
            return .secondaryLabelColor
        case .running:
            return .controlAccentColor
        case .success:
            return .systemGreen
        case .failed:
            return .systemRed
        }
    }
}

private final class DropView: NSView {
    var onDrop: (([URL]) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("不支持从 coder 初始化")
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard
        let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] ?? []
        onDrop?(urls)
        return urls.isEmpty == false
    }
}
