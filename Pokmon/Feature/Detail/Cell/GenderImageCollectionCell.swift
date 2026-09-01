//
//  GenderImageCollectionCell.swift
//  Pokmon
//
//  Created by Jie liang Huang on 2024/3/10.
//

import UIKit
import Kingfisher

enum Gender: String {
    case male, female
}

class GenderImageCollectionCell: UICollectionViewCell {

    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var genderImageView: UIImageView!

    override func awakeFromNib() {
        super.awakeFromNib()
        // `awakeFromNib()` 來自 NSObject，UIKit 沒有把它標成 @MainActor，
        // 所以即使這個類別本身是 MainActor 隔離的，覆寫的主體仍被視為 nonisolated。
        // nib 載入依契約在主執行緒發生，這個假設不是賭。
        MainActor.assumeIsolated {
            genderImageView.contentMode = .scaleAspectFit
            iconImageView.contentMode = .scaleAspectFit
            iconImageView.image = .placeHolder
            iconImageView.rotate()
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        iconImageView.kf.cancelDownloadTask()
        iconImageView.image = .placeHolder
    }
    

    func bindView(_ gender: Gender, url: String) {
        genderImageView.image = .init(named: gender.rawValue)
        iconImageView.kf.setImage(with: URL(string: url), placeholder: UIImage.placeHolder, completionHandler: { [weak self] result in
            self?.iconImageView.stopRotate()
            switch result {
            case .failure:
                self?.iconImageView.image = .errorImage
            default:
                break
            }
        })
    }
}
