import Cocoa
import Darwin

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
    private let scrollView = NSScrollView()
    private let listStackView = NSStackView()
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
    private let convertSelectedButton = NSButton(title: "", target: nil, action: nil)
    private let clearButton = NSButton(title: "", target: nil, action: nil)
    private let formatLabel = NSTextField(labelWithString: "")
    private let inputFormatLabel = NSTextField(labelWithString: "")
    private let languageLabel = NSTextField(labelWithString: "")
    private let outputTitleLabel = NSTextField(labelWithString: "")
    private let formatPopup = NSPopUpButton()
    private let inputFormatPopup = NSPopUpButton()
    private let languagePopup = NSPopUpButton()
    private let dropView = DropView()

    private var items: [ConversionItem] = [] {
        didSet {
            selectedItemIndexes = selectedItemIndexes.filter { items.indices.contains($0) }
            reloadFileSections()
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
    private let automaticScanQueue = DispatchQueue(label: "yinzhuanxia.automatic-scan.queue", qos: .userInitiated)
    private let transcoder = AudioTranscoder()
    private var completedCount = 0
    private var successCount = 0
    private var failureCount = 0
    private var activeConversionTotal = 0
    private var hasAutomaticallyScannedMusicFolder = false
    private var isAutomaticallyScanningMusicFolder = false
    private var selectedItemIndexes = Set<Int>()

    private var inputFormatOptions: [String] {
        let formats = Set(supportedInputExtensions.map { displayAudioFormat(forFileExtension: $0) })
        return formats.sorted { first, second in
            let firstIndex = preferredFormatDisplayOrder.firstIndex(of: first) ?? Int.max
            let secondIndex = preferredFormatDisplayOrder.firstIndex(of: second) ?? Int.max
            if firstIndex != secondIndex {
                return firstIndex < secondIndex
            }
            return first.localizedStandardCompare(second) == .orderedAscending
        }
    }

    private var sectionRowIndices: [ObjectIdentifier: [Int]] = [:]
    private var sectionTables: [ObjectIdentifier: NSTableView] = [:]
    private var checkboxItemIndexes: [ObjectIdentifier: Int] = [:]

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

        clearButton.target = self
        clearButton.action = #selector(clearItems)

        convertButton.target = self
        convertButton.action = #selector(convert)
        convertButton.bezelStyle = .rounded

        convertSelectedButton.target = self
        convertSelectedButton.action = #selector(convertSelected)
        convertSelectedButton.bezelStyle = .rounded

        formatPopup.target = self
        formatPopup.action = #selector(outputFormatChanged)
        rebuildFormatPopup(selected: .original)

        inputFormatPopup.target = self
        inputFormatPopup.action = #selector(inputFormatChanged)
        rebuildInputFormatPopup(selected: nil)

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

        setupFileList()

        let buttonRow = NSStackView(views: [addButton, addFolderButton, outputButton, clearButton, convertSelectedButton, convertButton])
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 8
        buttonRow.alignment = .centerY

        let optionRow = NSStackView(views: [inputFormatLabel, inputFormatPopup, formatLabel, formatPopup, languageLabel, languagePopup])
        optionRow.orientation = .horizontal
        optionRow.spacing = 8
        optionRow.alignment = .centerY

        let outputRow = NSStackView(views: [outputTitleLabel, outputLabel])
        outputRow.orientation = .horizontal
        outputRow.spacing = 8
        outputRow.alignment = .centerY

        let stack = NSStackView(views: [titleLabel, subtitleLabel, dropView, buttonRow, optionRow, outputRow, scrollView, progressIndicator, summaryLabel])
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

    private func setupFileList() {
        listStackView.orientation = .vertical
        listStackView.alignment = .leading
        listStackView.spacing = 14
        listStackView.edgeInsets = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        listStackView.translatesAutoresizingMaskIntoConstraints = false

        let documentView = NSView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        documentView.addSubview(listStackView)
        NSLayoutConstraint.activate([
            listStackView.leadingAnchor.constraint(equalTo: documentView.leadingAnchor),
            listStackView.trailingAnchor.constraint(equalTo: documentView.trailingAnchor),
            listStackView.topAnchor.constraint(equalTo: documentView.topAnchor),
            listStackView.bottomAnchor.constraint(lessThanOrEqualTo: documentView.bottomAnchor),
            listStackView.widthAnchor.constraint(equalTo: documentView.widthAnchor)
        ])

        scrollView.documentView = documentView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.borderType = .bezelBorder

        NSLayoutConstraint.activate([
            documentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor)
        ])
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
        selectedItemIndexes.removeAll()
        items.removeAll()
        progressIndicator.doubleValue = 0
    }

    @objc private func outputFormatChanged() {
        updateSummary()
    }

    @objc private func inputFormatChanged() {
        if let selectedInputFormat {
            items = items.filter { displayAudioFormat(forFileExtension: $0.url.pathExtension) == selectedInputFormat }
        }
        hasAutomaticallyScannedMusicFolder = false
        automaticallyScanMusicFolder()
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

    @objc private func convert() {
        performConversion(indices: Array(items.indices))
    }

    @objc private func convertSelected() {
        performConversion(indices: selectedItemIndexes.sorted())
    }

    private func performConversion(indices: [Int]) {
        let targetIndices = indices.filter { items.indices.contains($0) }
        guard targetIndices.isEmpty == false else {
            showAlert(title: L10n.tr("alert.noFiles.title"), message: L10n.tr("alert.noFiles.message"))
            return
        }

        convertButton.isEnabled = false
        convertSelectedButton.isEnabled = false
        completedCount = 0
        successCount = 0
        failureCount = 0
        activeConversionTotal = targetIndices.count
        progressIndicator.doubleValue = 0
        for index in targetIndices {
            items[index] = ConversionItem(url: items[index].url, status: .waiting, message: "")
        }

        try? FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        let group = DispatchGroup()

        for index in targetIndices {
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
            self.convertSelectedButton.isEnabled = self.selectedItemIndexes.isEmpty == false
            self.showAlert(
                title: L10n.tr("alert.done.title"),
                message: L10n.tr("alert.done.message", self.successCount, self.failureCount)
            )
        }
    }

    func startAutomaticMusicScan() {
        automaticallyScanMusicFolder()
    }

    private func automaticallyScanMusicFolder() {
        guard hasAutomaticallyScannedMusicFolder == false else { return }
        hasAutomaticallyScannedMusicFolder = true
        isAutomaticallyScanningMusicFolder = true
        updateSummary()

        let musicDirectory = realUserMusicDirectory()

        automaticScanQueue.async { [weak self] in
            guard let self else { return }
            for directory in self.automaticMusicScanDirectories(from: musicDirectory) {
                let files = self.supportedFilesUsingFind(from: directory)
                DispatchQueue.main.async {
                    self.addSupportedFiles(files)
                }
            }
            DispatchQueue.main.async {
                self.isAutomaticallyScanningMusicFolder = false
                self.updateSummary()
            }
        }
    }

    private func supportedFilesUsingFind(from directory: URL) -> [URL] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        let extensionPattern = supportedInputExtensions.sorted()
            .map { "-iname '*.\($0)'" }
            .joined(separator: " -o ")
        process.arguments = [
            "-lc",
            "/usr/bin/find \(shellQuoted(directory.path)) -maxdepth 8 -type f \\( \(extensionPattern) \\) | /usr/bin/head -n 500"
        ]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return []
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0,
              let output = String(data: data, encoding: .utf8) else {
            return []
        }

        return output
            .split(separator: "\n")
            .map { URL(fileURLWithPath: String($0)) }
            .filter(isSupported)
    }

    private func shellQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    private func automaticMusicScanDirectories(from musicDirectory: URL) -> [URL] {
        let priorityDirectories = [
            musicDirectory.appendingPathComponent("音转匣 输出", isDirectory: true),
            musicDirectory.appendingPathComponent("autoMC 输出", isDirectory: true),
            musicDirectory.appendingPathComponent("autoMC Output", isDirectory: true),
            musicDirectory.appendingPathComponent("QQMusic", isDirectory: true),
            musicDirectory.appendingPathComponent("Netease Cloud Music", isDirectory: true),
            musicDirectory.appendingPathComponent("网易云音乐", isDirectory: true)
        ]

        var seen = Set<String>()
        return priorityDirectories.filter { directory in
            var isDirectory = ObjCBool(false)
            let path = directory.standardizedFileURL.path
            return seen.insert(path).inserted
                && FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
                && isDirectory.boolValue
        }
    }

    private func realUserMusicDirectory() -> URL {
        if let passwordEntry = getpwuid(getuid()),
           let home = passwordEntry.pointee.pw_dir {
            return URL(fileURLWithPath: String(cString: home), isDirectory: true)
                .appendingPathComponent("Music", isDirectory: true)
        }
        if let homePath = NSHomeDirectoryForUser(NSUserName()) {
            return URL(fileURLWithPath: homePath, isDirectory: true)
                .appendingPathComponent("Music", isDirectory: true)
        }
        return FileManager.default.urls(for: .musicDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Music", isDirectory: true)
    }

    private func add(urls: [URL]) {
        let found = urls.flatMap { supportedFiles(from: $0) }
        addSupportedFiles(found)
    }

    private func addSupportedFiles(_ found: [URL]) {
        let filtered = found.filter { url in
            guard let selectedInputFormat else { return true }
            return displayAudioFormat(forFileExtension: url.pathExtension) == selectedInputFormat
        }

        guard filtered.isEmpty == false else {
            updateSummary()
            return
        }

        var existing = Set(items.map { $0.url.standardizedFileURL.path })
        var newItems = items
        for url in filtered {
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

    private var selectedInputFormat: String? {
        guard let value = inputFormatPopup.selectedItem?.representedObject as? String,
              value != "all" else {
            return nil
        }
        return value
    }

    private func mark(index: Int, status: ConversionStatus, message: String) {
        guard items.indices.contains(index) else { return }
        items[index].status = status
        items[index].message = message
        reloadFileSections()
        updateSummary()
    }

    private func finish(index: Int, result: Result<URL, Error>) {
        completedCount += 1
        progressIndicator.doubleValue = Double(completedCount) / Double(max(activeConversionTotal, 1))

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
        outputButton.title = L10n.tr("button.output")
        clearButton.title = L10n.tr("button.clear")
        convertButton.title = L10n.tr("button.convert")
        convertSelectedButton.title = L10n.tr("button.convertSelected")
        formatLabel.stringValue = L10n.tr("label.format")
        inputFormatLabel.stringValue = L10n.tr("label.inputFormat")
        languageLabel.stringValue = L10n.tr("label.language")
        outputTitleLabel.stringValue = L10n.tr("label.outputDirectory")
        rebuildFormatPopup(selected: selectedFormat)
        rebuildInputFormatPopup(selected: selectedInputFormat)
        rebuildLanguagePopup()
        reloadFileSections()
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

    private func rebuildInputFormatPopup(selected: String?) {
        inputFormatPopup.removeAllItems()
        inputFormatPopup.addItem(withTitle: L10n.tr("format.all"))
        inputFormatPopup.lastItem?.representedObject = "all"
        for format in inputFormatOptions {
            inputFormatPopup.addItem(withTitle: format)
            inputFormatPopup.lastItem?.representedObject = format
        }
        if let selected,
           let item = inputFormatPopup.itemArray.first(where: { ($0.representedObject as? String) == selected }) {
            inputFormatPopup.select(item)
        } else if let item = inputFormatPopup.itemArray.first {
            inputFormatPopup.select(item)
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

    private func reloadFileSections() {
        sectionRowIndices.removeAll()
        sectionTables.removeAll()
        checkboxItemIndexes.removeAll()
        listStackView.arrangedSubviews.forEach { view in
            listStackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        let groups = audioFormatCounts(for: items.map(\.url))
        for group in groups {
            let indices = items.indices
                .filter { displayAudioFormat(forFileExtension: items[$0].url.pathExtension) == group.format }
                .sorted {
                    items[$0].url.lastPathComponent.localizedStandardCompare(items[$1].url.lastPathComponent) == .orderedAscending
                }
            guard indices.isEmpty == false else { continue }
            let sectionView = makeSectionView(format: group.format, count: group.count, itemIndices: indices)
            listStackView.addArrangedSubview(sectionView)
            sectionView.translatesAutoresizingMaskIntoConstraints = false
            sectionView.widthAnchor.constraint(equalTo: listStackView.widthAnchor).isActive = true
        }
    }

    private func makeSectionView(format: String, count: Int, itemIndices: [Int]) -> NSView {
        let title = NSTextField(labelWithString: L10n.tr("table.group", format, count))
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        title.textColor = .labelColor

        let table = NSTableView()
        table.delegate = self
        table.dataSource = self
        table.allowsMultipleSelection = true
        table.allowsEmptySelection = true
        table.usesAlternatingRowBackgroundColors = true
        table.headerView = NSTableHeaderView()
        table.rowHeight = 26
        configureColumns(for: table)
        sectionRowIndices[ObjectIdentifier(table)] = itemIndices
        sectionTables[ObjectIdentifier(table)] = table
        table.reloadData()
        let selectedRows = IndexSet(itemIndices.indices.filter { selectedItemIndexes.contains(itemIndices[$0]) })
        if selectedRows.isEmpty {
            table.deselectAll(nil)
        } else {
            table.selectRowIndexes(selectedRows, byExtendingSelection: false)
        }

        let tableScrollView = NSScrollView()
        tableScrollView.documentView = table
        tableScrollView.hasVerticalScroller = itemIndices.count > 8
        tableScrollView.hasHorizontalScroller = true
        tableScrollView.borderType = .bezelBorder
        tableScrollView.translatesAutoresizingMaskIntoConstraints = false
        tableScrollView.heightAnchor.constraint(equalToConstant: min(CGFloat(itemIndices.count) * table.rowHeight + 48, 260)).isActive = true

        let sectionStack = NSStackView(views: [title, tableScrollView])
        sectionStack.orientation = .vertical
        sectionStack.alignment = .leading
        sectionStack.spacing = 6
        sectionStack.translatesAutoresizingMaskIntoConstraints = false
        for arrangedView in sectionStack.arrangedSubviews {
            arrangedView.translatesAutoresizingMaskIntoConstraints = false
            arrangedView.widthAnchor.constraint(equalTo: sectionStack.widthAnchor).isActive = true
        }

        return sectionStack
    }

    private func configureColumns(for tableView: NSTableView) {
        let columns: [(String, CGFloat)] = [
            ("select", 44),
            ("name", 260),
            ("status", 120),
            ("message", 220),
            ("path", 360)
        ]

        for column in columns {
            let identifier = NSUserInterfaceItemIdentifier(column.0)
            let tableColumn = NSTableColumn(identifier: identifier)
            tableColumn.width = column.1
            switch column.0 {
            case "select":
                tableColumn.title = L10n.tr("table.select")
                tableColumn.minWidth = 40
                tableColumn.maxWidth = 52
            case "name":
                tableColumn.title = L10n.tr("table.file")
                tableColumn.minWidth = 140
            case "status":
                tableColumn.title = L10n.tr("table.status")
                tableColumn.minWidth = 90
            case "message":
                tableColumn.title = L10n.tr("table.result")
                tableColumn.minWidth = 120
            case "path":
                tableColumn.title = L10n.tr("table.path")
                tableColumn.minWidth = 220
            default:
                break
            }
            tableView.addTableColumn(tableColumn)
        }
    }

    private func updateSummary() {
        if items.isEmpty {
            summaryLabel.stringValue = isAutomaticallyScanningMusicFolder
                ? L10n.tr("summary.scanning")
                : L10n.tr("summary.empty", L10n.tr("formats.short"))
        } else {
            let breakdown = audioFormatBreakdownText(for: items.map(\.url))
            summaryLabel.stringValue = L10n.tr("summary.items", items.count, outputDirectory.lastPathComponent, selectedOutputFormat.localizedTitle, breakdown)
        }
        convertButton.isEnabled = items.isEmpty == false
        convertSelectedButton.isEnabled = selectedItemIndexes.isEmpty == false
        clearButton.isEnabled = items.isEmpty == false
    }

    @objc private func checkboxSelectionChanged(_ sender: NSButton) {
        let identifier = ObjectIdentifier(sender)
        guard let itemIndex = checkboxItemIndexes[identifier], items.indices.contains(itemIndex) else { return }
        if sender.state == .on {
            selectedItemIndexes.insert(itemIndex)
        } else {
            selectedItemIndexes.remove(itemIndex)
        }
        updateTableSelections()
        updateSummary()
    }

    private func updateTableSelections() {
        checkboxItemIndexes.removeAll()
        for (identifier, table) in sectionTables {
            guard let itemIndices = sectionRowIndices[identifier] else { continue }
            let selectedRows = IndexSet(itemIndices.indices.filter { selectedItemIndexes.contains(itemIndices[$0]) })
            if selectedRows.isEmpty {
                table.deselectAll(nil)
            } else {
                table.selectRowIndexes(selectedRows, byExtendingSelection: false)
            }
            table.reloadData()
        }
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
    func tableViewSelectionDidChange(_ notification: Notification) {
        var nextSelection = Set<Int>()
        for (identifier, table) in sectionTables {
            guard let itemIndices = sectionRowIndices[identifier] else { continue }
            for row in table.selectedRowIndexes where itemIndices.indices.contains(row) {
                nextSelection.insert(itemIndices[row])
            }
        }
        selectedItemIndexes = nextSelection
        checkboxItemIndexes.removeAll()
        for table in sectionTables.values {
            table.reloadData()
        }
        updateSummary()
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        sectionRowIndices[ObjectIdentifier(tableView)]?.count ?? 0
    }

    func tableView(_ tableView: NSTableView, isGroupRow row: Int) -> Bool {
        return false
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        tableView.rowHeight
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = tableColumn?.identifier ?? NSUserInterfaceItemIdentifier("group")
        let cell = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView ?? NSTableCellView()
        cell.identifier = identifier
        cell.subviews
            .filter { $0 is NSButton }
            .forEach { $0.removeFromSuperview() }

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

        textField.font = .systemFont(ofSize: NSFont.systemFontSize)
        textField.textColor = .labelColor
        cell.wantsLayer = false
        cell.layer?.backgroundColor = nil
        cell.layer?.cornerRadius = 0

        guard let itemIndices = sectionRowIndices[ObjectIdentifier(tableView)],
              itemIndices.indices.contains(row),
              items.indices.contains(itemIndices[row]) else {
            textField.stringValue = ""
            return cell
        }

        let item = items[itemIndices[row]]
        let itemIndex = itemIndices[row]
        switch identifier.rawValue {
        case "select":
            textField.stringValue = ""
            let checkbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(checkboxSelectionChanged(_:)))
            checkbox.state = selectedItemIndexes.contains(itemIndex) ? .on : .off
            checkbox.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(checkbox)
            checkboxItemIndexes[ObjectIdentifier(checkbox)] = itemIndex
            NSLayoutConstraint.activate([
                checkbox.centerXAnchor.constraint(equalTo: cell.centerXAnchor),
                checkbox.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
            ])
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
        layer?.cornerRadius = 8
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
