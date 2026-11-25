import CoreText
import UIKit

/// The emoji page of the keyboard: recently used first, then Unicode's
/// categories, scrolled sideways like Apple's. A collection view reuses its
/// cells, so browsing all of them keeps the keyboard's memory small.
@MainActor
final class EmojiPanel: UIView, UICollectionViewDataSource, UICollectionViewDelegate {
    var onPick: ((String) -> Void)?

    private let sections: [[String]]
    private let collection: UICollectionView
    private let bar = UIStackView()

    static let titles = ["🕘", "😀", "🐻", "🍔", "⚽️", "🚗", "💡", "❤️", "🏳️"]

    /// Rows in the grid: as many as fit at about Apple's size (46 pt per
    /// emoji, as in Hex), at least three. Set before the first layout.
    private var rows = 3

    init() {
        sections = [EmojiRecents.load()] + EmojiCatalog.categories
        let configuration = UICollectionViewCompositionalLayoutConfiguration()
        configuration.scrollDirection = .horizontal
        var rowCount = 3
        let layout = UICollectionViewCompositionalLayout(
            sectionProvider: { _, environment in
                EmojiPanel.section(rows: rowCount, height: environment.container.effectiveContentSize.height)
            }, configuration: configuration)
        collection = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(frame: .zero)
        collection.backgroundColor = .clear
        collection.showsHorizontalScrollIndicator = false
        collection.register(EmojiCell.self, forCellWithReuseIdentifier: EmojiCell.id)
        collection.dataSource = self
        collection.delegate = self
        collection.accessibilityIdentifier = "openDictate.emoji"
        rowsChanged = { rowCount = $0 }

        bar.distribution = .fillEqually
        for (index, title) in Self.titles.enumerated() {
            var configuration = UIButton.Configuration.plain()
            configuration.title = title
            configuration.background.cornerRadius = 6
            let button = UIButton(configuration: configuration)
            button.addAction(UIAction { [weak self] _ in self?.jump(to: index) }, for: .touchUpInside)
            bar.addArrangedSubview(button)
        }
        let stack = UIStackView(arrangedSubviews: [collection, bar])
        stack.axis = .vertical
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            bar.heightAnchor.constraint(equalToConstant: 28)
        ])
        markCategory(sections[0].isEmpty ? 1 : 0)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    private var rowsChanged: ((Int) -> Void)?

    override func layoutSubviews() {
        super.layoutSubviews()
        let fitting = max(3, Int(collection.bounds.height / 46))
        if fitting != rows, collection.bounds.height > 0 {
            rows = fitting
            rowsChanged?(fitting)
            collection.collectionViewLayout.invalidateLayout()
        }
    }

    /// Square cells in columns of `rows`, filled top down, so a column a
    /// category leaves half empty keeps its emoji at the top.
    private static func section(rows: Int, height: CGFloat) -> NSCollectionLayoutSection {
        let side = floor(height / CGFloat(rows))
        let item = NSCollectionLayoutItem(
            layoutSize: .init(widthDimension: .absolute(side), heightDimension: .absolute(side)))
        let group = NSCollectionLayoutGroup.vertical(
            layoutSize: .init(widthDimension: .absolute(side), heightDimension: .absolute(side * CGFloat(rows))),
            repeatingSubitem: item, count: rows)
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 8)
        return section
    }

    /// The bar shows the category in view.
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let probe = CGPoint(x: scrollView.contentOffset.x + 12, y: scrollView.bounds.height / 2)
        if let path = collection.indexPathForItem(at: probe) { markCategory(path.section) }
    }

    private func markCategory(_ section: Int) {
        for (index, view) in bar.arrangedSubviews.enumerated() {
            guard let button = view as? UIButton else { continue }
            button.configuration?.background.backgroundColor = index == section ? .systemGray4 : .clear
            button.isSelected = index == section
        }
    }

    private func jump(to section: Int) {
        guard section < sections.count, !sections[section].isEmpty else { return }
        collection.scrollToItem(at: IndexPath(item: 0, section: section), at: .left, animated: false)
        markCategory(section)
    }

    func numberOfSections(in collectionView: UICollectionView) -> Int { sections.count }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        sections[section].count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath)
        -> UICollectionViewCell
    {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: EmojiCell.id, for: indexPath)
        (cell as? EmojiCell)?.label.text = sections[indexPath.section][indexPath.item]
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let emoji = sections[indexPath.section][indexPath.item]
        EmojiRecents.add(emoji)
        onPick?(emoji)
    }
}

private final class EmojiCell: UICollectionViewCell {
    static let id = "emoji"
    let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        label.textAlignment = .center
        label.frame = contentView.bounds
        label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        contentView.addSubview(label)
        isAccessibilityElement = true
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    /// About four fifths of the cell, as on Apple's emoji keyboard.
    override func layoutSubviews() {
        super.layoutSubviews()
        label.font = .systemFont(ofSize: floor(bounds.height * 0.8))
    }

    /// The emoji under the finger lights up while it is pressed.
    override var isHighlighted: Bool {
        didSet { contentView.backgroundColor = isHighlighted ? .systemGray4 : .clear }
    }

    override var accessibilityLabel: String? {
        get { label.text }
        set {}
    }
}

/// Unicode's emoji in its order, grouped into the panel's categories.
enum EmojiCatalog {
    static let categories: [[String]] = {
        var groups = Array(repeating: [String](), count: 8)
        let font = CTFontCreateWithName("AppleColorEmoji" as CFString, 20, nil)
        guard let url = Bundle.main.url(forResource: "emoji", withExtension: "txt"),
            let text = try? String(contentsOf: url, encoding: .utf8)
        else { return groups }
        for line in text.split(separator: "\n") where !line.hasPrefix("#") {
            let parts = line.split(separator: "\t")
            guard parts.count == 2, let index = Int(parts[0]), groups.indices.contains(index) else { continue }
            let emoji = String(parts[1])
            if canDraw(emoji, with: font) { groups[index].append(emoji) }
        }
        return groups
    }()

    /// An emoji newer than this iOS shows as a box; a single character can be
    /// checked against the emoji font. Sequences are kept.
    static func canDraw(_ emoji: String, with font: CTFont) -> Bool {
        let scalars = emoji.unicodeScalars.filter { $0.value != 0xFE0F }
        guard scalars.count == 1, let scalar = scalars.first else {
            // A sequence this iOS does not know falls apart into several glyphs.
            let line = CTLineCreateWithAttributedString(
                NSAttributedString(string: emoji, attributes: [.font: font]) as CFAttributedString)
            return CTLineGetGlyphCount(line) == 1
        }
        var characters = Array(String(scalar).utf16)
        var glyphs = [CGGlyph](repeating: 0, count: characters.count)
        return CTFontGetGlyphsForCharacters(font, &characters, &glyphs, characters.count)
    }
}

/// The last emoji picked, newest first, kept in the keyboard's own settings:
/// they never leave the iPhone and need no Full Access.
enum EmojiRecents {
    private static let key = "emoji.recents"
    static let limit = 30

    static func load(from defaults: UserDefaults = .standard) -> [String] {
        defaults.stringArray(forKey: key) ?? []
    }

    static func add(_ emoji: String, to defaults: UserDefaults = .standard) {
        var list = load(from: defaults).filter { $0 != emoji }
        list.insert(emoji, at: 0)
        defaults.set(Array(list.prefix(limit)), forKey: key)
    }
}
