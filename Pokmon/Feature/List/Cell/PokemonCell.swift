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
    private let numberLabel: UILabel = .init()
    private let nameLabel: UILabel = .init()
    private let heightLabel: UILabel = .init()
    private let widthLabel: UILabel = .init()
    private let divider: UIView = .init()
    private let typesStackView: UIStackView = .init()
    private var disposeBag: DisposeBag = .init()
    private let animation: UIViewPropertyAnimator = .init(duration: 0.3, curve: .linear)

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
        thumbNailImageView.image = .placeHolder
    }

    func setupUIAttribute() {
        selectionStyle = .none
        cornerView.layer.cornerRadius = 8
        cornerView.layer.borderWidth = 1
        thumbNailImageView.contentMode = .scaleAspectFit
        numberLabel.textColor = .black
        numberLabel.font = .systemFont(ofSize: 18)
        nameLabel.textColor = .gray
        nameLabel.font = .systemFont(ofSize: 16)
        widthLabel.font = .systemFont(ofSize: 14)
        widthLabel.adjustsFontSizeToFitWidth = true
        heightLabel.font = .systemFont(ofSize: 14)
        heightLabel.adjustsFontSizeToFitWidth = true
        divider.backgroundColor = .gray
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
        cornerView.addSubview(divider)
        cornerView.addSubview(widthLabel)
        cornerView.addSubview(heightLabel)
        (contentView.subviews + cornerView.subviews)
            .forEach {
                $0.translatesAutoresizingMaskIntoConstraints = false
            }
        NSLayoutConstraint.activate([
            cornerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            cornerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            cornerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            cornerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),

            thumbNailImageView.leadingAnchor.constraint(equalTo: cornerView.leadingAnchor, constant: 8),
            thumbNailImageView.topAnchor.constraint(equalTo: cornerView.topAnchor, constant: 8),
            thumbNailImageView.widthAnchor.constraint(equalToConstant: 60),
            thumbNailImageView.heightAnchor.constraint(equalToConstant: 60),
            
            divider.trailingAnchor.constraint(equalTo: cornerView.trailingAnchor, constant: -100),
            divider.centerYAnchor.constraint(equalTo: cornerView.centerYAnchor),
            divider.widthAnchor.constraint(equalToConstant: 1),
            divider.topAnchor.constraint(equalTo: thumbNailImageView.topAnchor, constant: 24),
            divider.bottomAnchor.constraint(equalTo: typesStackView.bottomAnchor, constant: -24),
            
            widthLabel.leadingAnchor.constraint(equalTo: divider.trailingAnchor, constant: 16),
            widthLabel.trailingAnchor.constraint(equalTo: cornerView.trailingAnchor, constant: -8),
            widthLabel.centerYAnchor.constraint(equalTo: cornerView.centerYAnchor, constant: 20),
            
            heightLabel.leadingAnchor.constraint(equalTo: widthLabel.leadingAnchor),
            heightLabel.trailingAnchor.constraint(equalTo: widthLabel.trailingAnchor),
            heightLabel.centerYAnchor.constraint(equalTo: cornerView.centerYAnchor, constant: -20),


            numberLabel.leadingAnchor.constraint(equalTo: thumbNailImageView.trailingAnchor, constant: 8),
            numberLabel.heightAnchor.constraint(equalToConstant: 24),
            numberLabel.trailingAnchor.constraint(equalTo: divider.leadingAnchor, constant: -16),
            numberLabel.topAnchor.constraint(equalTo: thumbNailImageView.topAnchor, constant: 6),

            nameLabel.leadingAnchor.constraint(equalTo: numberLabel.leadingAnchor),
            nameLabel.heightAnchor.constraint(equalToConstant: 20),
            nameLabel.trailingAnchor.constraint(equalTo: numberLabel.trailingAnchor),
            nameLabel.topAnchor.constraint(equalTo: numberLabel.bottomAnchor),
            nameLabel.bottomAnchor.constraint(lessThanOrEqualTo: thumbNailImageView.bottomAnchor),

            typesStackView.topAnchor.constraint(equalTo: thumbNailImageView.bottomAnchor),
            typesStackView.leadingAnchor.constraint(greaterThanOrEqualTo: thumbNailImageView.leadingAnchor),
            typesStackView.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
            typesStackView.heightAnchor.constraint(equalToConstant: 24),
            typesStackView.bottomAnchor.constraint(equalTo: cornerView.bottomAnchor, constant: -8)
        ])
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
            .drive(typesStackView.types)
            .disposed(by: disposeBag)
        output.number
            .drive(numberLabel.rx.text)
            .disposed(by: disposeBag)
        output.width
            .withLatestFrom(output.types) { width, types in
                return (width, types.first?.color)
            }
            .drive(widthText)
            .disposed(by: disposeBag)
        output.height
            .withLatestFrom(output.types) { height, types in
                return (height, types.first?.color)
            }
            .drive(heightText)
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
    func setup(label: UILabel, title: String, value: String, color: UIColor?) {
        var content = AttributedString()
        var title = AttributedString(title)
        title.font = .system(size: 12)
        title.foregroundColor = .black
        content += title
        var values = AttributedString(value)
        values.font = .system(size: 10)
        values.foregroundColor = color
        content += values
        label.attributedText = .init(content)
    }
    var heightText: Binder<(Int, UIColor?)> {
        return Binder(self) { cell, turple in
            let value = "\(Double(turple.0) / 10) m"
            cell.setup(label: cell.heightLabel, title: "H: ", value: value, color: turple.1)
        }
    }
    var widthText: Binder<(Int, UIColor?)> {
        return Binder(self) { cell, turple in
            let value = "\(Double(turple.0) / 10) kg"
            cell.setup(label: cell.widthLabel, title: "W: ", value: value, color: turple.1)
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
