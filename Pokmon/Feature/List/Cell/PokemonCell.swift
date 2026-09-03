//
//  PokemonCell.swift
//  Pokmon
//
//  Created by drake on 2024/3/8.
//

import UIKit
import Kingfisher

final class PokemonCell: UICollectionViewCell {

    private let cornerView: CornerGradientView = .init()
    private let thumbNailImageView: UIImageView = .init()
    private let numberLabel: UILabel = .init()
    private let nameLabel: UILabel = .init()
    private let typesStackView: UIStackView = .init()
    private weak var viewModel: CellViewModel?
    private var observationTokens: [ObservationToken] = []
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
        observationTokens.forEach { $0.cancel() }
        observationTokens = []
        viewModel?.cancel()
        viewModel = nil
        thumbNailImageView.kf.cancelDownloadTask()
        resetContent()
    }

    func bindView(_ viewModel: CellViewModel) {
        self.viewModel = viewModel

        observationTokens = [
            observe { [weak self] in
                guard let self, let viewModel = self.viewModel else { return }
                self.numberLabel.text = viewModel.numberText
            },

            observe { [weak self] in
                guard let self, let viewModel = self.viewModel else { return }
                self.nameLabel.text = viewModel.displayName
            },

            observe { [weak self] in
                guard let self, let viewModel = self.viewModel,
                      let urlString = viewModel.imageURL else { return }
                self.setImage(urlString)
            },

            observe { [weak self] in
                guard let self, let viewModel = self.viewModel else { return }
                let types = viewModel.types
                guard !types.isEmpty else { return }
                self.cornerView.layer.borderColor = types.first?.color.cgColor
                self.typesStackView.setTypes(types)
                self.typesStackView.insertArrangedSubview(.init(), at: .zero)
                self.cornerView.gradientLayer.colors = [
                    types.first?.color.cgColor ?? UIColor.white.cgColor,
                    UIColor.white.cgColor
                ]
            }
        ]

        viewModel.bindView()
    }
}

// MARK: private
private extension PokemonCell {
    func setImage(_ urlString: String) {
        thumbNailImageView.kf.setImage(
            with: URL(string: urlString),
            placeholder: UIImage.placeHolder,
            completionHandler: { [weak self] result in
                guard let self else { return }

                // 取消（prepareForReuse 的 cancelDownloadTask）與「已不是當前請求」
                // （舊 binding 的結果在 cell 重新綁定後才回來）都會走 failure，
                // 但兩者都不是載入失敗。Kingfisher 在 task identity 不符時仍然會
                // 呼叫這裡，而且連成功的過期請求也包成 failure，所以必須先濾掉，
                // 否則會把 errorImage 蓋到下一格上，也會停掉剛重啟的轉圈。
                if case .failure(let error) = result,
                   error.isTaskCancelled || error.isNotCurrentTask {
                    return
                }

                self.thumbNailImageView.stopRotate()
                if case .failure = result {
                    self.thumbNailImageView.image = .errorImage
                }
            }
        )
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
        resetContent()
    }

    /// 內容欄位的初始狀態，init 與 `prepareForReuse` 共用同一份定義。
    ///
    /// 這裡的每一項都對應一個「會 early return 的 observe closure」：
    /// `types` 為空時第四個 closure 直接 return，`imageURL` 為 nil 時第三個直接
    /// return——不在這裡清，重用後就會留著上一格的資料。
    func resetContent() {
        numberLabel.text = nil
        nameLabel.text = nil
        typesStackView.setTypes([])
        cornerView.layer.borderColor = UIColor.gray.cgColor
        cornerView.gradientLayer.colors = nil
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
}
