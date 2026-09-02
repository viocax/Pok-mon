//
//  ObserveTests.swift
//  PokmonTests
//
//  Created by drake on 2026/9/1.
//

import Testing
import UIKit
@testable import Pokmon

@Observable
@MainActor
private final class ProbeModel {
    var count: Int = 0
}

@MainActor
private final class ProbeResponder: UIResponder {}

@MainActor
@Suite struct ObserveTests {

    /// `withObservationTracking` 的 `onChange` 是 willSet 語義，重新掛載被丟進 `Task`，
    /// 所以要讓出執行權才看得到結果。
    private func waitForRearm(_ condition: @MainActor () -> Bool) async -> Bool {
        for _ in 0..<200 {
            if condition() { return true }
            await Task.yield()
        }
        return condition()
    }

    @Test func 掛載時立刻執行一次() {
        let model = ProbeModel()
        let responder = ProbeResponder()
        let recorder = Recorder<Int>()

        responder.observe { [weak model] in
            guard let model else { return }
            recorder.record(model.count)
        }

        #expect(recorder.recorded == [0])
    }

    @Test func 屬性變動後會重新執行() async {
        let model = ProbeModel()
        let responder = ProbeResponder()
        let recorder = Recorder<Int>()

        responder.observe { [weak model] in
            guard let model else { return }
            recorder.record(model.count)
        }
        #expect(recorder.recorded == [0])

        model.count = 1
        let rearmed = await waitForRearm { recorder.recorded.count == 2 }

        #expect(rearmed)
        #expect(recorder.recorded == [0, 1])
    }

    @Test func 連續變動每次都會重新執行() async {
        let model = ProbeModel()
        let responder = ProbeResponder()
        let recorder = Recorder<Int>()

        responder.observe { [weak model] in
            guard let model else { return }
            recorder.record(model.count)
        }

        model.count = 1
        _ = await waitForRearm { recorder.recorded.count == 2 }
        model.count = 2
        let rearmed = await waitForRearm { recorder.recorded.count == 3 }

        #expect(rearmed)
        #expect(recorder.recorded == [0, 1, 2])
    }

    @Test func 取消後不再重新執行() async {
        let model = ProbeModel()
        let responder = ProbeResponder()
        let recorder = Recorder<Int>()

        let token = responder.observe { [weak model] in
            guard let model else { return }
            recorder.record(model.count)
        }
        #expect(recorder.recorded == [0])

        token.cancel()
        model.count = 1
        // 給重新掛載的 Task 足夠機會執行，確認它真的沒有跑
        for _ in 0..<200 { await Task.yield() }

        #expect(recorder.recorded == [0])
    }

    /// 觀察者被釋放後，重新掛載的鏈路要自然終止，不能無限續命。
    @Test func 觀察者釋放後停止重新掛載() async {
        let model = ProbeModel()
        let recorder = Recorder<Int>()
        var responder: ProbeResponder? = ProbeResponder()

        responder?.observe { [weak model] in
            guard let model else { return }
            recorder.record(model.count)
        }
        #expect(recorder.recorded == [0])

        responder = nil
        model.count = 1
        for _ in 0..<200 { await Task.yield() }

        #expect(recorder.recorded == [0])
    }
}
