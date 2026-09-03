//
//  PokemonListScreen.swift
//  Pokmon
//
//  Created by drake on 2026/9/3.
//

import SwiftUI

/// 列表頁的 SwiftUI 版本，與 `PokemonListViewController` 並存。
///
/// 這個 spike 只想證明一件事：**`PokemonListStore` 一行都沒有改。**
/// 同一個 `@Observable` Store、同一個 `State`、同一組 `Action`，換掉的只有 view 層。
///
/// UIKit 版在 `bindStore()` 裡手寫六個 `observe` closure 把 `viewState` 推進畫面
/// （版型、收藏鈕圖示、loading、empty、cells、alert）。這裡一個都不需要——
/// `body` 讀什麼就追蹤什麼，那正是 `observe` 在模擬的行為。
struct PokemonListScreen: View {

    @State private var store: PokemonListStore

    init(store: PokemonListStore) {
        _store = State(initialValue: store)
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Pokemon List (SwiftUI)")
                .toolbar { toolbar }
                .overlay { if store.viewState.isLoading { ProgressView() } }
                .overlay { emptyView }
                .alert(
                    store.viewState.alert?.title ?? "",
                    isPresented: alertBinding,
                    presenting: store.viewState.alert
                ) { _ in
                    // 這裡刻意留空：SwiftUI 在按下按鈕後會自己把 isPresented 翻成
                    // false，於是 alertBinding 的 setter 送出 .dismissAlert。
                    // 如果按鈕自己也送一次，就會送兩次。
                    Button("OK", role: .cancel) { }
                } message: { alert in
                    Text(alert.message)
                }
        }
        .task { store.send(.onAppear) }
    }
}

// MARK: - Subviews

private extension PokemonListScreen {

    @ViewBuilder
    var content: some View {
        if store.viewState.isListLayout {
            List(store.viewState.displayCells, id: \.number) { cell in
                row(cell)
                    .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
        } else {
            ScrollView {
                LazyVGrid(columns: [.init(.adaptive(minimum: 160), spacing: 8)], spacing: 8) {
                    ForEach(store.viewState.displayCells, id: \.number) { cell in
                        row(cell)
                    }
                }
                .padding(8)
            }
        }
    }

    func row(_ cell: CellViewModel) -> some View {
        PokemonRow(model: cell)
            .contentShape(.rect)
            .onTapGesture { store.send(.tapCell(cell)) }
            .onAppear {
                // UIKit 版靠 scrollViewDidScroll 算到底；這裡由最後一格自己報到。
                if cell.number == store.viewState.displayCells.last?.number {
                    store.send(.loadMore)
                }
            }
    }

    @ViewBuilder
    var emptyView: some View {
        if store.viewState.isEmpty, !store.viewState.isLoading {
            ContentUnavailableView(
                store.viewState.isFavoriteFilterOn ? "沒有收藏的寶可夢" : "沒有資料",
                systemImage: "bookmark"
            )
        }
    }

    @ToolbarContentBuilder
    var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button(store.viewState.isListLayout ? "List" : "Grid") {
                store.send(.tapChangeLayout)
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                store.send(.tapFavorite)
            } label: {
                Image(systemName: store.viewState.isFavoriteFilterOn ? "bookmark.fill" : "bookmark")
            }
        }
    }

    /// `AlertState` 沒有 `Identifiable`，所以走 `isPresented` 而不是 `alert(item:)`。
    var alertBinding: Binding<Bool> {
        .init(
            get: { store.viewState.alert != nil },
            set: { if !$0 { store.send(.dismissAlert) } }
        )
    }
}

// MARK: - Row

/// `CellViewModel` 本身就是 `@Observable`，所以資料載進來時這一列自己會重畫，
/// 不需要 diffable data source 的 snapshot，也沒有 cell 重用。
///
/// 值得注意的是：UIKit 版那個「重用後殘留上一隻的屬性與配色」的 bug，
/// 在這裡**結構上不可能發生**——沒有被重用的 view 實例，就沒有要清的殘留狀態。
struct PokemonRow: View {

    let model: CellViewModel

    var body: some View {
        HStack(spacing: 12) {
            // 正式遷移會用 KFImage 以維持既有的快取行為；
            // spike 用 AsyncImage 是為了把焦點留在 Store 重用這件事上。
            AsyncImage(url: model.imageURL.flatMap(URL.init(string:))) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                Image(.pokeball).resizable().scaledToFit()
            }
            .frame(width: 72, height: 72)

            VStack(alignment: .leading, spacing: 4) {
                Text(model.numberText)
                    .font(.system(size: 18))
                Text(model.displayName)
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    ForEach(Array(model.types.enumerated()), id: \.offset) { _, type in
                        Text(type.name)
                            .font(.system(size: 12))
                            .padding(.horizontal, 10)
                            .frame(height: 24)
                            .background(Color(uiColor: type.color), in: .capsule)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(uiColor: model.types.first?.color ?? .gray))
        )
        // UIKit 版要在 bindView 呼叫、prepareForReuse 取消；這裡 .task 兩件事一起做。
        .task { model.bindView() }
    }
}
