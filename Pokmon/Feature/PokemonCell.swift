//
//  PokemonCell.swift
//  Pokmon
//
//  Created by drake on 2024/3/8.
//

import UIKit
import RxSwift
import RxCocoa
import Kingfisher

final class PokemonCell: UITableViewCell {

    private let cornerView: UIView = .init()
    private let thumbNailImageView: UIImageView = .init()
    private let nameLabel: UILabel = .init()
    private let isFavoriteButton: UIButton = .init()
    private let typesStackView: UIStackView = .init()
    private var disposeBag: DisposeBag = .init()
    private let animation: UIViewPropertyAnimator = .init(duration: 0.3, curve: .linear)
    static let placeHolder: UIImage? = UIImage(named: "pokeball")
    static let errorImage: UIImage? = .init(named: "errorImage")

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUIAttribute()
        setupLayout()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUIAttribute()
        setupLayout()
    }
    override func prepareForReuse() {
        super.prepareForReuse()
        disposeBag = .init()
        thumbNailImageView.kf.cancelDownloadTask()
        thumbNailImageView.image = Self.placeHolder
    }

    func setupUIAttribute() {
        selectionStyle = .none
        cornerView.layer.cornerRadius = 8
        cornerView.layer.borderWidth = 1
        thumbNailImageView.contentMode = .scaleAspectFit
        nameLabel.textColor = .black
        nameLabel.textAlignment = .right
        nameLabel.font = .systemFont(ofSize: 16)
        isFavoriteButton.setImage(.init(systemName: "star"), for: .normal)
        typesStackView.axis = .horizontal
        typesStackView.spacing = 8
        cornerView.layer.borderColor = UIColor.gray.cgColor
        thumbNailImageView.image = Self.placeHolder
        thumbNailImageView.rotate()
    }
    func setupLayout() {
        contentView.backgroundColor = .white
        contentView.addSubview(cornerView)
        cornerView.addSubview(thumbNailImageView)
        cornerView.addSubview(nameLabel)
        cornerView.addSubview(isFavoriteButton)
        cornerView.addSubview(typesStackView)
        (contentView.subviews + cornerView.subviews)
            .forEach {
                $0.translatesAutoresizingMaskIntoConstraints = false
            }
        NSLayoutConstraint.activate([
            cornerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            cornerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),
            cornerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            cornerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),

            thumbNailImageView.leadingAnchor.constraint(equalTo: cornerView.leadingAnchor, constant: 16),
            thumbNailImageView.topAnchor.constraint(equalTo: cornerView.topAnchor, constant: 8),
            thumbNailImageView.widthAnchor.constraint(equalToConstant: 60),
            thumbNailImageView.heightAnchor.constraint(equalToConstant: 60),
            thumbNailImageView.bottomAnchor.constraint(equalTo: cornerView.bottomAnchor, constant: -8),

            isFavoriteButton.trailingAnchor.constraint(equalTo: cornerView.trailingAnchor, constant: -16),
            isFavoriteButton.centerYAnchor.constraint(equalTo: cornerView.centerYAnchor),
            isFavoriteButton.widthAnchor.constraint(equalToConstant: 44),
            isFavoriteButton.heightAnchor.constraint(equalToConstant: 44),

            nameLabel.leadingAnchor.constraint(equalTo: thumbNailImageView.trailingAnchor, constant: 8),
            nameLabel.heightAnchor.constraint(equalToConstant: 28),
            nameLabel.trailingAnchor.constraint(equalTo: isFavoriteButton.leadingAnchor, constant: -8),
            nameLabel.topAnchor.constraint(equalTo: thumbNailImageView.topAnchor),

            typesStackView.bottomAnchor.constraint(equalTo: thumbNailImageView.bottomAnchor),
            typesStackView.leadingAnchor.constraint(greaterThanOrEqualTo: nameLabel.leadingAnchor),
            typesStackView.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
            typesStackView.heightAnchor.constraint(equalToConstant: 24)
        ])
    }
    func bindView(_ viewModel: CellViewModel) {
        let bindViewRelay = PublishRelay<Void>()
        defer { bindViewRelay.accept(()) }
        let input = CellViewModel
            .Input(
                bindView: bindViewRelay.asDriver(onErrorDriveWith: .never()),
                clickIsFavior: isFavoriteButton.rx.tap.asDriver()
            )
        let output = viewModel.transform(input)
        output.name
            .drive(nameLabel.rx.text)
            .disposed(by: disposeBag)
        output.imageURL
            .drive(imageURL)
            .disposed(by: disposeBag)
        output.isFavior
            .drive(isFaviorite)
            .disposed(by: disposeBag)
        output.types
            .drive(types)
            .disposed(by: disposeBag)
    }
    var imageURL: Binder<String> {
        return Binder(self.thumbNailImageView) { image, urlString in
            image.kf.setImage(with: URL(string: urlString), placeholder: Self.placeHolder, completionHandler: { result in
                image.stopRotate()
                switch result {
                case .failure:
                    image.image = Self.errorImage
                default:
                    break
                }
            })
        }
    }
    var isFaviorite: Binder<Bool> {
        return Binder(isFavoriteButton) { button, isFaviorite in
            button.setImage(isFaviorite ? .init(systemName: "star.fill") : .init(systemName: "star"), for: .normal)
        }
    }
    var types: Binder<[any TypeCornerProtocol]> {
        return Binder(self) { cell, types in
            // TODO: 優化
            let stackView = cell.typesStackView
            cell.cornerView.layer.borderColor = types.first?.color.cgColor
            stackView.arrangedSubviews.forEach {
                $0.removeFromSuperview()
            }
            types.map(TypeCornerButton.init)
                .forEach { button in
                    stackView.addArrangedSubview(button)
                }
        }
    }
}
