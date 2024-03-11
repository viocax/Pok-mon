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

final class PokemonCell: UICollectionViewCell {
    
    class CornerGradientView: UIView {
        fileprivate let gradientLayer: CAGradientLayer = .init()
        override init(frame: CGRect) {
            super.init(frame: frame)
            setup()
            
        }
        
        required init?(coder: NSCoder) {
            super.init(coder: coder)
            setup()
        }
        func setup() {
            gradientLayer.startPoint = .init(x: 0, y: 0)
            gradientLayer.endPoint = .init(x: 1, y: 1)
            gradientLayer.cornerRadius = 8
            layer.insertSublayer(gradientLayer, at: .zero)
        }
        override func layoutSubviews() {
            super.layoutSubviews()
            gradientLayer.frame = bounds
        }
    }

    private let cornerView: CornerGradientView = .init()
    private let thumbNailImageView: UIImageView = .init()
    private let numberLabel: UILabel = .init()
    private let nameLabel: UILabel = .init()
    private let typesStackView: UIStackView = .init()
    private var disposeBag: DisposeBag = .init()
    private let animation: UIViewPropertyAnimator = .init(duration: 0.3, curve: .linear)

    override init(frame: CGRect) {
        super.init(frame: frame)
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
        thumbNailImageView.image = .placeHolder
    }
    func setupUIAttribute() {
        cornerView.layer.cornerRadius = 8
        cornerView.layer.borderWidth = 1
        thumbNailImageView.contentMode = .scaleAspectFit
        numberLabel.textColor = .black
        numberLabel.font = .systemFont(ofSize: 18)
        nameLabel.textColor = .gray
        nameLabel.font = .systemFont(ofSize: 16)
        typesStackView.axis = .horizontal
        typesStackView.spacing = 8
        cornerView.layer.borderColor = UIColor.gray.cgColor
        thumbNailImageView.image = .placeHolder
        thumbNailImageView.rotate()
    }

    func setupLayout() {
        contentView.backgroundColor = .white
        contentView.addSubview(cornerView)
        cornerView.addSubview(thumbNailImageView)
        cornerView.addSubview(numberLabel)
        cornerView.addSubview(nameLabel)
        cornerView.addSubview(typesStackView)
        (contentView.subviews + cornerView.subviews)
            .forEach {
                $0.translatesAutoresizingMaskIntoConstraints = false
            }
        NSLayoutConstraint.activate([
            cornerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            cornerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            cornerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            cornerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),

            thumbNailImageView.topAnchor.constraint(equalTo: cornerView.topAnchor, constant: 8),
            thumbNailImageView.leadingAnchor.constraint(equalTo: cornerView.leadingAnchor),
            thumbNailImageView.bottomAnchor.constraint(equalTo: cornerView.bottomAnchor, constant: -8),
            thumbNailImageView.trailingAnchor.constraint(equalTo: cornerView.trailingAnchor),

            numberLabel.leadingAnchor.constraint(equalTo: cornerView.leadingAnchor, constant: 16),
            numberLabel.trailingAnchor.constraint(equalTo: cornerView.trailingAnchor, constant: -8),
            numberLabel.topAnchor.constraint(equalTo: cornerView.topAnchor, constant: 8),
            numberLabel.heightAnchor.constraint(equalToConstant: 24),

            nameLabel.leadingAnchor.constraint(equalTo: numberLabel.leadingAnchor, constant: 8),
            nameLabel.trailingAnchor.constraint(equalTo: numberLabel.trailingAnchor),
            nameLabel.topAnchor.constraint(equalTo: numberLabel.bottomAnchor),
            nameLabel.bottomAnchor.constraint(lessThanOrEqualTo: typesStackView.topAnchor, constant: -8),

            typesStackView.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            typesStackView.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
            typesStackView.bottomAnchor.constraint(equalTo: cornerView.bottomAnchor, constant: -8),
            typesStackView.heightAnchor.constraint(equalToConstant: 24),
        ])
        numberLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        numberLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        nameLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        nameLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
    }
    func bindView(_ viewModel: CellViewModel) {
        let bindViewRelay = PublishRelay<Void>()
        defer { bindViewRelay.accept(()) }
        let input = CellViewModel
            .Input(
                bindView: bindViewRelay.asDriver(onErrorDriveWith: .never())
            )
        let output = viewModel.transform(input)
        output.name
            .drive(nameLabel.rx.text)
            .disposed(by: disposeBag)
        output.imageURL
            .drive(imageURL)
            .disposed(by: disposeBag)
        output.types
            .compactMap(\.first?.color.cgColor)
            .drive(cornerView.layer.rx.borderColor)
            .disposed(by: disposeBag)
        output.types
            .drive(onNext: { [weak self] types in
                self?.typesStackView.types.onNext(types)
                self?.typesStackView.insertArrangedSubview(.init(), at: .zero)
                self?.cornerView.gradientLayer.colors = [
                    types.first?.color.cgColor ?? UIColor.white.cgColor,
                    UIColor.white.cgColor
                ]
            })
            .disposed(by: disposeBag)
        output.number
            .drive(numberLabel.rx.text)
            .disposed(by: disposeBag)
    }
    var imageURL: Binder<String> {
        return Binder(self.thumbNailImageView) { image, urlString in
            image.kf.setImage(with: URL(string: urlString), placeholder: UIImage.placeHolder, completionHandler: { result in
                image.stopRotate()
                switch result {
                case .failure:
                    image.image = .errorImage
                default:
                    break
                }
            })
        }
    }
}

extension UIStackView {
    var types: Binder<[any TypeCornerProtocol]> {
        return Binder(self) { stackView, types in
            // TODO: 優化
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
