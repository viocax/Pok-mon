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
            resetContent()
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        iconImageView.kf.cancelDownloadTask()
        resetContent()
    }

    func bindView(_ gender: Gender, url: String) {
        genderImageView.image = .init(named: gender.rawValue)
        iconImageView.kf.setImage(
            with: URL(string: url),
            placeholder: UIImage.placeHolder,
            completionHandler: { [weak self] result in
                guard let self else { return }

                // 跟 PokemonCell 同一個理由：取消（prepareForReuse 的
                // cancelDownloadTask）與「已不是當前請求」都會走 failure，但都不是
                // 載入失敗。不濾掉就會把 errorImage 蓋到下一格，也會停掉剛重啟的轉圈。
                if case .failure(let error) = result,
                   error.isTaskCancelled || error.isNotCurrentTask {
                    return
                }

                self.iconImageView.stopRotate()
                if case .failure = result {
                    self.iconImageView.image = .errorImage
                }
            }
        )
    }

    /// 內容欄位的初始狀態，`awakeFromNib` 與 `prepareForReuse` 共用同一份定義。
    ///
    /// `rotate()` 原本只在 `awakeFromNib` 掛一次，而每次載入完成都會 `stopRotate`，
    /// 所以 cell 第一次載完圖之後就再也不轉了。
    private func resetContent() {
        iconImageView.image = .placeHolder
        iconImageView.rotate()
    }
}
