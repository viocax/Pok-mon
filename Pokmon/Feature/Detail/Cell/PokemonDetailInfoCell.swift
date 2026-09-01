//
//  PokemonDetailInfoCell.swift
//  Pokmon
//
//  Created by Jie liang Huang on 2024/3/10.
//

import UIKit

@MainActor
protocol PokemonDetailInfoCellDelegate: AnyObject {
    func clickFavoriteSelected(_ id: Int)
}

class PokemonDetailInfoCell: UITableViewCell {

    @IBOutlet weak var pageControl: UIPageControl!
    @IBOutlet weak var heightLabel: UILabel!
    @IBOutlet weak var weightLabel: UILabel!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var subNameLabel: UILabel!
    @IBOutlet weak var typesStackView: UIStackView!
    @IBOutlet weak var favoriteButton: UIButton!
    @IBOutlet weak var ImageCollectionViews: UICollectionView!
    @IBOutlet weak var descriptionLabel: UILabel!

    private var observationTokens: [ObservationToken] = []
    private var isFavoriteProvider: (@MainActor () -> Bool)?
    private var pokemonID: Int?
    private lazy var genderDataSource = makeGenderDataSource()

    weak var delegate: PokemonDetailInfoCellDelegate?

    fileprivate enum Section {
        case main
    }

    struct GenderItem: Hashable {
        let gender: Gender
        let url: String
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        setupUIAttributes()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        observationTokens.forEach { $0.cancel() }
        observationTokens = []
        isFavoriteProvider = nil
        pokemonID = nil
        pageControl.currentPage = .zero
        ImageCollectionViews.setContentOffset(.zero, animated: false)
    }

    func setupUIAttributes() {
        contentView.backgroundColor = .white
        selectionStyle = .none
        pageControl.isHidden = true
        nameLabel.font = .systemFont(ofSize: 24)
        nameLabel.textColor = .black
        subNameLabel.font = .systemFont(ofSize: 18)
        subNameLabel.textColor = .gray
        descriptionLabel.font = .systemFont(ofSize: 16)
        descriptionLabel.textColor = .black
        ImageCollectionViews.isPagingEnabled = true
        ImageCollectionViews.backgroundColor = .white
        ImageCollectionViews.delegate = self
        let flowlayout = ImageCollectionViews.collectionViewLayout as? UICollectionViewFlowLayout
        flowlayout?.itemSize = .init(width: 116, height: 116)
        flowlayout?.minimumLineSpacing = .zero
        flowlayout?.minimumInteritemSpacing = .zero
        flowlayout?.scrollDirection = .horizontal

        // action 只掛一次。放進 bindView 的話每次 dequeue 都會多疊一個,
        // prepareForReuse 也清不掉(它只管得到 cancellables)。
        favoriteButton.addAction(
            .init { [weak self] _ in
                guard let id = self?.pokemonID else { return }
                self?.delegate?.clickFavoriteSelected(id)
            },
            for: .touchUpInside
        )
    }

    func bindView(_ info: PokemonDetailStore.Info) {
        let pokemon = info.pokemon
        let species = info.species
        pokemonID = pokemon.id

        nameLabel.text = species.names.first(where: { $0.isCN })?.name ?? pokemon.name
        subNameLabel.text = species.names.first(where: { $0.isEN })?.name ?? "-"
        heightLabel.setUp(title: "H: ", value: "\(Double(pokemon.height) / 10) m", color: pokemon.types.first?.type.color)
        weightLabel.setUp(title: "W: ", value: "\(Double(pokemon.weight) / 10) kg", color: pokemon.types.first?.type.color)
        let isCN = Locale.preferredLanguages.first?.contains("zh") ?? true
        descriptionLabel.text = species.flavorEntitys.first(where: { isCN ? $0.isCN : $0.isEN })?.text

        let types: [any TypeCornerProtocol] = pokemon.types.map(\.type)
        typesStackView.setTypes(types)
        typesStackView.insertArrangedSubview(.init(), at: .zero)

        let genders = pokemon.sprites.getGenders().map { GenderItem(gender: $0.0, url: $0.1) }
        pageControl.currentPageIndicatorTintColor = pokemon.types.first?.type.color
        pageControl.isHidden = genders.count < 2
        pageControl.numberOfPages = genders.count
        apply(genders)

        isFavoriteProvider = info.isFavorite
        observationTokens.append(
            observe { [weak self] in
                guard let self, let isFavorite = self.isFavoriteProvider?() else { return }
                self.favoriteButton.setImage(
                    isFavorite ? .init(named: "starFill") : .init(named: "starEmpty"),
                    for: .normal
                )
            }
        )
    }
}

// MARK: - private

private extension PokemonDetailInfoCell {

    func makeGenderDataSource() -> UICollectionViewDiffableDataSource<Section, GenderItem> {
        let registration = UICollectionView.CellRegistration<GenderImageCollectionCell, GenderItem>(
            cellNib: .init(nibName: "GenderImageCollectionCell", bundle: nil)
        ) { cell, _, item in
            cell.bindView(item.gender, url: item.url)
        }
        return .init(collectionView: ImageCollectionViews) { collectionView, indexPath, item in
            collectionView.dequeueConfiguredReusableCell(using: registration, for: indexPath, item: item)
        }
    }

    func apply(_ genders: [GenderItem]) {
        var snapshot = NSDiffableDataSourceSnapshot<Section, GenderItem>()
        snapshot.appendSections([.main])
        snapshot.appendItems(genders, toSection: .main)
        genderDataSource.apply(snapshot, animatingDifferences: false)
    }
}

// MARK: - UICollectionViewDelegate

extension PokemonDetailInfoCell: UICollectionViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView.bounds.width > .zero, pageControl.isHidden == false else { return }
        let page = scrollView.contentOffset.x / scrollView.bounds.width
        pageControl.currentPage = Int(page)
    }
}

extension UILabel {
    func setUp(title: String, value: String, color: UIColor?) {
        var content = AttributedString()
        var title = AttributedString(title)
        title.font = .systemFont(ofSize: 14)
        title.foregroundColor = UIColor.black
        content += title
        var message = AttributedString(value)
        message.font = .systemFont(ofSize: 12)
        message.foregroundColor = color ?? UIColor.gray
        content += message
        self.attributedText = .init(content)
    }
}
