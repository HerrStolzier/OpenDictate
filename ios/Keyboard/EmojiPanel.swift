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

    init() {
        sections = [EmojiRecents.load()] + EmojiCatalog.categories
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 40, height: 40)
        layout.minimumLineSpacing = 2
        layout.minimumInteritemSpacing = 2
        layout.sectionInset = UIEdgeInsets(top: 0, left: 4, bottom: 0, right: 8)
        collection = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(frame: .zero)
        collection.backgroundColor = .clear
        collection.showsHorizontalScrollIndicator = false
        collection.register(EmojiCell.self, forCellWithReuseIdentifier: EmojiCell.id)
        collection.dataSource = self
        collection.delegate = self
        collection.accessibilityIdentifier = "openDictate.emoji"

        bar.distribution = .fillEqually
        for (index, title) in Self.titles.enumerated() {
            let button = UIButton(type: .system)
            button.setTitle(title, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 18)
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
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    /// Four rows of emoji in whatever height the keyboard gives the panel.
    override func layoutSubviews() {
        super.layoutSubviews()
        guard let layout = collection.collectionViewLayout as? UICollectionViewFlowLayout else { return }
        let side = max(24, floor((collection.bounds.height - 3 * layout.minimumInteritemSpacing) / 4))
        if layout.itemSize.height != side {
            layout.itemSize = CGSize(width: side, height: side)
            layout.invalidateLayout()
        }
    }

    private func jump(to section: Int) {
        guard section < sections.count, !sections[section].isEmpty else { return }
        collection.scrollToItem(at: IndexPath(item: 0, section: section), at: .left, animated: false)
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
        label.font = .systemFont(ofSize: 28)
        label.textAlignment = .center
        label.frame = contentView.bounds
        label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        contentView.addSubview(label)
        isAccessibilityElement = true
    }

    required init?(coder: NSCoder) { fatalError("not used") }

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
        guard scalars.count == 1, let scalar = scalars.first else { return true }
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
