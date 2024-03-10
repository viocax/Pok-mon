//
//  PokemonDetailInfoCell.swift
//  Pokmon
//
//  Created by Jie liang Huang on 2024/3/10.
//

import UIKit
import RxSwift
import RxCocoa

class PokemonDetailInfoCell: UITableViewCell {

    @IBOutlet weak var pageControl: UIPageControl!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var subNameLabel: UILabel!
    @IBOutlet weak var typesStackView: UIStackView!
    @IBOutlet weak var favoriteButton: UIButton!
    @IBOutlet weak var ImageCollectionViews: UICollectionView!
    @IBOutlet weak var descriptionLabel: UILabel!

    private var disposeBag: DisposeBag = .init()

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        setupUIAttributes()
        
    }
    override func prepareForReuse() {
        super.prepareForReuse()
        disposeBag = .init()
    }

    
    func setupUIAttributes() {
        
        contentView.backgroundColor = .white
        selectionStyle = .none
        pageControl.isHidden = true
        nameLabel.font = .systemFont(ofSize: 18)
        nameLabel.textColor = .black
        subNameLabel.font = .systemFont(ofSize: 14)
        subNameLabel.textColor = .gray
        descriptionLabel.font = .systemFont(ofSize: 14)
        descriptionLabel.textColor = .black
        ImageCollectionViews.isPagingEnabled = true
        ImageCollectionViews.backgroundColor = .white
        ImageCollectionViews.register(UINib(nibName: "GenderImageCollectionCell", bundle: nil), forCellWithReuseIdentifier: "GenderImageCollectionCell")
        let flowlayout = ImageCollectionViews.collectionViewLayout as? UICollectionViewFlowLayout
        flowlayout?.itemSize = .init(width: 116, height: 116)
        flowlayout?.minimumLineSpacing = .zero
        flowlayout?.minimumInteritemSpacing = .zero
        flowlayout?.scrollDirection = .horizontal
        
    }

    func bindView(_ pokemon: PokmonResponse, species: PokemonSpeciesResponse) {
        nameLabel.text = species.names.first(where: { $0.isCN })?.name ?? pokemon.name
        subNameLabel.text = species.names.first(where: { $0.isEN })?.name ?? "-"
        let isCN = Locale.preferredLanguages.first?.contains("zh") ?? true
        descriptionLabel.text = species.flavorEntitys.first(where: { isCN ? $0.isCN : $0.isEN })?.text

        ImageCollectionViews.rx.setDelegate(self)
            .disposed(by: disposeBag)
        pageControl.currentPageIndicatorTintColor = pokemon.types.first?.type.color
        let genders = Driver.just(pokemon.sprites.getGenders())
        
        genders
            .drive(ImageCollectionViews.rx.items) { collection, row, model in
                let cell = collection.dequeueReusableCell(withReuseIdentifier: "GenderImageCollectionCell", for: .init(row: row, section: .zero))
                (cell as? GenderImageCollectionCell)?.bindView(model.0, url: model.1)
                return cell
            }
            .disposed(by: disposeBag)
        genders.map { $0.count < 2 }
            .drive(pageControl.rx.isHidden)
            .disposed(by: disposeBag)
        genders.map(\.count)
            .drive(pageControl.rx.numberOfPages)
            .disposed(by: disposeBag)

        Driver<[any TypeCornerProtocol]>.just(pokemon.types.map(\.type))
            .drive(typesStackView.types)
            .disposed(by: disposeBag)
    }
}

extension PokemonDetailInfoCell: UICollectionViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView.bounds.width > .zero, pageControl.isHidden == false else { return }
        let page = scrollView.contentOffset.x / scrollView.bounds.width
        pageControl.currentPage = Int(page)
    }
}
